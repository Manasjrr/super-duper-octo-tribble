import CryptoKit
import Foundation

// MARK: - Applis web expéditrices
//
// iOS affiche toujours l'icône de l'app qui envoie une notification. Pour avoir d'autres icônes
// sans autorisation payante, Nova fait envoyer ses notifications par des « applis web » ajoutées
// à l'écran d'accueil (une par expéditeur : Messages, Banque…). Chacune a son icône et son nom,
// et reçoit de vraies notifications push (iOS 16.4+). Nova envoie ces push lui-même via le
// protocole Web Push standard : aucun serveur n'est nécessaire, juste les pages statiques de docs/.

struct Persona: Identifiable, Codable, Hashable {
    var id: String          // emplacement (messages, banque, perso1…)
    var name: String
    var endpoint: String
    var p256dh: String
    var auth: String
    var lastStatus: String? = nil
}

enum WebPersonas {
    struct Slot: Identifiable {
        let id: String
        let label: String
        let preview: String     // image de l'app pour l'aperçu
        let custom: Bool
    }

    static let slots: [Slot] = [
        Slot(id: "messages", label: "Messages", preview: "Preview-AppIcon-Messages", custom: false),
        Slot(id: "mail", label: "Mail", preview: "Preview-AppIcon-Mail", custom: false),
        Slot(id: "colis", label: "Colis", preview: "Preview-AppIcon-Colis", custom: false),
        Slot(id: "banque", label: "Banque", preview: "Preview-AppIcon-Banque", custom: false),
        Slot(id: "agenda", label: "Agenda", preview: "Preview-AppIcon-Agenda", custom: false),
        Slot(id: "social", label: "Social", preview: "Preview-AppIcon-Social", custom: false),
        Slot(id: "alerte", label: "Alerte", preview: "Preview-AppIcon-Alerte", custom: false),
        Slot(id: "perso1", label: "Perso 1", preview: "Emblem", custom: true),
        Slot(id: "perso2", label: "Perso 2", preview: "Emblem", custom: true),
        Slot(id: "perso3", label: "Perso 3", preview: "Emblem", custom: true),
    ]

    static func slot(_ id: String?) -> Slot? {
        slots.first { $0.id == id }
    }

    static let defaultBaseURL = "https://manasjrr.github.io/super-duper-octo-tribble/"

    /// Adresse d'installation d'un expéditeur (la clé de Nova est passée dans l'adresse).
    static func installURL(base: String, slot: Slot, customName: String?, customIcon: Data?) -> URL? {
        var b = base.trimmingCharacters(in: .whitespaces)
        if !b.hasSuffix("/") { b += "/" }
        var s = b + "p/\(slot.id)/?k=" + WebPush.publicKey
        if slot.custom {
            var fragment: [String] = []
            if let name = customName?.addingPercentEncoding(withAllowedCharacters: .alphanumerics), !name.isEmpty {
                fragment.append("name=" + name)
            }
            if let icon = customIcon { fragment.append("icon=" + icon.base64URL) }
            if !fragment.isEmpty { s += "#" + fragment.joined(separator: "&") }
        }
        return URL(string: s)
    }

    /// Décode la connexion renvoyée par une appli web (nova://persona?d=… ou NOVA-SUB:…).
    static func decode(_ payload: String) -> Persona? {
        guard let data = Data(base64URL: payload),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let slot = obj["slot"] as? String,
              let endpoint = obj["endpoint"] as? String,
              let p256dh = obj["p256dh"] as? String,
              let auth = obj["auth"] as? String else { return nil }
        let name = (obj["name"] as? String) ?? self.slot(slot)?.label ?? slot
        return Persona(id: slot, name: name, endpoint: endpoint, p256dh: p256dh, auth: auth)
    }
}

// MARK: - Protocole Web Push (VAPID RFC 8292 + chiffrement aes128gcm RFC 8291)

enum WebPush {
    private static let keyDefaultsKey = "vapidPrivateKey"

    /// Clé de signature de Nova, créée une fois puis conservée.
    static let signingKey: P256.Signing.PrivateKey = {
        if let raw = UserDefaults.standard.data(forKey: keyDefaultsKey),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: raw) {
            return key
        }
        let key = P256.Signing.PrivateKey()
        UserDefaults.standard.set(key.rawRepresentation, forKey: keyDefaultsKey)
        return key
    }()

    static var publicKey: String {
        signingKey.publicKey.x963Representation.base64URL
    }

    enum PushError: LocalizedError {
        case badSubscription
        var errorDescription: String? { "Connexion de l'appli web invalide." }
    }

    /// Envoie une notification à une appli web. `completion(ok, détail)` est appelé sur le fil principal.
    static func send(to persona: Persona, title: String, subtitle: String, body: String, id: String,
                     completion: @escaping (Bool, String) -> Void) {
        do {
            guard let url = URL(string: persona.endpoint), let scheme = url.scheme, let host = url.host else {
                throw PushError.badSubscription
            }
            let json: [String: String] = ["title": title, "subtitle": subtitle, "body": body, "id": id]
            let payload = try JSONSerialization.data(withJSONObject: json)
            let encrypted = try encrypt(payload, p256dh: persona.p256dh, auth: persona.auth)
            let token = try jwt(audience: "\(scheme)://\(host)")

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = encrypted
            request.setValue("aes128gcm", forHTTPHeaderField: "Content-Encoding")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue("120", forHTTPHeaderField: "TTL")
            request.setValue("high", forHTTPHeaderField: "Urgency")
            request.setValue("vapid t=\(token), k=\(publicKey)", forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                let detail: String
                if let error {
                    detail = error.localizedDescription
                } else if (200..<300).contains(code) {
                    detail = "OK"
                } else {
                    let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    detail = "Erreur \(code) \(text)".trimmingCharacters(in: .whitespaces)
                }
                DispatchQueue.main.async { completion(error == nil && (200..<300).contains(code), detail) }
            }.resume()
        } catch {
            completion(false, error.localizedDescription)
        }
    }

    /// Jeton VAPID signé (ES256), valable 12 h.
    private static func jwt(audience: String) throws -> String {
        let header = #"{"typ":"JWT","alg":"ES256"}"#
        let exp = Int(Date().timeIntervalSince1970) + 12 * 3600
        let claims = "{\"aud\":\"\(audience)\",\"exp\":\(exp),\"sub\":\"https://manasjrr.github.io\"}"
        let input = Data(header.utf8).base64URL + "." + Data(claims.utf8).base64URL
        let signature = try signingKey.signature(for: Data(input.utf8))
        return input + "." + signature.rawRepresentation.base64URL
    }

    /// Chiffrement du message (RFC 8291, un seul enregistrement aes128gcm).
    static func encrypt(_ plaintext: Data, p256dh: String, auth: String) throws -> Data {
        guard let receiverKeyData = Data(base64URL: p256dh), let authSecret = Data(base64URL: auth) else {
            throw PushError.badSubscription
        }
        let receiverKey = try P256.KeyAgreement.PublicKey(x963Representation: receiverKeyData)
        let ephemeral = P256.KeyAgreement.PrivateKey()
        let ephemeralPublic = ephemeral.publicKey.x963Representation
        let shared = try ephemeral.sharedSecretFromKeyAgreement(with: receiverKey)

        // IKM = HKDF(sel = auth, secret ECDH, info = "WebPush: info\0" || clé du destinataire || clé éphémère)
        var keyInfo = Data("WebPush: info".utf8)
        keyInfo.append(0)
        keyInfo.append(receiverKeyData)
        keyInfo.append(ephemeralPublic)
        let ikm = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: authSecret,
                                                 sharedInfo: keyInfo, outputByteCount: 32)

        let salt = Data((0..<16).map { _ in UInt8.random(in: 0...255) })
        var cekInfo = Data("Content-Encoding: aes128gcm".utf8)
        cekInfo.append(0)
        var nonceInfo = Data("Content-Encoding: nonce".utf8)
        nonceInfo.append(0)
        let cek = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: cekInfo, outputByteCount: 16)
        let nonceKey = HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: salt, info: nonceInfo, outputByteCount: 12)
        let nonce = try AES.GCM.Nonce(data: nonceKey.withUnsafeBytes { Data($0) })

        var padded = plaintext
        padded.append(0x02)     // délimiteur du dernier enregistrement
        let sealed = try AES.GCM.seal(padded, using: cek, nonce: nonce)

        var body = Data()
        body.append(salt)
        body.append(contentsOf: [0x00, 0x00, 0x10, 0x00])   // taille d'enregistrement : 4096
        body.append(UInt8(ephemeralPublic.count))
        body.append(ephemeralPublic)
        body.append(sealed.ciphertext)
        body.append(sealed.tag)
        return body
    }
}

// MARK: - Base64 URL

extension Data {
    var base64URL: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(base64URL: String) {
        var s = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        self.init(base64Encoded: s)
    }
}
