// Literatur — Native SwiftUI client for ConsultingOS Literature
// Auth: shared keychain (com.dennis.consultingos / default)
// Backend: https://1o618.com/api/literature/

import SwiftUI
import AppKit
import PDFKit
import Security
import UniformTypeIdentifiers
import Combine

// ============================================================
// MARK: - Config
// ============================================================

enum Config {
    static let apiBase = "https://1o618.com"
    static let deviceName = "macOS Literatur"
}

// ============================================================
// MARK: - Theme
// ============================================================

struct T {
    static let bg          = Color(red: 0.06, green: 0.055, blue: 0.08)
    static let card        = Color(white: 0.10)
    static let cardHover   = Color(white: 0.13)
    static let header      = Color(white: 0.08)
    static let text1       = Color.white.opacity(0.93)
    static let text2       = Color.white.opacity(0.55)
    static let text3       = Color.white.opacity(0.30)
    static let line        = Color.white.opacity(0.07)
    static let accent      = Color(red: 0.55, green: 0.42, blue: 0.75)
    static let accentSoft  = Color(red: 0.55, green: 0.42, blue: 0.75).opacity(0.18)
    static let success     = Color(red: 0.20, green: 0.74, blue: 0.50)
    static let warning     = Color(red: 0.96, green: 0.62, blue: 0.04)
    static let danger      = Color(red: 0.96, green: 0.30, blue: 0.37)
    static let star        = Color(red: 0.98, green: 0.78, blue: 0.30)
    static let highlightYellow = Color(red: 0.98, green: 0.80, blue: 0.20)
    static let highlightBlue   = Color(red: 0.40, green: 0.65, blue: 0.95)
    static let highlightGreen  = Color(red: 0.40, green: 0.85, blue: 0.55)

    static func hexColor(_ hex: String?) -> Color? {
        guard var s = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8 else { return nil }
        var rgb: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&rgb) else { return nil }
        if s.count == 6 {
            return Color(
                red: Double((rgb >> 16) & 0xFF) / 255.0,
                green: Double((rgb >> 8) & 0xFF) / 255.0,
                blue: Double(rgb & 0xFF) / 255.0
            )
        } else {
            return Color(
                .sRGB,
                red: Double((rgb >> 24) & 0xFF) / 255.0,
                green: Double((rgb >> 16) & 0xFF) / 255.0,
                blue: Double((rgb >> 8) & 0xFF) / 255.0,
                opacity: Double(rgb & 0xFF) / 255.0
            )
        }
    }

    static func absoluteURL(_ s: String?) -> URL? {
        guard let s = s, !s.isEmpty else { return nil }
        if s.hasPrefix("http") { return URL(string: s) }
        return URL(string: Config.apiBase + s)
    }

    static func tagColor(_ name: String) -> Color {
        switch name {
        case "red":    return Color(red: 0.92, green: 0.36, blue: 0.40)
        case "orange": return Color(red: 0.96, green: 0.60, blue: 0.32)
        case "yellow": return Color(red: 0.95, green: 0.75, blue: 0.30)
        case "green":  return Color(red: 0.30, green: 0.72, blue: 0.50)
        case "blue":   return Color(red: 0.42, green: 0.55, blue: 0.78)
        case "violet", "purple": return Color(red: 0.62, green: 0.45, blue: 0.82)
        case "pink":   return Color(red: 0.92, green: 0.50, blue: 0.72)
        case "cyan":   return Color(red: 0.36, green: 0.74, blue: 0.78)
        case "teal":   return Color(red: 0.30, green: 0.70, blue: 0.66)
        case "indigo": return Color(red: 0.45, green: 0.45, blue: 0.85)
        case "gray":   return Color(red: 0.50, green: 0.50, blue: 0.55)
        default:       return T.accent
        }
    }

    static func statusColor(_ status: String) -> Color {
        switch status {
        case "unread":    return Color(red: 0.50, green: 0.50, blue: 0.55)
        case "reading":   return Color(red: 0.42, green: 0.60, blue: 0.85)
        case "read":      return T.success
        case "annotated": return T.accent
        default:          return T.text3
        }
    }

    static func statusLabel(_ status: String) -> String {
        switch status {
        case "unread":    return "Ungelesen"
        case "reading":   return "Lesen"
        case "read":      return "Gelesen"
        case "annotated": return "Annotiert"
        default:          return status
        }
    }

    static func journalRatingColor(_ rating: String) -> Color {
        switch rating.uppercased() {
        case "A+", "A":  return T.success
        case "B":        return Color(red: 0.42, green: 0.60, blue: 0.85)
        case "C":        return T.warning
        case "D":        return Color(red: 0.96, green: 0.55, blue: 0.30)
        default:         return T.text3
        }
    }

    static func relevanceColor(_ score: Int?) -> Color {
        guard let s = score else { return T.text3 }
        if s >= 7 { return T.success }
        if s >= 4 { return T.warning }
        return T.danger
    }

    // Date helpers
    static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func parseISO(_ s: String) -> Date? {
        if let d = isoFormatter.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }

    static func relativeDate(_ s: String) -> String {
        guard let d = parseISO(s) else { return s }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.unitsStyle = .abbreviated
        return f.localizedString(for: d, relativeTo: Date())
    }

    static func mediumDate(_ s: String) -> String {
        guard let d = parseISO(s) else { return s }
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM yyyy"
        return f.string(from: d)
    }

    // Format authors as "Doe, J., Smith, K." (max 3 + et al.)
    static func formatAuthors(_ authors: [Author], max: Int = 3) -> String {
        let formatted = authors.prefix(max).map { author -> String in
            let initial = author.first.first.map { String($0) + "." } ?? ""
            return author.last + (initial.isEmpty ? "" : ", " + initial)
        }
        var result = formatted.joined(separator: " · ")
        if authors.count > max {
            result += " et al."
        }
        return result
    }
}

// ============================================================
// MARK: - AnyCodable (for research_analysis JSON)
// ============================================================

struct AnyCodable: Codable, Hashable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self.value = NSNull()
        } else if let v = try? container.decode(Bool.self) {
            self.value = v
        } else if let v = try? container.decode(Int.self) {
            self.value = v
        } else if let v = try? container.decode(Double.self) {
            self.value = v
        } else if let v = try? container.decode(String.self) {
            self.value = v
        } else if let v = try? container.decode([AnyCodable].self) {
            self.value = v.map { $0.value }
        } else if let v = try? container.decode([String: AnyCodable].self) {
            self.value = v.mapValues { $0.value }
        } else {
            self.value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [Any]: try container.encode(v.map { AnyCodable($0) })
        case let v as [String: Any]: try container.encode(v.mapValues { AnyCodable($0) })
        default: try container.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Lightweight: compare if both nil/non-nil, skip deep JSON comparison
        // Full deep-compare is too expensive for 276 entries on every SwiftUI diff
        switch (lhs.value, rhs.value) {
        case (is NSNull, is NSNull): return true
        case (let l as String, let r as String): return l == r
        case (let l as Int, let r as Int): return l == r
        case (let l as Bool, let r as Bool): return l == r
        default:
            // For dicts/arrays, compare by reference identity or skip
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        // Lightweight hash — don't re-encode entire JSON
        switch value {
        case let v as String: hasher.combine(v)
        case let v as Int: hasher.combine(v)
        case let v as Bool: hasher.combine(v)
        case is NSNull: hasher.combine(0)
        default: hasher.combine(1)
        }
    }
}

// ============================================================
// MARK: - Models
// ============================================================

struct AuthData: Codable {
    var access_token: String
    var refresh_token: String
    var username: String?
}

struct Author: Codable, Equatable, Hashable {
    var first: String
    var last: String

    enum CodingKeys: String, CodingKey {
        case first, last, first_name, last_name
    }

    init(first: String, last: String) {
        self.first = first
        self.last = last
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        first = (try? c.decode(String.self, forKey: .first))
            ?? (try? c.decode(String.self, forKey: .first_name))
            ?? ""
        last = (try? c.decode(String.self, forKey: .last))
            ?? (try? c.decode(String.self, forKey: .last_name))
            ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(first, forKey: .first)
        try c.encode(last, forKey: .last)
    }
}

struct LiteratureTag: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var color: String
    var entry_count: Int
}

struct LiteratureCollection: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String
    var collection_type: String
    var parent_id: Int?
    var color: String
    var sort_order: Int
    var is_archived: Bool
    var entry_count: Int
    var created_at: String
}

struct LiteratureEntry: Codable, Identifiable, Hashable {
    let id: Int
    var entry_type: String
    var title: String
    var authors: [Author]
    var year: Int?
    var month: String
    var journal: String
    var volume: String
    var issue: String
    var pages: String
    var publisher: String
    var booktitle: String
    var edition: String
    var series: String
    var doi: String
    var isbn: String
    var url: String
    var arxiv_id: String
    var abstract: String
    var bibtex_key: String
    var keywords: [String]
    var notes: String
    var research_analysis: AnyCodable?
    var rating: Int
    var journal_rating: String
    var reading_status: String
    var is_favorite: Bool
    var pdf_url: String?
    var pdf_file_size: Int?
    var citation_count: Int?
    var pdf_access_status: String
    var relevance_score: Int?
    var relevance_note: String?
    var tags: [LiteratureTag]
    var collection_ids: [Int]
    var created_at: String
    var updated_at: String
}

struct EntryRelation: Codable, Identifiable, Hashable {
    let id: Int
    var source_entry_id: Int
    var target_entry_id: Int
    var source_entry_title: String
    var target_entry_title: String
    var relation_type: String
    var notes: String
    var created_at: String
}

struct PdfHighlightRect: Codable, Hashable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct PdfHighlight: Codable, Identifiable, Hashable {
    var id: String
    var pageNumber: Int
    var color: String
    var rects: [PdfHighlightRect]
    var text: String
    var translated: String?
}

struct DictionaryData: Codable, Hashable {
    var word: String?
    var phonetic: String?
    var pos: String?
    var translations: [String]?
    var definition: String?
    var academic_context: String?
    var examples: [String]?
    var synonyms: [String]?
    var etymology: String?
}

struct TranslationEntry: Codable, Identifiable, Hashable {
    var id: String
    var source: String
    var translated: String
    var page: Int?
    var timestamp: Double
    var mode: String?
    var dictionary: DictionaryData?
    var highlightId: String?
}

struct MethodData: Codable, Hashable {
    var method_name: String
    var description: String
    var how_it_works: String
    var assumptions: String?
    var example: String?
    var formulas: String?
    var interpretation: String?
    var strengths_limitations: String?
    var use_cases: String?
    var why_used_here: String?
    var related_methods: [String]?
}

struct MethodEntry: Codable, Identifiable, Hashable {
    var id: String
    var source: String
    var page: Int?
    var timestamp: Double
    var highlightId: String?
    var cached: Bool?
    var method: MethodData
}

struct AgentQAEntry: Codable, Identifiable, Hashable {
    var id: String
    var question: String
    var answer: String
    var pages: [Int]
    var timestamp: Double
}

struct AnnotationsBundle: Codable {
    var translations: [TranslationEntry]
    var highlights: [PdfHighlight]
    var methodExplanations: [MethodEntry]
    var agentQA: [AgentQAEntry]
}

struct RelevanceSummary: Codable {
    var high: Int
    var medium: Int
    var low: Int
    var unrated: Int
    var total: Int
}

// ============================================================
// MARK: - AuthStore (shared keychain)
// ============================================================

final class AuthStore: ObservableObject {
    @Published var auth: AuthData?

    static let keychainService = "com.dennis.consultingos"
    static let keychainAccount = "default"

    init() {
        loadFromKeychain()
        if auth == nil { migrateFromLegacyFiles() }
    }

    func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data,
           let decoded = try? JSONDecoder().decode(AuthData.self, from: data) {
            auth = decoded
        }
    }

    private func migrateFromLegacyFiles() {
        let legacy = [
            NSHomeDirectory() + "/.config/kanban/auth.json",
            NSHomeDirectory() + "/.config/zeit/auth.json",
            NSHomeDirectory() + "/.config/termine/auth.json",
            NSHomeDirectory() + "/.config/literatur/auth.json",
        ]
        for path in legacy {
            guard let data = FileManager.default.contents(atPath: path),
                  let decoded = try? JSONDecoder().decode(AuthData.self, from: data) else { continue }
            save(decoded)
            break
        }
    }

    func save(_ a: AuthData) {
        DispatchQueue.main.async { self.auth = a }
        guard let data = try? JSONEncoder().encode(a) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        let updateAttrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttrs as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func updateAccessToken(_ token: String) {
        loadFromKeychain()
        guard var a = auth else { return }
        a.access_token = token
        save(a)
    }

    func clear() {
        DispatchQueue.main.async { self.auth = nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    var isLoggedIn: Bool { auth != nil }
}

// ============================================================
// MARK: - API
// ============================================================

final class API {
    let auth: AuthStore
    init(_ auth: AuthStore) { self.auth = auth }

    enum APIError: Error { case unauthorized, http(Int), bad }

    func request(_ method: String, _ path: String, body: Any? = nil, retryOn401: Bool = true) async throws -> Data {
        guard let url = URL(string: Config.apiBase + path) else { throw APIError.bad }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = auth.auth?.access_token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.bad }
        if http.statusCode == 401, retryOn401 {
            auth.loadFromKeychain()
            if let r = auth.auth?.refresh_token, try await refreshAccessToken(r) {
                return try await request(method, path, body: body, retryOn401: false)
            } else {
                auth.clear()
                throw APIError.unauthorized
            }
        }
        if http.statusCode >= 400 { throw APIError.http(http.statusCode) }
        return data
    }

    func uploadMultipart(_ path: String, fileURL: URL, fieldName: String = "file", extraFields: [String: String] = [:]) async throws -> Data {
        guard let url = URL(string: Config.apiBase + path) else { throw APIError.bad }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = auth.auth?.access_token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let filename = fileURL.lastPathComponent
        let mime = mimeType(for: fileURL.pathExtension.lowercased())
        let fileData = try Data(contentsOf: fileURL)
        var body = Data()
        for (key, value) in extraFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        req.httpBody = body
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode < 400 else { throw APIError.bad }
        return data
    }

    private func mimeType(for ext: String) -> String {
        switch ext {
        case "pdf": return "application/pdf"
        case "zip": return "application/zip"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        default: return "application/octet-stream"
        }
    }

    @discardableResult
    func refreshAccessToken(_ refresh: String) async throws -> Bool {
        guard let url = URL(string: Config.apiBase + "/api/auth/mobile/refresh") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refresh])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return false }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String else { return false }
        auth.updateAccessToken(access)
        return true
    }

    func refreshIfPossible() async {
        guard let r = auth.auth?.refresh_token else { return }
        _ = try? await refreshAccessToken(r)
    }

    // ----- Entries -----
    func listEntries(filters: [String: String] = [:]) async throws -> [LiteratureEntry] {
        var path = "/api/literature/entries"
        if !filters.isEmpty {
            let query = filters.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
            path += "?" + query
        }
        let data = try await request("GET", path)
        // Try strict decoding first; fall back to per-entry decoding so a single
        // bad row doesn't kill the whole list
        if let entries = try? JSONDecoder().decode([LiteratureEntry].self, from: data) {
            return entries
        }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        var result: [LiteratureEntry] = []
        for dict in raw {
            guard let itemData = try? JSONSerialization.data(withJSONObject: dict) else { continue }
            if let entry = try? JSONDecoder().decode(LiteratureEntry.self, from: itemData) {
                result.append(entry)
            }
        }
        return result
    }

    func getEntry(_ id: Int) async throws -> LiteratureEntry? {
        let data = try await request("GET", "/api/literature/entries/\(id)")
        return try? JSONDecoder().decode(LiteratureEntry.self, from: data)
    }

    func createEntry(_ data: [String: Any]) async throws -> LiteratureEntry? {
        let resp = try await request("POST", "/api/literature/entries", body: data)
        return try? JSONDecoder().decode(LiteratureEntry.self, from: resp)
    }

    func updateEntry(_ id: Int, _ data: [String: Any]) async throws -> LiteratureEntry? {
        let resp = try await request("PUT", "/api/literature/entries/\(id)", body: data)
        return try? JSONDecoder().decode(LiteratureEntry.self, from: resp)
    }

    func deleteEntry(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/literature/entries/\(id)")
    }

    func toggleFavorite(_ id: Int) async throws -> LiteratureEntry? {
        let data = try await request("POST", "/api/literature/entries/\(id)/toggle-favorite")
        return try? JSONDecoder().decode(LiteratureEntry.self, from: data)
    }

    func uploadPdf(entryId: Int, fileURL: URL) async throws -> LiteratureEntry? {
        let data = try await uploadMultipart("/api/literature/entries/\(entryId)/pdf", fileURL: fileURL)
        return try? JSONDecoder().decode(LiteratureEntry.self, from: data)
    }

    func deletePdf(_ id: Int) async throws -> LiteratureEntry? {
        let data = try await request("DELETE", "/api/literature/entries/\(id)/pdf")
        return try? JSONDecoder().decode(LiteratureEntry.self, from: data)
    }

    func uploadPaper(fileURL: URL, collectionId: Int? = nil) async throws -> [String: Any]? {
        var fields: [String: String] = [:]
        if let cid = collectionId { fields["collection_id"] = "\(cid)" }
        let data = try await uploadMultipart("/api/literature/entries/upload-paper", fileURL: fileURL, extraFields: fields)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func extractMetadata(_ id: Int) async throws -> [String: Any]? {
        let data = try await request("POST", "/api/literature/entries/\(id)/extract-metadata")
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func importBibtex(content: String, collectionId: Int? = nil) async throws -> [String: Any]? {
        var body: [String: Any] = ["bibtex": content]
        if let cid = collectionId { body["collection_id"] = cid }
        let data = try await request("POST", "/api/literature/entries/import-bibtex", body: body)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func lookupDOI(_ doi: String) async throws -> [String: Any]? {
        let data = try await request("POST", "/api/literature/entries/lookup-doi", body: ["doi": doi])
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    func formatCitation(_ id: Int, style: String) async throws -> [String: Any]? {
        let data = try await request("POST", "/api/literature/entries/\(id)/format-citation", body: ["style": style])
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // ----- Collections -----
    func listCollections(includeArchived: Bool = false) async throws -> [LiteratureCollection] {
        let path = "/api/literature/collections" + (includeArchived ? "?include_archived=true" : "")
        let data = try await request("GET", path)
        return (try? JSONDecoder().decode([LiteratureCollection].self, from: data)) ?? []
    }

    func createCollection(_ data: [String: Any]) async throws -> LiteratureCollection? {
        let resp = try await request("POST", "/api/literature/collections", body: data)
        return try? JSONDecoder().decode(LiteratureCollection.self, from: resp)
    }

    func updateCollection(_ id: Int, _ data: [String: Any]) async throws -> LiteratureCollection? {
        let resp = try await request("PUT", "/api/literature/collections/\(id)", body: data)
        return try? JSONDecoder().decode(LiteratureCollection.self, from: resp)
    }

    func deleteCollection(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/literature/collections/\(id)")
    }

    func toggleArchiveCollection(_ id: Int) async throws -> LiteratureCollection? {
        let data = try await request("POST", "/api/literature/collections/\(id)/toggle-archive")
        return try? JSONDecoder().decode(LiteratureCollection.self, from: data)
    }

    func addEntriesToCollection(collectionId: Int, entryIds: [Int]) async throws {
        _ = try await request("POST", "/api/literature/collections/\(collectionId)/entries", body: ["entry_ids": entryIds])
    }

    func removeEntriesFromCollection(collectionId: Int, entryIds: [Int]) async throws {
        _ = try await request("POST", "/api/literature/collections/\(collectionId)/remove-entries", body: ["entry_ids": entryIds])
    }

    // ----- Tags -----
    func listTags() async throws -> [LiteratureTag] {
        let data = try await request("GET", "/api/literature/tags")
        return (try? JSONDecoder().decode([LiteratureTag].self, from: data)) ?? []
    }

    func createTag(name: String, color: String) async throws -> LiteratureTag? {
        let data = try await request("POST", "/api/literature/tags", body: ["name": name, "color": color])
        return try? JSONDecoder().decode(LiteratureTag.self, from: data)
    }

    func updateTag(_ id: Int, _ data: [String: Any]) async throws -> LiteratureTag? {
        let resp = try await request("PUT", "/api/literature/tags/\(id)", body: data)
        return try? JSONDecoder().decode(LiteratureTag.self, from: resp)
    }

    func deleteTag(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/literature/tags/\(id)")
    }

    // ----- Annotations -----
    func getAnnotations(_ entryId: Int) async throws -> AnnotationsBundle? {
        let data = try await request("GET", "/api/literature/entries/\(entryId)/annotations")
        return try? JSONDecoder().decode(AnnotationsBundle.self, from: data)
    }

    func saveAnnotations(_ entryId: Int, _ bundle: AnnotationsBundle) async throws {
        let encoded = try JSONEncoder().encode(bundle)
        guard let dict = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return }
        _ = try await request("POST", "/api/literature/entries/\(entryId)/annotations", body: dict)
    }

    // ----- Translation / Method -----
    func translateText(_ text: String, mode: String?, sourceLang: String = "en", targetLang: String = "de", force: Bool = false) async throws -> [String: Any]? {
        var body: [String: Any] = [
            "text": text,
            "source_lang": sourceLang,
            "target_lang": targetLang,
            "force": force,
        ]
        if let m = mode { body["mode"] = m }
        let data = try await request("POST", "/api/literature/translate-text", body: body)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // ----- Agent Q&A -----
    func askAgent(_ entryId: Int, question: String) async throws -> [String: Any]? {
        // Agent Q&A can take 10+ minutes for large papers — use custom long timeout
        guard let url = URL(string: Config.apiBase + "/api/literature/entries/\(entryId)/ask-agent") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 600
        if let token = auth.auth?.access_token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "question": question,
            "target_lang": "de",
        ])
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 600
        cfg.timeoutIntervalForResource = 1800
        let session = URLSession(configuration: cfg)
        let (data, _) = try await session.data(for: req)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // ----- Translate Analysis -----
    func translateAnalysis(_ entryId: Int, force: Bool = false) async throws -> [String: Any]? {
        let data = try await request("POST", "/api/literature/entries/\(entryId)/translate-analysis", body: ["force": force])
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    // ----- Relations -----
    func listRelations(_ entryId: Int) async throws -> [EntryRelation] {
        let data = try await request("GET", "/api/literature/entries/\(entryId)/relations")
        return (try? JSONDecoder().decode([EntryRelation].self, from: data)) ?? []
    }

    func networkRelations(collectionId: Int? = nil) async throws -> [EntryRelation] {
        var path = "/api/literature/relations/network"
        if let c = collectionId { path += "?collection=\(c)" }
        let data = try await request("GET", path)
        return (try? JSONDecoder().decode([EntryRelation].self, from: data)) ?? []
    }

    func createRelation(sourceId: Int, targetId: Int, type: String, notes: String) async throws -> EntryRelation? {
        let data = try await request("POST", "/api/literature/entries/\(sourceId)/relations", body: [
            "target_entry_id": targetId,
            "relation_type": type,
            "notes": notes,
        ])
        return try? JSONDecoder().decode(EntryRelation.self, from: data)
    }

    func deleteRelation(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/literature/relations/\(id)")
    }

    // ----- RAG -----
    func ragSearch(query: String, collectionId: Int? = nil, limit: Int = 20) async throws -> [[String: Any]] {
        var body: [String: Any] = ["query": query, "limit": limit]
        if let c = collectionId { body["collection_id"] = c }
        let data = try await request("POST", "/api/literature/rag/search", body: body)
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    func ragIndexAll() async throws {
        _ = try await request("POST", "/api/literature/rag/index")
    }

    func ragIndexEntry(_ id: Int) async throws {
        _ = try await request("POST", "/api/literature/rag/index/\(id)")
    }

    // ----- Journal Ratings -----
    func listJournalRatings() async throws -> [[String: Any]] {
        let data = try await request("GET", "/api/literature/journal-ratings")
        return (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }
}

// ============================================================
// MARK: - Stores
// ============================================================

enum SmartList: String, Hashable {
    case all, favorites, recent, unread, rag
}

enum SidebarFilter: Hashable {
    case smart(SmartList)
    case collection(Int)
    case tag(Int)

    var persistKey: String {
        switch self {
        case .smart(let s): return "smart:\(s.rawValue)"
        case .collection(let id): return "collection:\(id)"
        case .tag(let id): return "tag:\(id)"
        }
    }

    static func fromPersistKey(_ key: String) -> SidebarFilter {
        let parts = key.split(separator: ":", maxSplits: 1)
        guard parts.count == 2 else { return .smart(.all) }
        let prefix = String(parts[0])
        let value = String(parts[1])
        switch prefix {
        case "smart":
            return .smart(SmartList(rawValue: value) ?? .all)
        case "collection":
            if let id = Int(value) { return .collection(id) }
        case "tag":
            if let id = Int(value) { return .tag(id) }
        default: break
        }
        return .smart(.all)
    }
}

enum SortBy: String, CaseIterable {
    case title, year, added, rating, journalRating
    var label: String {
        switch self {
        case .title:        return "Titel"
        case .year:         return "Jahr"
        case .added:        return "Hinzugefügt"
        case .rating:       return "Bewertung"
        case .journalRating: return "VHB"
        }
    }
}

enum ViewMode: String { case list, cards }

@MainActor
final class EntriesStore: ObservableObject {
    @Published var entries: [LiteratureEntry] = []
    @Published var loading: Bool = false
    @Published var selectedDetail: LiteratureEntry? = nil

    // UI filters — persisted via UserDefaults
    @Published var sidebarFilter: SidebarFilter = .smart(.all) {
        didSet { UserDefaults.standard.set(sidebarFilter.persistKey, forKey: "lit.sidebarFilter") }
    }
    @Published var searchQuery: String = "" {
        didSet { UserDefaults.standard.set(searchQuery, forKey: "lit.searchQuery") }
    }
    @Published var sortBy: SortBy = .added {
        didSet { UserDefaults.standard.set(sortBy.rawValue, forKey: "lit.sortBy") }
    }
    @Published var sortAscending: Bool = false {
        didSet { UserDefaults.standard.set(sortAscending, forKey: "lit.sortAscending") }
    }
    @Published var viewMode: ViewMode = .list {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "lit.viewMode") }
    }
    @Published var relevanceFilter: String = "all"
    @Published var selectedEntryId: Int? = nil {
        didSet {
            if let id = selectedEntryId { UserDefaults.standard.set(id, forKey: "lit.selectedEntryId") }
            else { UserDefaults.standard.removeObject(forKey: "lit.selectedEntryId") }
        }
    }

    let api: API
    private var cancellables = Set<AnyCancellable>()

    init(api: API) {
        self.api = api

        // Restore persisted UI state
        let ud = UserDefaults.standard
        if let filterKey = ud.string(forKey: "lit.sidebarFilter") {
            sidebarFilter = SidebarFilter.fromPersistKey(filterKey)
        }
        if let sq = ud.string(forKey: "lit.searchQuery") { searchQuery = sq }
        if let sb = ud.string(forKey: "lit.sortBy"), let s = SortBy(rawValue: sb) { sortBy = s }
        sortAscending = ud.bool(forKey: "lit.sortAscending")
        if let vm = ud.string(forKey: "lit.viewMode"), let v = ViewMode(rawValue: vm) { viewMode = v }
        let savedId = ud.integer(forKey: "lit.selectedEntryId")
        if savedId > 0 { selectedEntryId = savedId }

        // Auto-recalculate filteredEntries when any input changes
        Publishers.CombineLatest4($entries, $sidebarFilter, $searchQuery, $sortBy)
            .combineLatest($sortAscending)
            .debounce(for: 0.05, scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.recalculateFiltered() }
            .store(in: &cancellables)
    }

    func reload() async {
        loading = true
        if let e = try? await api.listEntries() {
            withAnimation(.easeInOut(duration: 0.2)) { entries = e }
            // Restore selected entry detail if persisted
            if let sid = selectedEntryId, selectedDetail == nil {
                await loadDetail(sid)
            }
        }
        loading = false
    }

    func loadDetail(_ id: Int) async {
        selectedEntryId = id
        if let d = try? await api.getEntry(id) {
            selectedDetail = d
        }
    }

    func update(_ id: Int, _ data: [String: Any]) async -> LiteratureEntry? {
        guard let updated = try? await api.updateEntry(id, data) else { return nil }
        if selectedDetail?.id == id { selectedDetail = updated }
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i] = updated }
        return updated
    }

    func toggleFavorite(_ id: Int) async {
        if let updated = try? await api.toggleFavorite(id) {
            if selectedDetail?.id == id { selectedDetail = updated }
            if let i = entries.firstIndex(where: { $0.id == id }) { entries[i] = updated }
        }
    }

    func delete(_ id: Int) async {
        try? await api.deleteEntry(id)
        entries.removeAll { $0.id == id }
        if selectedDetail?.id == id { selectedDetail = nil }
    }

    // Cached filtered entries + sidebar counts
    @Published var filteredEntries: [LiteratureEntry] = []
    @Published var countAll: Int = 0
    @Published var countFavorites: Int = 0
    @Published var countRecent: Int = 0
    @Published var countUnread: Int = 0

    func recalculateFiltered() {
        // Update sidebar counts
        let cal = Calendar.current
        let cutoff14 = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        countAll = entries.count
        countFavorites = entries.filter { $0.is_favorite }.count
        countRecent = entries.filter { T.parseISO($0.created_at).map { $0 >= cutoff14 } ?? false }.count
        countUnread = entries.filter { $0.reading_status == "unread" }.count

        var result = entries

        // Sidebar filter
        switch sidebarFilter {
        case .smart(.all): break
        case .smart(.favorites):
            result = result.filter { $0.is_favorite }
        case .smart(.recent):
            // Last 14 days
            let cal = Calendar.current
            let cutoff = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            result = result.filter {
                if let d = T.parseISO($0.created_at) { return d >= cutoff }
                return false
            }
        case .smart(.unread):
            result = result.filter { $0.reading_status == "unread" }
        case .smart(.rag):
            // RAG search results handled in phase 7
            break
        case .collection(let cid):
            result = result.filter { $0.collection_ids.contains(cid) }
        case .tag(let tid):
            result = result.filter { $0.tags.contains(where: { $0.id == tid }) }
        }

        // Search
        let q = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter { entry in
                if entry.title.lowercased().contains(q) { return true }
                if entry.journal.lowercased().contains(q) { return true }
                if entry.abstract.lowercased().contains(q) { return true }
                for a in entry.authors {
                    if a.last.lowercased().contains(q) || a.first.lowercased().contains(q) { return true }
                }
                if entry.keywords.contains(where: { $0.lowercased().contains(q) }) { return true }
                if entry.tags.contains(where: { $0.name.lowercased().contains(q) }) { return true }
                return false
            }
        }

        // Sort
        result.sort { a, b in
            let ascending = sortAscending
            switch sortBy {
            case .title:
                return ascending ? a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
                                 : a.title.localizedCaseInsensitiveCompare(b.title) == .orderedDescending
            case .year:
                let ay = a.year ?? 0
                let by = b.year ?? 0
                return ascending ? ay < by : ay > by
            case .added:
                return ascending ? a.created_at < b.created_at : a.created_at > b.created_at
            case .rating:
                return ascending ? a.rating < b.rating : a.rating > b.rating
            case .journalRating:
                return ascending ? a.journal_rating < b.journal_rating : a.journal_rating > b.journal_rating
            }
        }

        filteredEntries = result
    }
}

@MainActor
final class CollectionsStore: ObservableObject {
    @Published var collections: [LiteratureCollection] = []
    @Published var includeArchived: Bool = false
    let api: API
    init(api: API) { self.api = api }

    func reload() async {
        if let c = try? await api.listCollections(includeArchived: includeArchived) {
            collections = c
        }
    }
}

@MainActor
final class TagsStore: ObservableObject {
    @Published var tags: [LiteratureTag] = []
    let api: API
    init(api: API) { self.api = api }

    func reload() async {
        if let t = try? await api.listTags() { tags = t }
    }
}

// ============================================================
// MARK: - SSE Stream client
// ============================================================

final class SSEStream: NSObject, URLSessionDataDelegate {
    let url: URL
    let body: [String: Any]
    let token: String?
    let onEvent: (String) -> Void
    let onComplete: (Error?) -> Void

    private var task: URLSessionDataTask?
    private var session: URLSession!
    private var buffer = Data()

    init(url: URL, body: [String: Any], token: String?, onEvent: @escaping (String) -> Void, onComplete: @escaping (Error?) -> Void) {
        self.url = url
        self.body = body
        self.token = token
        self.onEvent = onEvent
        self.onComplete = onComplete
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 600
        cfg.timeoutIntervalForResource = 1800
        self.session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func start() {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let t = token { req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        task = session.dataTask(with: req)
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        session.invalidateAndCancel()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        let separator = Data("\n\n".utf8)
        while let range = buffer.range(of: separator) {
            let chunk = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            if let str = String(data: chunk, encoding: .utf8) {
                for line in str.split(separator: "\n") {
                    if line.hasPrefix("data: ") {
                        onEvent(String(line.dropFirst(6)))
                    } else if line.hasPrefix("data:") {
                        onEvent(String(line.dropFirst(5)))
                    }
                }
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // Flush remaining buffer (last chunk may lack trailing \n\n)
        if !buffer.isEmpty, let str = String(data: buffer, encoding: .utf8) {
            for line in str.split(separator: "\n") {
                if line.hasPrefix("data: ") {
                    onEvent(String(line.dropFirst(6)))
                } else if line.hasPrefix("data:") {
                    onEvent(String(line.dropFirst(5)))
                }
            }
            buffer.removeAll()
        }
        onComplete(error)
    }
}

// ============================================================
// MARK: - AnalysisStore
// ============================================================

@MainActor
final class AnalysisStore: ObservableObject {
    enum Status: String {
        case idle, extracting, analyzing, consolidating, done, error
    }

    @Published var status: Status = .idle
    @Published var totalPages: Int = 0
    @Published var processedPages: Int = 0
    @Published var totalChunks: Int = 0
    @Published var currentChunk: Int = 0
    @Published var error: String?
    @Published var translatingAnalysis: Bool = false
    @Published var displayLanguage: String = UserDefaults.standard.string(forKey: "lit.analysisLang") ?? "en" {
        didSet { UserDefaults.standard.set(displayLanguage, forKey: "lit.analysisLang") }
    }
    @Published var provider: String = UserDefaults.standard.string(forKey: "lit.analysisProvider") ?? "openrouter" {
        didSet { UserDefaults.standard.set(provider, forKey: "lit.analysisProvider") }
    }

    private var sseStream: SSEStream?
    let api: API
    init(api: API) { self.api = api }

    func analyze(entryId: Int, onDone: @escaping () -> Void) {
        status = .extracting
        error = nil
        totalPages = 0
        processedPages = 0
        totalChunks = 0
        currentChunk = 0
        let url = URL(string: Config.apiBase + "/api/literature/entries/\(entryId)/analyze")!
        let body: [String: Any] = ["provider": provider]
        sseStream = SSEStream(
            url: url,
            body: body,
            token: api.auth.auth?.access_token,
            onEvent: { [weak self] payload in
                guard let self = self else { return }
                guard let data = payload.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String else { return }
                Task { @MainActor in
                    switch type {
                    case "progress":
                        if let phase = json["phase"] as? String,
                           let s = Status(rawValue: phase) {
                            self.status = s
                        }
                        if let p = json["processed"] as? Int { self.processedPages = p }
                        if let t = json["total"] as? Int { self.totalPages = t }
                        if let cc = json["current_chunk"] as? Int { self.currentChunk = cc }
                        if let tc = json["total_chunks"] as? Int { self.totalChunks = tc }
                    case "complete", "done":
                        self.status = .done
                        onDone()
                    case "error":
                        self.error = json["message"] as? String ?? "Fehler bei Analyse"
                        self.status = .error
                    default: break
                    }
                }
            },
            onComplete: { [weak self] err in
                Task { @MainActor in
                    if let e = err, (e as NSError).code != NSURLErrorCancelled {
                        self?.error = e.localizedDescription
                        self?.status = .error
                    } else if self?.status != .error && self?.status != .done {
                        self?.status = .done
                        onDone()
                    }
                }
            }
        )
        sseStream?.start()
    }

    func cancel() {
        sseStream?.cancel()
        sseStream = nil
        status = .idle
    }

    func translateAnalysis(entryId: Int) async {
        translatingAnalysis = true
        defer { translatingAnalysis = false }
        _ = try? await api.translateAnalysis(entryId)
    }
}

// AnyCodable accessors
extension AnyCodable {
    var asDict: [String: Any]? { value as? [String: Any] }
    var asArray: [Any]? { value as? [Any] }
    var asString: String? { value as? String }
    var asInt: Int? { value as? Int }
}

@MainActor
final class RelationsStore: ObservableObject {
    @Published var relations: [EntryRelation] = []
    @Published var loading: Bool = false
    let api: API
    init(api: API) { self.api = api }

    func loadNetwork(collectionId: Int? = nil) async {
        loading = true
        if let r = try? await api.networkRelations(collectionId: collectionId) {
            relations = r
        }
        loading = false
    }

    func create(sourceId: Int, targetId: Int, type: String, notes: String) async {
        if let r = try? await api.createRelation(sourceId: sourceId, targetId: targetId, type: type, notes: notes) {
            relations.append(r)
        }
    }

    func delete(_ id: Int) async {
        try? await api.deleteRelation(id)
        relations.removeAll { $0.id == id }
    }
}

@MainActor
final class RAGStore: ObservableObject {
    @Published var query: String = ""
    @Published var results: [[String: Any]] = []
    @Published var loading: Bool = false
    @Published var indexing: Bool = false
    let api: API
    init(api: API) { self.api = api }

    func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true
        results = (try? await api.ragSearch(query: q)) ?? []
        loading = false
    }

    func indexAll() async {
        indexing = true
        try? await api.ragIndexAll()
        indexing = false
    }
}

@MainActor
final class AnnotationsStore: ObservableObject {
    @Published var highlights: [PdfHighlight] = []
    @Published var translations: [TranslationEntry] = []
    @Published var methodExplanations: [MethodEntry] = []
    @Published var agentQA: [AgentQAEntry] = []

    private var saveTask: Task<Void, Never>? = nil
    private var currentEntryId: Int? = nil
    let api: API
    init(api: API) { self.api = api }

    func load(entryId: Int) async {
        currentEntryId = entryId
        if let bundle = try? await api.getAnnotations(entryId) {
            highlights = bundle.highlights
            translations = bundle.translations
            methodExplanations = bundle.methodExplanations
            agentQA = bundle.agentQA
        } else {
            highlights = []
            translations = []
            methodExplanations = []
            agentQA = []
        }
    }

    func clear() {
        currentEntryId = nil
        highlights = []
        translations = []
        methodExplanations = []
        agentQA = []
    }

    func saveDebounced() {
        guard let id = currentEntryId else { return }
        let bundle = AnnotationsBundle(
            translations: translations,
            highlights: highlights,
            methodExplanations: methodExplanations,
            agentQA: agentQA
        )
        saveTask?.cancel()
        saveTask = Task { [bundle] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if Task.isCancelled { return }
            try? await self.api.saveAnnotations(id, bundle)
        }
    }

    func addHighlight(_ h: PdfHighlight) {
        highlights.append(h)
        saveDebounced()
    }

    func updateHighlights(_ hs: [PdfHighlight]) {
        highlights = hs
        saveDebounced()
    }

    func removeHighlight(id: String) {
        highlights.removeAll { $0.id == id }
        // Cascade: remove associated translation/method
        translations.removeAll { $0.highlightId == id }
        methodExplanations.removeAll { $0.highlightId == id }
        saveDebounced()
    }

    func addTranslation(_ t: TranslationEntry) {
        translations.append(t)
        saveDebounced()
    }

    func removeTranslation(id: String) {
        if let t = translations.first(where: { $0.id == id }), let hid = t.highlightId {
            highlights.removeAll { $0.id == hid }
        }
        translations.removeAll { $0.id == id }
        saveDebounced()
    }

    func addMethod(_ m: MethodEntry) {
        methodExplanations.append(m)
        saveDebounced()
    }

    func removeMethod(id: String) {
        if let m = methodExplanations.first(where: { $0.id == id }), let hid = m.highlightId {
            highlights.removeAll { $0.id == hid }
        }
        methodExplanations.removeAll { $0.id == id }
        saveDebounced()
    }

    func addAgentQA(_ qa: AgentQAEntry) {
        agentQA.append(qa)
        saveDebounced()
    }

    func removeAgentQA(id: String) {
        agentQA.removeAll { $0.id == id }
        saveDebounced()
    }
}

// ============================================================
// MARK: - LoginView
// ============================================================

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var phase: Phase = .idle
    @State private var userCode: String = ""
    @State private var deviceCode: String = ""
    @State private var verificationURL: String = ""
    @State private var error: String?
    @State private var pollTask: Task<Void, Never>?

    enum Phase { case idle, waiting }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(T.accent)

            VStack(spacing: 4) {
                Text("Literatur")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("ConsultingOS")
                    .font(.system(size: 11, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(T.text2)
                    .textCase(.uppercase)
            }
            Spacer().frame(height: 6)

            Group {
                switch phase {
                case .idle:
                    Button(action: startLogin) {
                        HStack(spacing: 8) {
                            Image(systemName: "safari")
                            Text("Mit Browser anmelden")
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22).padding(.vertical, 11)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                case .waiting:
                    VStack(spacing: 12) {
                        Text("Im Browser bestätigen")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(T.text3)
                            .textCase(.uppercase)
                        Text(userCode)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(T.accent)
                            .tracking(8)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(T.accentSoft)
                        ProgressView().controlSize(.small).tint(T.text2)
                        HStack(spacing: 14) {
                            Button("Browser erneut öffnen") {
                                if let u = URL(string: verificationURL) { NSWorkspace.shared.open(u) }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                            Text("·").foregroundStyle(T.text3)
                            Button("Abbrechen") { cancelLogin() }
                                .buttonStyle(.plain)
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                        }
                    }
                }
            }
            .frame(minHeight: 110)

            if let e = error {
                Text(e).font(.system(size: 11)).foregroundStyle(.red.opacity(0.85))
            }
            Spacer()
            Text("Geteilt mit Kanban / Zeit / Termine · Token bleibt 30 Tage gültig")
                .font(.system(size: 10))
                .foregroundStyle(T.text3)
                .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func startLogin() {
        error = nil
        Task {
            do {
                let url = URL(string: Config.apiBase + "/api/auth/mobile/device-code")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["device_name": Config.deviceName])
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dc = json["device_code"] as? String,
                      let uc = json["user_code"] as? String,
                      let vu = json["verification_url"] as? String
                else {
                    await MainActor.run { error = "Unerwartete Server-Antwort" }
                    return
                }
                await MainActor.run {
                    deviceCode = dc
                    userCode = uc
                    verificationURL = vu
                    withAnimation(.easeOut(duration: 0.2)) { phase = .waiting }
                }
                if let u = URL(string: vu) { NSWorkspace.shared.open(u) }
                pollTask = Task { await poll() }
            } catch {
                await MainActor.run { self.error = "Verbindung fehlgeschlagen" }
            }
        }
    }

    func cancelLogin() {
        pollTask?.cancel()
        pollTask = nil
        withAnimation(.easeOut(duration: 0.2)) { phase = .idle }
    }

    func poll() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if Task.isCancelled { return }
            do {
                let url = URL(string: Config.apiBase + "/api/auth/mobile/device-code/poll")!
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try JSONSerialization.data(withJSONObject: ["device_code": deviceCode])
                let (data, _) = try await URLSession.shared.data(for: req)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                let status = json["status"] as? String ?? "pending"
                if status == "approved",
                   let access = json["access_token"] as? String,
                   let refresh = json["refresh_token"] as? String {
                    let username = (json["user"] as? [String: Any])?["username"] as? String
                    let auth = AuthData(access_token: access, refresh_token: refresh, username: username)
                    authStore.save(auth)
                    return
                }
            } catch {}
        }
    }
}

// ============================================================
// MARK: - Window helpers
// ============================================================

struct TransparentWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.isOpaque = false
            w.backgroundColor = .clear
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.isMovableByWindowBackground = false
            w.hasShadow = false
            w.minSize = NSSize(width: 1100, height: 700)
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

final class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowDragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

@ViewBuilder
func modalOverlay<Content: View>(onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
    ZStack {
        Color.black.opacity(0.55)
            .ignoresSafeArea()
            .onTapGesture { onClose() }
        content()
            .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
    }
    .transition(.opacity)
}

// ============================================================
// MARK: - Top Bar
// ============================================================

struct TopBar: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var entriesStore: EntriesStore
    @Binding var showLogout: Bool
    let onNew: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onJournalRatings: () -> Void
    let onNetwork: () -> Void
    let onDictionary: () -> Void
    let onMethodBook: () -> Void
    let onReload: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onNew) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Neu")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(T.accent)
            }.buttonStyle(.plain)

            Button(action: onImport) {
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Import")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Button {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                panel.allowedContentTypes = [.zip]
                if panel.runModal() == .OK, let url = panel.url {
                    Task {
                        _ = try? await entriesStore.api.uploadMultipart("/api/literature/upload-zip", fileURL: url)
                        await entriesStore.reload()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.zipper")
                        .font(.system(size: 11, weight: .semibold))
                    Text("ZIP")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Button(action: onExport) {
                HStack(spacing: 4) {
                    Image(systemName: "tray.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Export")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Button(action: onJournalRatings) {
                HStack(spacing: 4) {
                    Image(systemName: "rosette")
                        .font(.system(size: 11, weight: .semibold))
                    Text("VHB")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Button(action: onNetwork) {
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Network")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Button(action: onDictionary) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.text2)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Button(action: onMethodBook) {
                Image(systemName: "function")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.text2)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Spacer()

            if entriesStore.loading {
                ProgressView().controlSize(.mini).tint(T.text2)
            }

            Button(action: onReload) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.text2)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Menu {
                if let username = authStore.auth?.username {
                    Text("Angemeldet als \(username)")
                }
                Button("Aktualisieren", action: onReload)
                Divider()
                Button("Abmelden", role: .destructive) { showLogout = true }
            } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(T.text2)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.04))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()

            Button {
                NSApp.keyWindow?.close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(T.text3)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12).padding(.bottom, 10)
        .background(WindowDragArea())
    }
}

// ============================================================
// MARK: - Sidebar
// ============================================================

struct Sidebar: View {
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var collectionsStore: CollectionsStore
    @EnvironmentObject var tagsStore: TagsStore
    @State private var collectionsExpanded: Bool = true
    @State private var tagsExpanded: Bool = true
    @State private var showArchived: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    smartListsSection
                    collectionsSection
                    tagsSection
                    Color.clear.frame(height: 24)
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            // Collapse button at bottom
            Button {
                NotificationCenter.default.post(name: .init("collapseSidebar"), object: nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                    Text("Einklappen")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(T.text3)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .top)
        }
    }

    // ----- Smart Lists -----
    var smartListsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            sectionHeader("BIBLIOTHEK")
            smartListRow(.all,       label: "Alle Einträge",  icon: "books.vertical", count: entriesStore.countAll)
            smartListRow(.favorites, label: "Favoriten",      icon: "star.fill",      count: entriesStore.countFavorites)
            smartListRow(.recent,    label: "Neu",            icon: "clock",          count: entriesStore.countRecent)
            smartListRow(.unread,    label: "Ungelesen",      icon: "doc",            count: entriesStore.countUnread)
            smartListRow(.rag,       label: "RAG-Suche",      icon: "magnifyingglass.circle", count: nil)
        }
    }

    func smartListRow(_ list: SmartList, label: String, icon: String, count: Int?) -> some View {
        let active = entriesStore.sidebarFilter == .smart(list)
        return Button {
            entriesStore.sidebarFilter = .smart(list)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(active ? T.accent : T.text2)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? T.text1 : T.text2)
                Spacer()
                if let c = count, c > 0 {
                    Text("\(c)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(active ? T.accentSoft : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // ----- Collections -----
    var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { collectionsExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: collectionsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(T.text3)
                        Text("COLLECTIONS")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(T.text3)
                    }
                }.buttonStyle(.plain)
                Spacer()
                Text("\(collectionsStore.collections.filter { !$0.is_archived }.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text3)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            if collectionsExpanded {
                ForEach(collectionsStore.collections.filter { !$0.is_archived }) { collection in
                    collectionRow(collection)
                }
                let archived = collectionsStore.collections.filter { $0.is_archived }
                if !archived.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showArchived.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: showArchived ? "chevron.down" : "chevron.right")
                                .font(.system(size: 7, weight: .bold))
                            Text("Archiviert (\(archived.count))")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                    }.buttonStyle(.plain)
                    if showArchived {
                        ForEach(archived) { collection in
                            collectionRow(collection)
                        }
                    }
                }
                if collectionsStore.collections.isEmpty {
                    Text("Keine Collections")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    func collectionRow(_ c: LiteratureCollection) -> some View {
        let active = entriesStore.sidebarFilter == .collection(c.id)
        let color = T.tagColor(c.color)
        return Button {
            entriesStore.sidebarFilter = .collection(c.id)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: c.is_archived ? "archivebox.fill" : "folder.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(active ? color : color.opacity(0.7))
                    .frame(width: 18)
                Text(c.name)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? T.text1 : T.text2)
                    .lineLimit(1)
                Spacer()
                if c.entry_count > 0 {
                    Text("\(c.entry_count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(active ? T.accentSoft : Color.clear)
        }
        .buttonStyle(.plain)
        .dropDestination(for: String.self) { items, _ in
            guard let item = items.first, item.hasPrefix("litentry-"),
                  let entryId = Int(String(item.dropFirst(9))) else { return false }
            Task {
                try? await collectionsStore.api.addEntriesToCollection(collectionId: c.id, entryIds: [entryId])
                await collectionsStore.reload()
                await entriesStore.reload()
            }
            return true
        }
        .contextMenu {
            Button("Umbenennen") {
                // Simple rename via prompt (no modal needed)
                let alert = NSAlert()
                alert.messageText = "Collection umbenennen"
                alert.addButton(withTitle: "Speichern")
                alert.addButton(withTitle: "Abbrechen")
                let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
                input.stringValue = c.name
                alert.accessoryView = input
                if alert.runModal() == .alertFirstButtonReturn {
                    Task { _ = try? await collectionsStore.api.updateCollection(c.id, ["name": input.stringValue]); await collectionsStore.reload() }
                }
            }
            Button(c.is_archived ? "Wiederherstellen" : "Archivieren") {
                Task { _ = try? await collectionsStore.api.toggleArchiveCollection(c.id); await collectionsStore.reload() }
            }
            Divider()
            Button("Löschen", role: .destructive) {
                Task { try? await collectionsStore.api.deleteCollection(c.id); await collectionsStore.reload() }
            }
        }
    }

    // ----- Tags -----
    var tagsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { tagsExpanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: tagsExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(T.text3)
                        Text("TAGS")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(T.text3)
                    }
                }.buttonStyle(.plain)
                Spacer()
                Text("\(tagsStore.tags.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text3)
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            if tagsExpanded {
                ForEach(tagsStore.tags) { tag in
                    tagRow(tag)
                }
                if tagsStore.tags.isEmpty {
                    Text("Keine Tags")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    func tagRow(_ tag: LiteratureTag) -> some View {
        let active = entriesStore.sidebarFilter == .tag(tag.id)
        let color = T.tagColor(tag.color)
        return Button {
            entriesStore.sidebarFilter = .tag(tag.id)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .padding(.leading, 5)
                    .frame(width: 18)
                Text(tag.name)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? T.text1 : T.text2)
                    .lineLimit(1)
                Spacer()
                if tag.entry_count > 0 {
                    Text("\(tag.entry_count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(active ? T.accentSoft : Color.clear)
        }
        .buttonStyle(.plain)
    }

    func sectionHeader(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(T.text3)
            .padding(.horizontal, 4)
            .padding(.bottom, 2)
    }
}

// ============================================================
// MARK: - Entry list
// ============================================================

struct EntryListHeader: View {
    @EnvironmentObject var entriesStore: EntriesStore

    var headerTitle: String {
        switch entriesStore.sidebarFilter {
        case .smart(.all):       return "Alle Einträge"
        case .smart(.favorites): return "Favoriten"
        case .smart(.recent):    return "Neu hinzugefügt"
        case .smart(.unread):    return "Ungelesen"
        case .smart(.rag):       return "RAG-Suche"
        case .collection(let id):
            return "Collection"
                + (entriesStore.entries.first(where: { $0.collection_ids.contains(id) }).map { _ in "" } ?? "")
        case .tag:               return "Tag"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(T.text3)
                    TextField("Suchen…", text: $entriesStore.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                Spacer()

                Menu {
                    ForEach(SortBy.allCases, id: \.self) { sort in
                        Button {
                            entriesStore.sortBy = sort
                        } label: {
                            HStack {
                                if entriesStore.sortBy == sort {
                                    Image(systemName: "checkmark")
                                }
                                Text(sort.label)
                            }
                        }
                    }
                    Divider()
                    Button {
                        entriesStore.sortAscending.toggle()
                    } label: {
                        HStack {
                            Image(systemName: entriesStore.sortAscending ? "arrow.up" : "arrow.down")
                            Text(entriesStore.sortAscending ? "Aufsteigend" : "Absteigend")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 10, weight: .semibold))
                        Text(entriesStore.sortBy.label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()

                HStack(spacing: 0) {
                    Button { entriesStore.viewMode = .list } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(entriesStore.viewMode == .list ? T.text1 : T.text3)
                            .frame(width: 26, height: 26)
                            .background(entriesStore.viewMode == .list ? T.accentSoft : Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                    Button { entriesStore.viewMode = .cards } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(entriesStore.viewMode == .cards ? T.text1 : T.text3)
                            .frame(width: 26, height: 26)
                            .background(entriesStore.viewMode == .cards ? T.accentSoft : Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                }
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            HStack {
                Text("\(entriesStore.filteredEntries.count) Einträge")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(T.text3)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
        }
        .background(T.bg.opacity(0.4))
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(T.line),
            alignment: .bottom
        )
    }
}

struct EntryListView: View {
    @EnvironmentObject var entriesStore: EntriesStore

    var body: some View {
        ScrollView(showsIndicators: true) {
            if entriesStore.viewMode == .list {
                LazyVStack(spacing: 6) {
                    ForEach(entriesStore.filteredEntries) { entry in
                        EntryListItem(entry: entry)
                    }
                    Color.clear.frame(height: 20)
                }
                .padding(14)
            } else {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 10)
                ], spacing: 10) {
                    ForEach(entriesStore.filteredEntries) { entry in
                        EntryCardItem(entry: entry)
                    }
                }
                .padding(14)
            }

            if entriesStore.filteredEntries.isEmpty && !entriesStore.loading {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(T.text3)
                    Text("Keine Einträge")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(T.text2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            }
        }
    }
}

struct EntryListItem: View {
    let entry: LiteratureEntry
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var hover = false

    var isSelected: Bool { entriesStore.selectedEntryId == entry.id }

    // Draggable for cross-collection drag-drop
    var dragString: String { "litentry-\(entry.id)" }

    var body: some View {
        Button {
            Task { await entriesStore.loadDetail(entry.id) }
        } label: {
            HStack(spacing: 0) {
                Rectangle()
                    .fill(T.statusColor(entry.reading_status))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(entry.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(T.text1)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if entry.is_favorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(T.star)
                        }
                        if entry.pdf_url != nil {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                        if entry.research_analysis != nil {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                                .foregroundStyle(T.accent)
                        }
                    }

                    HStack(spacing: 8) {
                        if !entry.authors.isEmpty {
                            Text(T.formatAuthors(entry.authors))
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                                .lineLimit(1)
                        }
                        if let year = entry.year {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                            Text(String(year))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(T.text3)
                        }
                        if !entry.journal.isEmpty {
                            Text("·")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                            Text(entry.journal)
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }

                    if !entry.tags.isEmpty || !entry.journal_rating.isEmpty || !entry.entry_type.isEmpty {
                        HStack(spacing: 5) {
                            if !entry.entry_type.isEmpty && entry.entry_type != "article" {
                                Text(entry.entry_type.uppercased())
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(T.text3)
                                    .padding(.horizontal, 4).padding(.vertical, 1)
                                    .background(Color.white.opacity(0.06))
                            }
                            if !entry.journal_rating.isEmpty {
                                Text(entry.journal_rating)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(T.journalRatingColor(entry.journal_rating))
                            }
                            ForEach(entry.tags.prefix(4)) { tag in
                                Text(tag.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(T.tagColor(tag.color))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(T.tagColor(tag.color).opacity(0.18))
                            }
                            if entry.tags.count > 4 {
                                Text("+\(entry.tags.count - 4)")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(T.text3)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? T.accentSoft : (hover ? T.cardHover : T.card))
            .overlay(Rectangle().stroke(isSelected ? T.accent.opacity(0.5) : T.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .draggable(dragString)
        .onTapGesture(count: 2) {
            Task {
                await entriesStore.loadDetail(entry.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .init("openAnalysis"), object: entry.id)
                }
            }
        }
    }
}

struct EntryCardItem: View {
    let entry: LiteratureEntry
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var hover = false

    var isSelected: Bool { entriesStore.selectedEntryId == entry.id }

    var body: some View {
        Button {
            Task { await entriesStore.loadDetail(entry.id) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Rectangle()
                        .fill(T.statusColor(entry.reading_status))
                        .frame(width: 3, height: 28)
                    Text(entry.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(T.text1)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if entry.is_favorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(T.star)
                    }
                }

                if !entry.authors.isEmpty {
                    Text(T.formatAuthors(entry.authors))
                        .font(.system(size: 10))
                        .foregroundStyle(T.text2)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let year = entry.year {
                        Text(String(year))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(T.text3)
                    }
                    if !entry.journal.isEmpty {
                        Text(entry.journal)
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if !entry.journal_rating.isEmpty {
                        Text(entry.journal_rating)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(T.journalRatingColor(entry.journal_rating))
                    }
                }

                if !entry.abstract.isEmpty {
                    Text(entry.abstract)
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                if !entry.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(entry.tags.prefix(3)) { tag in
                            Text(tag.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(T.tagColor(tag.color))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(T.tagColor(tag.color).opacity(0.18))
                        }
                        if entry.tags.count > 3 {
                            Text("+\(entry.tags.count - 3)")
                                .font(.system(size: 9))
                                .foregroundStyle(T.text3)
                        }
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 6) {
                    if entry.pdf_url != nil {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(T.text3)
                    }
                    if entry.research_analysis != nil {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(T.accent)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isSelected ? T.accentSoft : (hover ? T.cardHover : T.card))
            .overlay(Rectangle().stroke(isSelected ? T.accent.opacity(0.5) : T.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .onTapGesture(count: 2) {
            Task {
                await entriesStore.loadDetail(entry.id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .init("openAnalysis"), object: entry.id)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Detail Pane (right column)
// ============================================================

struct DetailPane: View {
    let entry: LiteratureEntry
    let onOpenAnalysis: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var collectionsStore: CollectionsStore
    @EnvironmentObject var tagsStore: TagsStore
    @State private var notes: String
    @State private var notesDebounce: Task<Void, Never>? = nil
    @State private var showEditForm = false
    @State private var showCitationModal = false
    @State private var showDeleteConfirm = false
    @State private var pendingTagPicker = false
    @State private var uploadingPdf = false

    init(entry: LiteratureEntry, onOpenAnalysis: @escaping () -> Void) {
        self.entry = entry
        self.onOpenAnalysis = onOpenAnalysis
        _notes = State(initialValue: entry.notes)
    }

    func pickAndUploadPdf() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK, let url = panel.url {
            uploadingPdf = true
            Task {
                if let updated = try? await entriesStore.api.uploadPdf(entryId: entry.id, fileURL: url) {
                    entriesStore.selectedDetail = updated
                    if let i = entriesStore.entries.firstIndex(where: { $0.id == updated.id }) {
                        entriesStore.entries[i] = updated
                    }
                }
                uploadingPdf = false
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Title
                Text(entry.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(T.text1)
                    .lineLimit(5)

                // Authors + year + journal
                if !entry.authors.isEmpty {
                    Text(T.formatAuthors(entry.authors, max: 8))
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                }
                HStack(spacing: 6) {
                    if !entry.entry_type.isEmpty {
                        Text(entry.entry_type.uppercased())
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color.white.opacity(0.06))
                    }
                    if let y = entry.year {
                        Text(String(y))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(T.text2)
                    }
                    if !entry.journal.isEmpty {
                        Text("·").foregroundStyle(T.text3).font(.system(size: 11))
                        Text(entry.journal)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(T.text2)
                            .lineLimit(2)
                    }
                }

                // Additional metadata
                VStack(alignment: .leading, spacing: 3) {
                    if !entry.volume.isEmpty || !entry.issue.isEmpty || !entry.pages.isEmpty {
                        HStack(spacing: 6) {
                            if !entry.volume.isEmpty { metaLabel("Vol.", entry.volume) }
                            if !entry.issue.isEmpty { metaLabel("Issue", entry.issue) }
                            if !entry.pages.isEmpty { metaLabel("S.", entry.pages) }
                        }
                    }
                    if !entry.isbn.isEmpty { metaLabel("ISBN", entry.isbn) }
                    if !entry.url.isEmpty {
                        Button {
                            if let u = URL(string: entry.url) { NSWorkspace.shared.open(u) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 9))
                                Text(entry.url)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(T.accent)
                        }.buttonStyle(.plain)
                    }
                    if let cc = entry.citation_count {
                        metaLabel("Zitiert", "\(cc)×")
                    }
                    if !entry.keywords.isEmpty {
                        FlowLayout(spacing: 4) {
                            ForEach(entry.keywords, id: \.self) { kw in
                                Text(kw)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(T.text3)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Color.white.opacity(0.04))
                            }
                        }
                    }
                }

                // Action row
                HStack(spacing: 6) {
                    Button {
                        Task { await entriesStore.toggleFavorite(entry.id) }
                    } label: {
                        Image(systemName: entry.is_favorite ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundStyle(entry.is_favorite ? T.star : T.text3)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)

                    Button {
                        showEditForm = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)

                    Button {
                        showCitationModal = true
                    } label: {
                        Image(systemName: "text.quote")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)

                    if let doi = entry.doi.isEmpty ? nil : entry.doi {
                        Button {
                            if let u = URL(string: "https://doi.org/\(doi)") { NSWorkspace.shared.open(u) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 9))
                                Text("DOI")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(T.text2)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.white.opacity(0.04))
                        }.buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.red.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.red.opacity(0.06))
                    }.buttonStyle(.plain)
                }

                // PDF + Analyse buttons
                if entry.pdf_url != nil {
                    Button {
                        onOpenAnalysis()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.richtext")
                                .font(.system(size: 11, weight: .semibold))
                            Text("PDF + Analyse öffnen")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                            if let size = entry.pdf_file_size {
                                Text(formatBytes(size))
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                } else {
                    Button(action: pickAndUploadPdf) {
                        HStack(spacing: 6) {
                            if uploadingPdf {
                                ProgressView().controlSize(.mini).tint(.white)
                            } else {
                                Image(systemName: "tray.and.arrow.up")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            Text(uploadingPdf ? "Lade hoch…" : "PDF hochladen")
                                .font(.system(size: 11, weight: .semibold))
                            Spacer()
                        }
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    }.buttonStyle(.plain)
                    .disabled(uploadingPdf)
                }

                Divider().background(T.line)

                // Status picker
                fieldLabel("LESESTATUS")
                HStack(spacing: 4) {
                    ForEach(["unread", "reading", "read", "annotated"], id: \.self) { status in
                        Button {
                            Task { _ = await entriesStore.update(entry.id, ["reading_status": status]) }
                        } label: {
                            Text(T.statusLabel(status))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(entry.reading_status == status ? T.text1 : T.text3)
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(entry.reading_status == status ? T.statusColor(status).opacity(0.25) : Color.white.opacity(0.03))
                                .overlay(
                                    Rectangle().stroke(
                                        entry.reading_status == status ? T.statusColor(status).opacity(0.6) : T.line,
                                        lineWidth: 0.5
                                    )
                                )
                        }.buttonStyle(.plain)
                    }
                }

                // Rating (5 stars)
                fieldLabel("BEWERTUNG")
                HStack(spacing: 3) {
                    ForEach(1...5, id: \.self) { i in
                        Button {
                            let newRating = (entry.rating == i) ? 0 : i
                            Task { _ = await entriesStore.update(entry.id, ["rating": newRating]) }
                        } label: {
                            Image(systemName: i <= entry.rating ? "star.fill" : "star")
                                .font(.system(size: 12))
                                .foregroundStyle(i <= entry.rating ? T.star : T.text3)
                        }.buttonStyle(.plain)
                    }
                    if !entry.journal_rating.isEmpty {
                        Spacer()
                        Text(entry.journal_rating)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(T.journalRatingColor(entry.journal_rating))
                    }
                }

                // Tags
                fieldLabel("TAGS")
                FlexibleTagsRow(
                    tags: entry.tags,
                    allTags: tagsStore.tags,
                    onAdd: { tag in
                        let newTagIds = (entry.tags.map { $0.id } + [tag.id]).uniqued()
                        Task { _ = await entriesStore.update(entry.id, ["tag_ids": newTagIds]) }
                    },
                    onRemove: { tag in
                        let newTagIds = entry.tags.map { $0.id }.filter { $0 != tag.id }
                        Task { _ = await entriesStore.update(entry.id, ["tag_ids": newTagIds]) }
                    }
                )

                // Collections
                if !entry.collection_ids.isEmpty {
                    fieldLabel("COLLECTIONS")
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(entry.collection_ids, id: \.self) { cid in
                            if let c = collectionsStore.collections.first(where: { $0.id == cid }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(T.tagColor(c.color))
                                    Text(c.name)
                                        .font(.system(size: 11))
                                        .foregroundStyle(T.text2)
                                    Spacer()
                                }
                            }
                        }
                    }
                }

                // Abstract
                if !entry.abstract.isEmpty {
                    fieldLabel("ABSTRACT")
                    Text(entry.abstract)
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                        .lineLimit(8)
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color.white.opacity(0.02))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }

                // Notes (auto-save with debounce)
                fieldLabel("NOTIZEN")
                ZStack(alignment: .topLeading) {
                    if notes.isEmpty {
                        Text("Eigene Notizen…")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3.opacity(0.7))
                            .padding(.horizontal, 10).padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $notes)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 11))
                        .foregroundStyle(T.text1)
                        .frame(minHeight: 80)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                }
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                .onChange(of: notes) { _, newVal in
                    notesDebounce?.cancel()
                    notesDebounce = Task {
                        try? await Task.sleep(nanoseconds: 800_000_000)
                        if Task.isCancelled { return }
                        _ = await entriesStore.update(entry.id, ["notes": newVal])
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(14)
        }
        .sheet(isPresented: $showEditForm) {
            EntryFormModal(existing: entry, onClose: { showEditForm = false })
        }
        .sheet(isPresented: $showCitationModal) {
            CitationModal(entry: entry, onClose: { showCitationModal = false })
        }
        .confirmationDialog(
            "Eintrag wirklich löschen?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                Task { await entriesStore.delete(entry.id) }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    func fieldLabel(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(T.text3)
    }

    func metaLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(T.text3)
            Text(value)
                .font(.system(size: 10))
                .foregroundStyle(T.text2)
        }
    }

    func formatBytes(_ b: Int) -> String {
        if b >= 1_000_000 { return String(format: "%.1f MB", Double(b) / 1_000_000.0) }
        if b >= 1_000 { return String(format: "%.0f KB", Double(b) / 1_000.0) }
        return "\(b) B"
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

struct FlexibleTagsRow: View {
    let tags: [LiteratureTag]
    let allTags: [LiteratureTag]
    let onAdd: (LiteratureTag) -> Void
    let onRemove: (LiteratureTag) -> Void
    @State private var menuOpen = false

    var availableTags: [LiteratureTag] {
        let activeIds = Set(tags.map { $0.id })
        return allTags.filter { !activeIds.contains($0.id) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        FlowLayout(spacing: 4) {
            ForEach(tags) { tag in
                HStack(spacing: 4) {
                    Text(tag.name)
                        .font(.system(size: 10, weight: .medium))
                    Button { onRemove(tag) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                    }.buttonStyle(.plain)
                }
                .foregroundStyle(T.tagColor(tag.color))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(T.tagColor(tag.color).opacity(0.18))
            }
            Menu {
                if availableTags.isEmpty {
                    Text("Keine weiteren Tags")
                } else {
                    ForEach(availableTags) { tag in
                        Button(tag.name) { onAdd(tag) }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                    Text("Tag")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(T.text3)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.white.opacity(0.04))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}

// Simple flow layout (wrap items)
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalH: CGFloat = 0
        var rowW: CGFloat = 0
        var rowH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if rowW + size.width > maxWidth {
                totalH += rowH + spacing
                rowW = size.width + spacing
                rowH = size.height
            } else {
                rowW += size.width + spacing
                rowH = max(rowH, size.height)
            }
        }
        totalH += rowH
        return CGSize(width: maxWidth.isFinite ? maxWidth : rowW, height: totalH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > maxWidth {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// ============================================================
// MARK: - Modals
// ============================================================

struct EntryFormModal: View {
    let existing: LiteratureEntry?
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore

    @State private var title: String
    @State private var authors: String
    @State private var year: String
    @State private var journal: String
    @State private var volume: String
    @State private var issue: String
    @State private var pages: String
    @State private var publisher: String
    @State private var booktitle: String
    @State private var doi: String
    @State private var isbn: String
    @State private var entryUrl: String
    @State private var abstract: String
    @State private var keywords: String
    @State private var entryType: String
    @State private var saving: Bool = false
    @State private var showDOILookup = false

    init(existing: LiteratureEntry?, onClose: @escaping () -> Void) {
        self.existing = existing
        self.onClose = onClose
        _title = State(initialValue: existing?.title ?? "")
        _authors = State(initialValue: (existing?.authors ?? []).map { "\($0.first) \($0.last)" }.joined(separator: "; "))
        _year = State(initialValue: existing?.year.map(String.init) ?? "")
        _journal = State(initialValue: existing?.journal ?? "")
        _volume = State(initialValue: existing?.volume ?? "")
        _issue = State(initialValue: existing?.issue ?? "")
        _pages = State(initialValue: existing?.pages ?? "")
        _publisher = State(initialValue: existing?.publisher ?? "")
        _booktitle = State(initialValue: existing?.booktitle ?? "")
        _doi = State(initialValue: existing?.doi ?? "")
        _isbn = State(initialValue: existing?.isbn ?? "")
        _entryUrl = State(initialValue: existing?.url ?? "")
        _abstract = State(initialValue: existing?.abstract ?? "")
        _keywords = State(initialValue: (existing?.keywords ?? []).joined(separator: ", "))
        _entryType = State(initialValue: existing?.entry_type ?? "article")
    }

    var isEditing: Bool { existing != nil }

    var parsedAuthors: [[String: String]] {
        authors.split(separator: ";").map { part in
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            let words = trimmed.split(separator: " ")
            if words.count >= 2 {
                return ["first": words.dropLast().joined(separator: " "), "last": String(words.last!)]
            }
            return ["first": "", "last": trimmed]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Text(isEditing ? "Eintrag bearbeiten" : "Neuer Eintrag")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    formField("Titel", text: $title, multiline: true)

                    HStack(spacing: 8) {
                        formField("Jahr", text: $year).frame(width: 80)
                        formField("Typ", text: $entryType).frame(width: 120)
                        Spacer()
                    }

                    formField("Autoren (Vorname Nachname; …)", text: $authors)

                    formField("Journal / Konferenz", text: $journal)

                    HStack(spacing: 8) {
                        formField("Volume", text: $volume).frame(width: 80)
                        formField("Issue", text: $issue).frame(width: 80)
                        formField("Pages", text: $pages).frame(width: 100)
                        Spacer()
                    }

                    formField("Publisher", text: $publisher)
                    formField("Booktitle (Konferenzband)", text: $booktitle)

                    HStack(alignment: .bottom, spacing: 6) {
                        formField("DOI", text: $doi)
                        Button("Lookup") {
                            showDOILookup = true
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(T.accent)
                    }

                    HStack(spacing: 8) {
                        formField("ISBN", text: $isbn)
                        formField("URL", text: $entryUrl)
                    }

                    formField("Keywords (komma-getrennt)", text: $keywords)

                    fieldLabel("ABSTRACT")
                    TextEditor(text: $abstract)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 11))
                        .foregroundStyle(T.text1)
                        .frame(height: 100)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .padding(.horizontal, 18).padding(.bottom, 14)
            }
            .frame(maxHeight: 500)

            Divider().background(T.line)
            HStack {
                Spacer()
                Button(action: onClose) {
                    Text("Abbrechen")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                }.buttonStyle(.plain)

                Button {
                    saving = true
                    Task {
                        var fields: [String: Any] = [
                            "title": title,
                            "authors": parsedAuthors,
                            "journal": journal,
                            "volume": volume,
                            "issue": issue,
                            "pages": pages,
                            "publisher": publisher,
                            "booktitle": booktitle,
                            "doi": doi,
                            "isbn": isbn,
                            "url": entryUrl,
                            "abstract": abstract,
                            "keywords": keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                            "entry_type": entryType,
                        ]
                        if let y = Int(year) { fields["year"] = y }
                        if let e = existing {
                            _ = await entriesStore.update(e.id, fields)
                        } else {
                            _ = try? await entriesStore.api.createEntry(fields)
                            await entriesStore.reload()
                        }
                        saving = false
                        onClose()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().controlSize(.mini).tint(.white) }
                        Text(isEditing ? "Speichern" : "Erstellen")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(T.accent)
                }
                .buttonStyle(.plain)
                .disabled(saving || title.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 540)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .sheet(isPresented: $showDOILookup) {
            DOILookupModal(initialDOI: doi, onClose: { showDOILookup = false }, onResult: { result in
                if let t = result["title"] as? String { title = t }
                if let y = result["year"] as? Int { year = "\(y)" }
                if let j = result["journal"] as? String { journal = j }
                if let d = result["doi"] as? String { doi = d }
                if let a = result["abstract"] as? String { abstract = a }
                if let auths = result["authors"] as? [[String: String]] {
                    authors = auths.map { "\($0["first"] ?? "") \($0["last"] ?? "")" }.joined(separator: "; ")
                }
            })
        }
    }

    func formField(_ label: String, text: Binding<String>, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            fieldLabel(label.uppercased())
            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(T.text1)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
    }

    func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(T.text3)
            .tracking(0.6)
    }
}

struct DOILookupModal: View {
    let initialDOI: String
    let onClose: () -> Void
    let onResult: ([String: Any]) -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var doi: String
    @State private var loading = false
    @State private var error: String?

    init(initialDOI: String, onClose: @escaping () -> Void, onResult: @escaping ([String: Any]) -> Void) {
        self.initialDOI = initialDOI
        self.onClose = onClose
        self.onResult = onResult
        _doi = State(initialValue: initialDOI)
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Text("DOI Lookup")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                Text("DOI eingeben (z.B. 10.1145/1234567):")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text2)
                TextField("10.1145/...", text: $doi)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                if let e = error {
                    Text(e).font(.system(size: 10)).foregroundStyle(.red.opacity(0.85))
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider().background(T.line)
            HStack {
                Spacer()
                Button("Abbrechen", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                Button {
                    loading = true
                    error = nil
                    Task {
                        do {
                            if let result = try await entriesStore.api.lookupDOI(doi) {
                                if let err = result["error"] as? String {
                                    error = err
                                } else {
                                    onResult(result)
                                    onClose()
                                }
                            } else {
                                error = "Keine Daten gefunden"
                            }
                        } catch {
                            self.error = "Fehler bei Lookup"
                        }
                        loading = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if loading { ProgressView().controlSize(.mini).tint(.white) }
                        Text("Nachschlagen")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(T.accent)
                }.buttonStyle(.plain)
                .disabled(loading || doi.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 460)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
    }
}

struct ImportBibtexModal: View {
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var collectionsStore: CollectionsStore
    @State private var bibtex: String = ""
    @State private var collectionId: Int? = nil
    @State private var importing = false
    @State private var result: String?

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Text("BibTeX Import")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                Text("BibTeX einfügen (mehrere Einträge möglich):")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text2)
                TextEditor(text: $bibtex)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(T.text1)
                    .frame(height: 240)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                Menu {
                    Button("Keine Collection") { collectionId = nil }
                    ForEach(collectionsStore.collections) { c in
                        Button(c.name) { collectionId = c.id }
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder")
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                        if let cid = collectionId, let c = collectionsStore.collections.first(where: { $0.id == cid }) {
                            Text(c.name)
                                .font(.system(size: 11))
                                .foregroundStyle(T.text1)
                        } else {
                            Text("Keine Collection")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                        }
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundStyle(T.text3)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)

                if let r = result {
                    Text(r).font(.system(size: 10)).foregroundStyle(T.success)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider().background(T.line)
            HStack {
                Spacer()
                Button("Abbrechen", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                Button {
                    importing = true
                    Task {
                        if let r = try? await entriesStore.api.importBibtex(content: bibtex, collectionId: collectionId) {
                            if let imported = r["imported"] as? Int {
                                result = "\(imported) Einträge importiert"
                            }
                            await entriesStore.reload()
                        }
                        importing = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if importing { ProgressView().controlSize(.mini).tint(.white) }
                        Text("Importieren")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(T.accent)
                }.buttonStyle(.plain)
                .disabled(importing || bibtex.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 600)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
    }
}

struct CitationModal: View {
    let entry: LiteratureEntry
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var style: String = "apa"
    @State private var citation: String = ""
    @State private var loading = false

    let styles = ["apa", "harvard", "ieee", "chicago", "mla", "bibtex"]

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Text("Zitation kopieren")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 4) {
                    ForEach(styles, id: \.self) { s in
                        Button {
                            style = s
                            loadCitation()
                        } label: {
                            Text(s.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(style == s ? T.text1 : T.text2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(style == s ? T.accentSoft : Color.white.opacity(0.04))
                                .overlay(Rectangle().stroke(style == s ? T.accent.opacity(0.55) : T.line, lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
                }
                ScrollView {
                    Text(citation.isEmpty ? "Lade…" : citation)
                        .font(.system(size: 12, design: style == "bibtex" ? .monospaced : .default))
                        .foregroundStyle(T.text1)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .frame(height: 160)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(citation, forType: .string)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                        Text("In Zwischenablage")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(T.accent)
                }.buttonStyle(.plain)
                .disabled(citation.isEmpty)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider().background(T.line)
            HStack {
                Spacer()
                Button("Schließen", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 600)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .onAppear { loadCitation() }
    }

    func loadCitation() {
        loading = true
        Task {
            if let r = try? await entriesStore.api.formatCitation(entry.id, style: style),
               let c = r["citation"] as? String {
                citation = c
            }
            loading = false
        }
    }
}

// ============================================================
// MARK: - PDF Viewer (PDFKit)
// ============================================================

enum ActiveTool: String {
    case read, highlight, translate, method
}

final class PDFViewerCoordinator: NSObject {
    var activeTool: ActiveTool = .read
    var onTextSelected: ((String, Int, [PdfHighlightRect]) -> Void)?
    var onHighlightAdded: ((PdfHighlight) -> Void)?
    var pdfView: PDFView?

    @objc func selectionChanged(_ notification: Notification) {
        guard let view = pdfView,
              let selection = view.currentSelection,
              let text = selection.string,
              !text.isEmpty else { return }
        guard let firstPage = selection.pages.first,
              let pageIdx = view.document?.index(for: firstPage) else { return }
        let pageNum = pageIdx + 1
        let pageBounds = firstPage.bounds(for: .mediaBox)

        var rects: [PdfHighlightRect] = []
        for lineSel in selection.selectionsByLine() {
            for page in lineSel.pages {
                let bounds = lineSel.bounds(for: page)
                // Store as PERCENT (0–100) to match web format
                rects.append(PdfHighlightRect(
                    x: (bounds.minX / pageBounds.width) * 100.0,
                    y: (1.0 - (bounds.maxY / pageBounds.height)) * 100.0,
                    width: (bounds.width / pageBounds.width) * 100.0,
                    height: (bounds.height / pageBounds.height) * 100.0
                ))
            }
        }
        guard !rects.isEmpty else { return }

        if activeTool == .highlight {
            let h = PdfHighlight(
                id: UUID().uuidString,
                pageNumber: pageNum,
                color: "yellow",
                rects: rects,
                text: text,
                translated: nil
            )
            onHighlightAdded?(h)
            view.clearSelection()
        } else if activeTool == .translate || activeTool == .method {
            onTextSelected?(text, pageNum, rects)
        }
    }
}

struct PDFViewerWrapper: NSViewRepresentable {
    let pdfURL: URL
    let highlights: [PdfHighlight]
    let activeTool: ActiveTool
    let zoomLevel: CGFloat
    let sepiaMode: Bool
    let onHighlightAdded: (PdfHighlight) -> Void
    let onTextSelected: (String, Int, [PdfHighlightRect]) -> Void
    let onPageChange: (Int, Int) -> Void
    @Binding var jumpToPage: Int?

    func makeCoordinator() -> PDFViewerCoordinator {
        let c = PDFViewerCoordinator()
        c.activeTool = activeTool
        c.onTextSelected = onTextSelected
        c.onHighlightAdded = onHighlightAdded
        return c
    }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: pdfURL)
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        // Aggressively clear ALL internal backgrounds so transparency works with colorInvert
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            Self.forceTransparent(view)
        }
        view.pageBreakMargins = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view.wantsLayer = true
        context.coordinator.pdfView = view
        applyHighlights(to: view)
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(PDFViewerCoordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: view
        )
        // Restore scroll position per entry
        let key = "pdf-page-\(pdfURL.lastPathComponent)"
        let savedPage = UserDefaults.standard.integer(forKey: key)
        if savedPage > 0, let doc = view.document, savedPage - 1 < doc.pageCount,
           let page = doc.page(at: savedPage - 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                view.go(to: page)
            }
        }
        // Save page on scroll + report page change
        let total = view.document?.pageCount ?? 0
        NotificationCenter.default.addObserver(
            forName: .PDFViewPageChanged,
            object: view,
            queue: .main
        ) { [onPageChange] _ in
            if let cp = view.currentPage,
               let idx = view.document?.index(for: cp) {
                UserDefaults.standard.set(idx + 1, forKey: key)
                onPageChange(idx + 1, total)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onPageChange(1, total)
        }
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        context.coordinator.activeTool = activeTool
        context.coordinator.onTextSelected = onTextSelected
        context.coordinator.onHighlightAdded = onHighlightAdded
        applyHighlights(to: view)
        // Zoom
        if abs(view.scaleFactor - zoomLevel) > 0.01 {
            view.scaleFactor = zoomLevel
        }
        // Dark mode handled via SwiftUI .colorInvert() modifier
        if let page = jumpToPage, let pdfPage = view.document?.page(at: page - 1) {
            view.go(to: pdfPage)
            DispatchQueue.main.async { jumpToPage = nil }
        }
    }

    static func forceTransparent(_ view: NSView) {
        view.wantsLayer = true
        view.layer?.backgroundColor = CGColor.clear
        view.layer?.isOpaque = false
        if let scroll = view as? NSScrollView {
            scroll.drawsBackground = false
            scroll.backgroundColor = .clear
            scroll.contentView.drawsBackground = false
            scroll.contentView.wantsLayer = true
            scroll.contentView.layer?.backgroundColor = CGColor.clear
            scroll.contentView.layer?.isOpaque = false
            if let docView = scroll.documentView {
                docView.wantsLayer = true
                docView.layer?.backgroundColor = CGColor.clear
                docView.layer?.isOpaque = false
            }
        }
        for sub in view.subviews {
            forceTransparent(sub)
        }
    }

    private func applyHighlights(to view: PDFView) {
        guard let doc = view.document else { return }
        // Clear existing highlight annotations
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let toRemove = page.annotations.filter { $0.type == "Highlight" }
            for a in toRemove { page.removeAnnotation(a) }
        }
        // Add highlights — API stores rects as PERCENT (0–100), not fractions (0–1)
        for h in highlights {
            guard h.pageNumber - 1 < doc.pageCount,
                  let page = doc.page(at: h.pageNumber - 1) else { continue }
            let pageBounds = page.bounds(for: .mediaBox)
            for rect in h.rects {
                // Normalize: if values > 1, they're percentages; divide by 100
                let xPct = rect.x > 1 ? rect.x / 100.0 : rect.x
                let yPct = rect.y > 1 ? rect.y / 100.0 : rect.y
                let wPct = rect.width > 1 ? rect.width / 100.0 : rect.width
                let hPct = rect.height > 1 ? rect.height / 100.0 : rect.height

                let x = xPct * pageBounds.width
                let w = wPct * pageBounds.width
                let height = hPct * pageBounds.height
                // Convert top-left origin (API) → bottom-left origin (PDFKit)
                let y = pageBounds.height - (yPct * pageBounds.height) - height
                let pdfRect = CGRect(x: x, y: y, width: w, height: height)
                let annotation = PDFAnnotation(bounds: pdfRect, forType: .highlight, withProperties: nil)
                annotation.color = pdfHighlightColor(h.color)
                page.addAnnotation(annotation)
            }
        }
    }

    private func pdfHighlightColor(_ name: String) -> NSColor {
        // Support both named colors and hex values (#93c5fd)
        if name.hasPrefix("#") {
            var hex = name
            hex.removeFirst()
            if hex.count == 6 {
                var rgb: UInt64 = 0
                Scanner(string: hex).scanHexInt64(&rgb)
                return NSColor(
                    calibratedRed: CGFloat((rgb >> 16) & 0xFF) / 255.0,
                    green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
                    blue: CGFloat(rgb & 0xFF) / 255.0,
                    alpha: 0.45
                )
            }
        }
        switch name {
        case "yellow": return NSColor(calibratedRed: 0.98, green: 0.85, blue: 0.20, alpha: 0.50)
        case "blue":   return NSColor(calibratedRed: 0.40, green: 0.65, blue: 0.95, alpha: 0.45)
        case "green":  return NSColor(calibratedRed: 0.40, green: 0.85, blue: 0.55, alpha: 0.45)
        default:       return NSColor.systemYellow.withAlphaComponent(0.5)
        }
    }
}

// Replicates the web CSS: filter: invert(0.88) contrast(0.95) brightness(1.05) sepia(0.15)
// Uses a CALayer with CIFilters applied to the parent PDFView
struct PDFToolbar: View {
    @Binding var activeTool: ActiveTool
    @Binding var sepiaMode: Bool
    let onZoomIn: () -> Void
    let onZoomOut: () -> Void
    let onClose: () -> Void
    let pageCount: Int
    let currentPage: Int

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(T.text2)
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.05))
            }.buttonStyle(.plain)

            Divider().frame(height: 18).background(T.line)

            HStack(spacing: 4) {
                toolButton(.read,      icon: "hand.point.up", label: "Lesen")
                toolButton(.highlight, icon: "highlighter",   label: "Markieren")
                toolButton(.translate, icon: "character.book.closed", label: "Übersetzen")
                toolButton(.method,    icon: "function",      label: "Methode")
            }

            Divider().frame(height: 18).background(T.line)

            HStack(spacing: 4) {
                Button(action: onZoomOut) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
                Button(action: onZoomIn) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
            }

            // Dark mode / Normal toggle
            Button { sepiaMode.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: sepiaMode ? "moon.fill" : "sun.max.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(sepiaMode ? "Dark" : "Hell")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(sepiaMode ? T.accent : T.text2)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(sepiaMode ? T.accentSoft : Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Spacer()

            if pageCount > 0 {
                Text("Seite \(currentPage) / \(pageCount)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(T.bg.opacity(0.85))
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(T.line),
            alignment: .bottom
        )
    }

    func toolButton(_ tool: ActiveTool, icon: String, label: String) -> some View {
        Button { activeTool = tool } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(activeTool == tool ? T.text1 : T.text2)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(activeTool == tool ? T.accentSoft : Color.white.opacity(0.04))
            .overlay(Rectangle().stroke(activeTool == tool ? T.accent.opacity(0.55) : Color.clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - Analysis Panel (right side of AnalysisView)
// ============================================================

// ============================================================
// MARK: - Translation / Method / Agent cards
// ============================================================

struct TranslationCard: View {
    let tr: TranslationEntry
    @Binding var jumpToPage: Int?
    @EnvironmentObject var annotationsStore: AnnotationsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source text (original)
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(T.highlightBlue)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ORIGINAL")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(T.text3)
                    Text(tr.source)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                        .textSelection(.enabled)
                }
                Spacer()
                if let p = tr.page {
                    Button { jumpToPage = p } label: {
                        Text("S. \(p)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(T.accent)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(T.accentSoft)
                    }.buttonStyle(.plain)
                }
                Button { annotationsStore.removeTranslation(id: tr.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.6))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)

            // Divider
            Rectangle().fill(T.line).frame(height: 1)

            // Translation
            HStack(alignment: .top, spacing: 8) {
                Rectangle()
                    .fill(T.accent)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ÜBERSETZUNG")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(T.text3)
                    Text(tr.translated)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(T.accent)
                        .textSelection(.enabled)
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.vertical, 8)

            // Dictionary section (always visible if present)
            if let dict = tr.dictionary {
                Rectangle().fill(T.line).frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        if let p = dict.phonetic, !p.isEmpty {
                            Text("/\(p)/")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(T.text3)
                        }
                        if let p = dict.pos, !p.isEmpty {
                            Text(p)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(T.accent)
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(T.accentSoft)
                        }
                    }
                    if let trs = dict.translations, !trs.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(trs, id: \.self) { t in
                                Text(t)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(T.text1)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(Color.white.opacity(0.05))
                            }
                        }
                    }
                    if let def = dict.definition, !def.isEmpty {
                        Text(def)
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let ac = dict.academic_context, !ac.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AKADEMISCH")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(T.text3)
                            Text(ac)
                                .font(.system(size: 10))
                                .foregroundStyle(T.text2)
                        }
                    }
                    if let ex = dict.examples, !ex.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("BEISPIELE")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.4)
                                .foregroundStyle(T.text3)
                            ForEach(Array(ex.enumerated()), id: \.offset) { _, e in
                                Text("→ \(e)")
                                    .font(.system(size: 10).italic())
                                    .foregroundStyle(T.text2)
                            }
                        }
                    }
                    if let syn = dict.synonyms, !syn.isEmpty {
                        HStack(spacing: 4) {
                            Text("SYN")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(T.text3)
                            Text(syn.joined(separator: ", "))
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                    }
                    if let ety = dict.etymology, !ety.isEmpty {
                        HStack(spacing: 4) {
                            Text("ETYMOLOGIE")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(T.text3)
                            Text(ety)
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
            }
        }
        .background(T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
    }
}

struct MethodCard: View {
    let m: MethodEntry
    @Binding var jumpToPage: Int?
    @EnvironmentObject var annotationsStore: AnnotationsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.method.method_name)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(T.text1)
                    Text(m.method.description)
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                }
                Spacer()
                Button { annotationsStore.removeMethod(id: m.id) } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.7))
                }.buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                if let p = m.page {
                    Button { jumpToPage = p } label: {
                        Text("S. \(p)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(T.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(T.accentSoft)
                    }.buttonStyle(.plain)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                    methodField("Wie es funktioniert", m.method.how_it_works)
                    methodField("Annahmen", m.method.assumptions)
                    methodField("Beispiel", m.method.example)
                    methodField("Formeln", m.method.formulas, mono: true)
                    methodField("Interpretation", m.method.interpretation)
                    methodField("Stärken/Limitationen", m.method.strengths_limitations)
                    methodField("Use Cases", m.method.use_cases)
                    methodField("Warum hier", m.method.why_used_here)
                    if let rel = m.method.related_methods, !rel.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verwandt").font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                            FlowLayout(spacing: 4) {
                                ForEach(rel, id: \.self) { r in
                                    Text(r)
                                        .font(.system(size: 10))
                                        .foregroundStyle(T.text2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.white.opacity(0.04))
                                }
                            }
                        }
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.03))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
        .padding(10)
        .background(T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
    }

    @ViewBuilder
    func methodField(_ label: String, _ text: String?, mono: Bool = false) -> some View {
        if let t = text, !t.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                Text(t)
                    .font(.system(size: 10, design: mono ? .monospaced : .default))
                    .foregroundStyle(T.text1)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AgentQATab: View {
    let entry: LiteratureEntry
    @Binding var jumpToPage: Int?
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var annotationsStore: AnnotationsStore
    @State private var question: String = ""
    @State private var asking = false
    @State private var error: String?

    func ask() {
        let q = question.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        asking = true
        error = nil
        Task {
            do {
                if let result = try await entriesStore.api.askAgent(entry.id, question: q),
                   let answer = result["answer"] as? String {
                    let pages = (result["pages"] as? [Int]) ?? []
                    let qa = AgentQAEntry(
                        id: UUID().uuidString,
                        question: q,
                        answer: answer,
                        pages: pages,
                        timestamp: Date().timeIntervalSince1970
                    )
                    annotationsStore.addAgentQA(qa)
                    question = ""
                } else {
                    error = "Keine Antwort erhalten"
                }
            } catch {
                self.error = "\(error)"
            }
            asking = false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Q&A list
            ForEach(annotationsStore.agentQA) { qa in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(T.accent)
                        Text(qa.question)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(T.text1)
                        Spacer()
                        Button { annotationsStore.removeAgentQA(id: qa.id) } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 9))
                                .foregroundStyle(.red.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                    Text((try? AttributedString(markdown: qa.answer, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(qa.answer))
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .padding(.leading, 17)
                    if !qa.pages.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(qa.pages, id: \.self) { p in
                                Button { jumpToPage = p } label: {
                                    Text("S. \(p)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(T.accent)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(T.accentSoft)
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.leading, 17)
                    }
                }
                .padding(10)
                .background(T.card)
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            }

            // Input
            VStack(alignment: .leading, spacing: 4) {
                Text("FRAGE STELLEN")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(T.text3)
                HStack(spacing: 6) {
                    TextField("z.B. Was ist die Hauptmethode?", text: $question, onCommit: ask)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    Button(action: ask) {
                        HStack(spacing: 4) {
                            if asking { ProgressView().controlSize(.mini).tint(.white) }
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                    .disabled(asking || question.isEmpty)
                }
                if let e = error {
                    Text(e).font(.system(size: 10)).foregroundStyle(.red.opacity(0.85))
                }
            }
        }
    }
}

enum AnalysisTab: String, CaseIterable {
    case analyse, highlights, translations, methods, agent
    var label: String {
        switch self {
        case .analyse:      return "Analyse"
        case .highlights:   return "Highlights"
        case .translations: return "Übersetzungen"
        case .methods:      return "Methoden"
        case .agent:        return "Agent"
        }
    }
    var icon: String {
        switch self {
        case .analyse:      return "doc.text.magnifyingglass"
        case .highlights:   return "highlighter"
        case .translations: return "character.book.closed"
        case .methods:      return "function"
        case .agent:        return "sparkles"
        }
    }
}

struct AnalysisPanel: View {
    let entry: LiteratureEntry
    @Binding var jumpToPage: Int?
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var analysisStore: AnalysisStore
    @EnvironmentObject var annotationsStore: AnnotationsStore
    @State private var tab: AnalysisTab = .analyse

    var hasAnalysis: Bool {
        guard let dict = analysisDict() else { return false }
        return dict["summary"] != nil || dict["positioning"] != nil || dict["keyFindings"] != nil
    }

    func analysisDict() -> [String: Any]? {
        guard let raw = entriesStore.selectedDetail?.research_analysis?.value as? [String: Any] else {
            return entry.research_analysis?.value as? [String: Any]
        }
        if analysisStore.displayLanguage == "de",
           let i18n = raw["_i18n"] as? [String: Any],
           let de = i18n["de"] as? [String: Any] {
            return de
        }
        return raw
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header / toolbar
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Button {
                        analysisStore.analyze(entryId: entry.id) {
                            Task {
                                if let e = try? await entriesStore.api.getEntry(entry.id) {
                                    await MainActor.run { entriesStore.selectedDetail = e }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: hasAnalysis ? "arrow.clockwise" : "play.fill")
                                .font(.system(size: 9, weight: .bold))
                            Text(hasAnalysis ? "Neu analysieren" : "Analysieren")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                    .disabled(analysisStore.status == .extracting || analysisStore.status == .analyzing || analysisStore.status == .consolidating)

                    if hasAnalysis {
                        Button {
                            // Reconsolidate: re-run consolidation without re-extracting
                            analysisStore.analyze(entryId: entry.id) {
                                Task {
                                    if let e = try? await entriesStore.api.getEntry(entry.id) {
                                        await MainActor.run { entriesStore.selectedDetail = e }
                                    }
                                }
                            }
                        } label: {
                            Text("Rekonsolidieren")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(T.text2)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .background(Color.white.opacity(0.04))
                        }.buttonStyle(.plain)
                    }

                    if analysisStore.status == .extracting || analysisStore.status == .analyzing || analysisStore.status == .consolidating {
                        Button("Abbrechen") { analysisStore.cancel() }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundStyle(T.text2)
                    }

                    Spacer()

                    // Provider toggle
                    Menu {
                        Button("OpenRouter") { analysisStore.provider = "openrouter" }
                        Button("Claude CLI") { analysisStore.provider = "claude_cli" }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "cpu")
                                .font(.system(size: 9))
                            Text(analysisStore.provider == "openrouter" ? "OpenRouter" : "Claude CLI")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                    }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()

                    // Language toggle
                    HStack(spacing: 0) {
                        Button {
                            analysisStore.displayLanguage = "en"
                        } label: {
                            Text("EN")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(analysisStore.displayLanguage == "en" ? T.text1 : T.text3)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(analysisStore.displayLanguage == "en" ? T.accentSoft : Color.white.opacity(0.04))
                        }.buttonStyle(.plain)
                        Button {
                            if hasAnalysis {
                                analysisStore.displayLanguage = "de"
                                Task {
                                    await analysisStore.translateAnalysis(entryId: entry.id)
                                    if let updated = try? await entriesStore.api.getEntry(entry.id) {
                                        entriesStore.selectedDetail = updated
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                if analysisStore.translatingAnalysis {
                                    ProgressView().controlSize(.mini)
                                }
                                Text("DE")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(analysisStore.displayLanguage == "de" ? T.text1 : T.text3)
                            }
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(analysisStore.displayLanguage == "de" ? T.accentSoft : Color.white.opacity(0.04))
                        }.buttonStyle(.plain)
                    }
                }

                // Progress
                if analysisStore.status != .idle && analysisStore.status != .done {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            ProgressView().controlSize(.mini)
                            Text(progressText)
                                .font(.system(size: 10))
                                .foregroundStyle(T.text2)
                        }
                        if analysisStore.totalChunks > 0 {
                            ProgressView(value: Double(analysisStore.currentChunk), total: Double(analysisStore.totalChunks))
                                .tint(T.accent)
                        }
                    }
                }
                if let err = analysisStore.error {
                    Text(err).font(.system(size: 10)).foregroundStyle(.red.opacity(0.85))
                }

                // Tabs
                HStack(spacing: 4) {
                    ForEach(AnalysisTab.allCases, id: \.self) { t in
                        Button { tab = t } label: {
                            HStack(spacing: 4) {
                                Image(systemName: t.icon)
                                    .font(.system(size: 9, weight: .semibold))
                                Text(t.label)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(tab == t ? T.text1 : T.text3)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(tab == t ? T.accentSoft : Color.white.opacity(0.04))
                            .overlay(Rectangle().stroke(tab == t ? T.accent.opacity(0.55) : Color.clear, lineWidth: 1))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(T.bg.opacity(0.6))
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            // Content
            ScrollView(showsIndicators: true) {
                Group {
                    switch tab {
                    case .analyse:      analyseContent
                    case .highlights:   highlightsContent
                    case .translations: translationsContent
                    case .methods:      methodsContent
                    case .agent:        agentContent
                    }
                }
                .padding(14)
            }
        }
    }

    var progressText: String {
        switch analysisStore.status {
        case .extracting:   return "Extrahiere PDF…"
        case .analyzing:
            if analysisStore.totalChunks > 0 {
                return "Analysiere Chunk \(analysisStore.currentChunk)/\(analysisStore.totalChunks)…"
            }
            return "Analysiere…"
        case .consolidating: return "Konsolidiere…"
        default: return ""
        }
    }

    // ----- Analyse content (all sections) -----
    @State private var analysisSubTab: String = "overview"

    @ViewBuilder var analyseContent: some View {
        if let dict = analysisDict() {
            VStack(alignment: .leading, spacing: 12) {
                // Sub-tabs like web: Overview / Research Design / Results / Dissertation
                HStack(spacing: 4) {
                    ForEach([("overview","Überblick"),("design","Forschungsdesign"),("results","Ergebnisse"),("diss","Dissertation")], id: \.0) { id, label in
                        Button { analysisSubTab = id } label: {
                            Text(label)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(analysisSubTab == id ? T.text1 : T.text3)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(analysisSubTab == id ? T.accentSoft : Color.white.opacity(0.03))
                                .overlay(Rectangle().stroke(analysisSubTab == id ? T.accent.opacity(0.5) : Color.clear, lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
                }

                Group {
                    switch analysisSubTab {
                    case "overview":
                        VStack(alignment: .leading, spacing: 18) {
                            summarySection(dict)
                            positioningSection(dict)
                            theoreticalSection(dict)
                            researchQuestionsSection(dict)
                        }
                    case "design":
                        VStack(alignment: .leading, spacing: 18) {
                            methodologySection(dict)
                            variablesSection(dict)
                            statMethodsSection(dict)
                        }
                    case "results":
                        VStack(alignment: .leading, spacing: 18) {
                            findingsSection(dict)
                            limitationsSection(dict)
                            quotesSection(dict)
                            replicationSection(dict)
                        }
                    case "diss":
                        dissertationSection(dict)
                    default:
                        summarySection(dict)
                    }
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(T.text3)
                Text("Noch keine Analyse")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.text2)
                Text("Klicke „Analysieren\" oben um die KI-Analyse zu starten")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
        }
    }

    // ----- Section helpers -----
    func sectionTitle(_ s: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(T.accent)
            Text(s.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(T.text3)
        }
    }

    func pageRefBadges(_ refs: Any?) -> some View {
        let pages: [Int] = (refs as? [[String: Any]])?.compactMap { $0["page"] as? Int } ?? []
        return HStack(spacing: 3) {
            ForEach(pages, id: \.self) { p in
                Button { jumpToPage = p } label: {
                    Text("S. \(p)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.accent)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(T.accentSoft)
                }.buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    func summarySection(_ dict: [String: Any]) -> some View {
        if let summary = dict["summary"] as? String, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Zusammenfassung", icon: "doc.text")
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    .fixedSize(horizontal: false, vertical: true)
                pageRefBadges(dict["summaryRefs"])
            }
        }
    }

    @ViewBuilder
    func positioningSection(_ dict: [String: Any]) -> some View {
        if let pos = dict["positioning"] as? [String: Any] {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Positionierung", icon: "location.viewfinder")
                if let v = pos["researchGap"] as? String, !v.isEmpty {
                    labeled("Forschungslücke", text: v)
                }
                if let v = pos["contribution"] as? String, !v.isEmpty {
                    labeled("Beitrag", text: v)
                }
                if let v = pos["theoreticalBasis"] as? String, !v.isEmpty {
                    labeled("Theoret. Basis", text: v)
                }
                if let v = pos["practicalImplications"] as? String, !v.isEmpty {
                    labeled("Praxis", text: v)
                }
                pageRefBadges(dict["positioningRefs"])
            }
        }
    }

    @ViewBuilder
    func researchQuestionsSection(_ dict: [String: Any]) -> some View {
        if let qs = dict["researchQuestions"] as? [[String: Any]], !qs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Forschungsfragen", icon: "questionmark.circle")
                ForEach(Array(qs.enumerated()), id: \.offset) { _, q in
                    VStack(alignment: .leading, spacing: 3) {
                        if let text = q["question"] as? String {
                            Text("• \(text)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(T.text1)
                        }
                        if let notes = q["notes"] as? String, !notes.isEmpty {
                            Text(notes)
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                                .padding(.leading, 12)
                        }
                        pageRefBadges(q["refs"]).padding(.leading, 12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func methodologySection(_ dict: [String: Any]) -> some View {
        if let meth = dict["methodology"] as? [String: Any] {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Methodik", icon: "wrench.and.screwdriver")
                if let v = meth["design"] as? String, !v.isEmpty { labeled("Design", text: v) }
                if let v = meth["sample"] as? String, !v.isEmpty { labeled("Sample", text: v) }
                if let v = meth["procedure"] as? String, !v.isEmpty { labeled("Vorgehen", text: v) }
                if let v = meth["dataCollection"] as? String, !v.isEmpty { labeled("Datenerhebung", text: v) }
                pageRefBadges(dict["methodologyRefs"])
            }
        }
    }

    @ViewBuilder
    func theoreticalSection(_ dict: [String: Any]) -> some View {
        if let th = dict["theoreticalFramework"] as? [String: Any] {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Theoretischer Rahmen", icon: "books.vertical")
                if let theories = th["theories"] as? [[String: Any]], !theories.isEmpty {
                    Text("Theorien")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(T.text2)
                    ForEach(Array(theories.enumerated()), id: \.offset) { _, t in
                        VStack(alignment: .leading, spacing: 2) {
                            if let n = t["name"] as? String {
                                Text(n).font(.system(size: 11, weight: .semibold)).foregroundStyle(T.text1)
                            }
                            if let d = t["description"] as? String, !d.isEmpty {
                                Text(d).font(.system(size: 11)).foregroundStyle(T.text2)
                            }
                            pageRefBadges(t["refs"])
                        }
                        .padding(.leading, 12)
                    }
                }
                if let hyps = th["hypotheses"] as? [[String: Any]], !hyps.isEmpty {
                    Text("Hypothesen").font(.system(size: 10, weight: .semibold)).foregroundStyle(T.text2)
                    ForEach(Array(hyps.enumerated()), id: \.offset) { _, h in
                        VStack(alignment: .leading, spacing: 2) {
                            if let txt = h["text"] as? String {
                                Text("• \(txt)").font(.system(size: 11)).foregroundStyle(T.text1)
                            }
                            pageRefBadges(h["refs"]).padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func variablesSection(_ dict: [String: Any]) -> some View {
        if let vars = dict["variables"] as? [String: Any] {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Variablen", icon: "function")
                ForEach([
                    ("dependent", "Abhängig"),
                    ("independent", "Unabhängig"),
                    ("control", "Kontrollvariablen"),
                    ("moderators", "Moderatoren"),
                    ("mediators", "Mediatoren"),
                ], id: \.0) { (key, label) in
                    if let arr = vars[key] as? [[String: Any]], !arr.isEmpty {
                        Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(T.text2)
                        ForEach(Array(arr.enumerated()), id: \.offset) { _, v in
                            VStack(alignment: .leading, spacing: 2) {
                                if let n = v["name"] as? String {
                                    Text(n).font(.system(size: 11, weight: .semibold)).foregroundStyle(T.text1)
                                }
                                if let d = v["description"] as? String, !d.isEmpty {
                                    Text(d).font(.system(size: 10)).foregroundStyle(T.text2)
                                }
                                if let m = v["measurement"] as? String, !m.isEmpty {
                                    Text("Messung: \(m)").font(.system(size: 10)).foregroundStyle(T.text3)
                                }
                                pageRefBadges(v["refs"])
                            }
                            .padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func statMethodsSection(_ dict: [String: Any]) -> some View {
        if let arr = dict["statisticalMethods"] as? [[String: Any]], !arr.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Statistische Methoden", icon: "chart.bar")
                ForEach(Array(arr.enumerated()), id: \.offset) { _, m in
                    VStack(alignment: .leading, spacing: 2) {
                        if let name = m["method"] as? String {
                            Text(name).font(.system(size: 11, weight: .semibold)).foregroundStyle(T.text1)
                        }
                        if let det = m["details"] as? String, !det.isEmpty {
                            Text(det).font(.system(size: 11)).foregroundStyle(T.text2)
                        }
                        pageRefBadges(m["refs"])
                    }
                }
            }
        }
    }

    @ViewBuilder
    func findingsSection(_ dict: [String: Any]) -> some View {
        if let arr = dict["keyFindings"] as? [[String: Any]], !arr.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Kernergebnisse", icon: "lightbulb")
                ForEach(Array(arr.enumerated()), id: \.offset) { _, f in
                    VStack(alignment: .leading, spacing: 3) {
                        if let txt = f["finding"] as? String {
                            Text("• \(txt)").font(.system(size: 12, weight: .semibold)).foregroundStyle(T.text1)
                        }
                        HStack(spacing: 6) {
                            if let rq = f["supportsRQ"] as? String, !rq.isEmpty {
                                Text("RQ: \(rq)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(T.text3)
                            }
                            if let es = f["effectSize"] as? String, !es.isEmpty {
                                Text("ES: \(es)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(T.text3)
                            }
                            pageRefBadges(f["refs"])
                        }
                        .padding(.leading, 12)
                    }
                }
            }
        }
    }

    @ViewBuilder
    func limitationsSection(_ dict: [String: Any]) -> some View {
        if let arr = dict["limitations"] as? [[String: Any]], !arr.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Limitationen", icon: "exclamationmark.triangle")
                ForEach(Array(arr.enumerated()), id: \.offset) { _, l in
                    HStack(alignment: .top, spacing: 6) {
                        if let sev = l["severity"] as? String {
                            let color: Color = sev == "high" ? T.danger : sev == "medium" ? T.warning : T.text3
                            Circle().fill(color).frame(width: 6, height: 6).padding(.top, 5)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if let txt = l["text"] as? String {
                                Text(txt).font(.system(size: 11)).foregroundStyle(T.text1)
                            }
                            pageRefBadges(l["refs"])
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    func quotesSection(_ dict: [String: Any]) -> some View {
        if let arr = dict["directQuotes"] as? [[String: Any]], !arr.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Zitate", icon: "quote.opening")
                ForEach(Array(arr.enumerated()), id: \.offset) { _, q in
                    VStack(alignment: .leading, spacing: 3) {
                        if let qt = q["quote"] as? String {
                            Text("„\(qt)\"")
                                .font(.system(size: 11, design: .serif).italic())
                                .foregroundStyle(T.text1)
                        }
                        if let ctx = q["context"] as? String, !ctx.isEmpty {
                            Text(ctx).font(.system(size: 10)).foregroundStyle(T.text3)
                        }
                        if let p = q["page"] as? Int {
                            Button { jumpToPage = p } label: {
                                Text("S. \(p)")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(T.accent)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(T.accentSoft)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
            }
        }
    }

    @ViewBuilder
    func dissertationSection(_ dict: [String: Any]) -> some View {
        if let dr = dict["dissertationRelevance"] as? [String: Any] {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Dissertation-Relevanz", icon: "graduationcap")
                if let score = dr["relevanceScore"] as? Int {
                    HStack(spacing: 6) {
                        Text("Relevanz:").font(.system(size: 10)).foregroundStyle(T.text3)
                        Text("\(score)/10")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(T.relevanceColor(score))
                    }
                }
                if let kt = dr["keyTakeaways"] as? [String], !kt.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Key Takeaways").font(.system(size: 10, weight: .semibold)).foregroundStyle(T.text2)
                        ForEach(Array(kt.enumerated()), id: \.offset) { _, t in
                            Text("• \(t)").font(.system(size: 11)).foregroundStyle(T.text1)
                        }
                    }
                }
                if let m = dr["methodologicalInsights"] as? String, !m.isEmpty {
                    labeled("Methodisch", text: m)
                }
                if let g = dr["gapsForOwnResearch"] as? String, !g.isEmpty {
                    labeled("Lücken für eigene Arbeit", text: g)
                }
                if let cit = dr["potentialCitations"] as? [String], !cit.isEmpty {
                    Text("Potentielle Zitate").font(.system(size: 10, weight: .semibold)).foregroundStyle(T.text2)
                    ForEach(Array(cit.enumerated()), id: \.offset) { _, c in
                        Text("• \(c)").font(.system(size: 10)).foregroundStyle(T.text2)
                    }
                }
            }
            .padding(10)
            .background(T.accentSoft.opacity(0.4))
            .overlay(Rectangle().stroke(T.accent.opacity(0.3), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func replicationSection(_ dict: [String: Any]) -> some View {
        if let arr = dict["replicationIdeas"] as? [[String: Any]], !arr.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Replikations-Ideen", icon: "arrow.triangle.2.circlepath")
                ForEach(Array(arr.enumerated()), id: \.offset) { _, r in
                    VStack(alignment: .leading, spacing: 2) {
                        if let i = r["idea"] as? String {
                            Text("• \(i)").font(.system(size: 11, weight: .semibold)).foregroundStyle(T.text1)
                        }
                        if let r2 = r["rationale"] as? String, !r2.isEmpty {
                            Text(r2).font(.system(size: 10)).foregroundStyle(T.text2).padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    func labeled(_ label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(0.4).foregroundStyle(T.text3)
            Text(text).font(.system(size: 11)).foregroundStyle(T.text1)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // ----- Highlights tab -----
    @ViewBuilder
    var highlightsContent: some View {
        if annotationsStore.highlights.isEmpty {
            emptyState(icon: "highlighter", text: "Keine Highlights")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(annotationsStore.highlights) { h in
                    HStack(alignment: .top, spacing: 8) {
                        Rectangle()
                            .fill(highlightColor(h.color))
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(h.text)
                                .font(.system(size: 11))
                                .foregroundStyle(T.text1)
                                .lineLimit(4)
                            HStack(spacing: 6) {
                                Button { jumpToPage = h.pageNumber } label: {
                                    Text("S. \(h.pageNumber)")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundStyle(T.accent)
                                        .padding(.horizontal, 5).padding(.vertical, 1)
                                        .background(T.accentSoft)
                                }.buttonStyle(.plain)
                                Spacer()
                                Button {
                                    annotationsStore.removeHighlight(id: h.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.red.opacity(0.7))
                                }.buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                    }
                    .background(T.card)
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
            }
        }
    }

    func highlightColor(_ name: String) -> Color {
        switch name {
        case "yellow": return T.highlightYellow
        case "blue":   return T.highlightBlue
        case "green":  return T.highlightGreen
        default:       return T.highlightYellow
        }
    }

    // ----- Translations tab -----
    @ViewBuilder
    var translationsContent: some View {
        if annotationsStore.translations.isEmpty {
            emptyState(icon: "character.book.closed", text: "Wähle Text im PDF + Übersetzen-Tool")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(annotationsStore.translations.reversed()) { tr in
                    TranslationCard(tr: tr, jumpToPage: $jumpToPage)
                }
            }
        }
    }

    // ----- Methods tab -----
    @ViewBuilder
    var methodsContent: some View {
        if annotationsStore.methodExplanations.isEmpty {
            emptyState(icon: "function", text: "Wähle Text im PDF + Methode-Tool")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(annotationsStore.methodExplanations.reversed()) { m in
                    MethodCard(m: m, jumpToPage: $jumpToPage)
                }
            }
        }
    }

    // ----- Agent tab -----
    @ViewBuilder
    var agentContent: some View {
        AgentQATab(entry: entry, jumpToPage: $jumpToPage)
    }

    func emptyState(icon: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(T.text3)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(T.text3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// ============================================================
// MARK: - Citation Network View (Force-Directed DAG)
// ============================================================

struct GraphNode: Identifiable, Hashable {
    let id: Int
    let title: String
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var fixed: Bool = false
}

struct GraphEdge: Identifiable, Hashable {
    let id: Int
    let source: Int
    let target: Int
    let type: String
}

func relationColor(_ type: String) -> Color {
    switch type {
    case "cites":        return Color(red: 0.42, green: 0.55, blue: 0.78)
    case "cited_by":     return Color(red: 0.36, green: 0.74, blue: 0.78)
    case "extends":      return T.success
    case "contradicts":  return T.danger
    case "replicates":   return T.warning
    case "reviews":      return Color(red: 0.62, green: 0.45, blue: 0.82)
    case "related":      return T.text3
    case "builds_on":    return Color(red: 0.30, green: 0.70, blue: 0.66)
    default:             return T.text3
    }
}

func relationLabel(_ type: String) -> String {
    switch type {
    case "cites":        return "zitiert"
    case "cited_by":     return "zitiert von"
    case "extends":      return "erweitert"
    case "contradicts":  return "widerspricht"
    case "replicates":   return "repliziert"
    case "reviews":      return "rezensiert"
    case "related":      return "verwandt"
    case "builds_on":    return "baut auf"
    default:             return type
    }
}

struct CitationNetworkView: View {
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var relationsStore: RelationsStore
    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var simulationTask: Task<Void, Never>? = nil
    @State private var canvasSize: CGSize = CGSize(width: 800, height: 600)
    @State private var dragNodeId: Int? = nil
    @State private var dragOffset: CGSize = .zero
    @State private var selectedNodeId: Int? = nil
    @State private var showAddRelation = false

    func loadAndLayout() async {
        await relationsStore.loadNetwork()
        // Build nodes from unique entry IDs in relations
        var nodeMap: [Int: GraphNode] = [:]
        for r in relationsStore.relations {
            if nodeMap[r.source_entry_id] == nil {
                nodeMap[r.source_entry_id] = GraphNode(
                    id: r.source_entry_id,
                    title: r.source_entry_title,
                    x: CGFloat.random(in: 100...700),
                    y: CGFloat.random(in: 100...500)
                )
            }
            if nodeMap[r.target_entry_id] == nil {
                nodeMap[r.target_entry_id] = GraphNode(
                    id: r.target_entry_id,
                    title: r.target_entry_title,
                    x: CGFloat.random(in: 100...700),
                    y: CGFloat.random(in: 100...500)
                )
            }
        }
        nodes = Array(nodeMap.values)
        edges = relationsStore.relations.map {
            GraphEdge(id: $0.id, source: $0.source_entry_id, target: $0.target_entry_id, type: $0.relation_type)
        }
        runSimulation()
    }

    func runSimulation() {
        simulationTask?.cancel()
        let currentEdges = edges
        let size = canvasSize
        simulationTask = Task.detached(priority: .userInitiated) {
            var localNodes = await MainActor.run { self.nodes }
            for iteration in 0..<300 {
                if Task.isCancelled { return }
                let totalVelocity = Self.stepPhysics(nodes: &localNodes, edges: currentEdges, canvasSize: size)
                // Update UI every 3rd frame for performance
                if iteration % 3 == 0 {
                    let snapshot = localNodes
                    await MainActor.run { self.nodes = snapshot }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
                // Early convergence: stop if total velocity is low
                if totalVelocity < 0.5 && iteration > 30 {
                    let snapshot = localNodes
                    await MainActor.run { self.nodes = snapshot }
                    return
                }
            }
            let final = localNodes
            await MainActor.run { self.nodes = final }
        }
    }

    nonisolated static func stepPhysics(nodes: inout [GraphNode], edges: [GraphEdge], canvasSize: CGSize) -> CGFloat {
        let kRep: CGFloat = 8000
        let kAttr: CGFloat = 0.04
        let restLength: CGFloat = 140
        let damping: CGFloat = 0.85
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2

        // Repulsion
        for i in 0..<nodes.count {
            if nodes[i].fixed { continue }
            var fx: CGFloat = 0
            var fy: CGFloat = 0
            for j in 0..<nodes.count where i != j {
                let dx = nodes[i].x - nodes[j].x
                let dy = nodes[i].y - nodes[j].y
                let dSq = max(dx * dx + dy * dy, 100)
                let force = kRep / dSq
                fx += dx / sqrt(dSq) * force
                fy += dy / sqrt(dSq) * force
            }
            fx += (centerX - nodes[i].x) * 0.005
            fy += (centerY - nodes[i].y) * 0.005
            nodes[i].vx = (nodes[i].vx + fx) * damping
            nodes[i].vy = (nodes[i].vy + fy) * damping
        }

        // Attraction
        for edge in edges {
            guard let si = nodes.firstIndex(where: { $0.id == edge.source }),
                  let ti = nodes.firstIndex(where: { $0.id == edge.target }) else { continue }
            let dx = nodes[ti].x - nodes[si].x
            let dy = nodes[ti].y - nodes[si].y
            let d = sqrt(dx * dx + dy * dy)
            let stretch = d - restLength
            let fx = dx / max(d, 1) * stretch * kAttr
            let fy = dy / max(d, 1) * stretch * kAttr
            if !nodes[si].fixed { nodes[si].vx += fx; nodes[si].vy += fy }
            if !nodes[ti].fixed { nodes[ti].vx -= fx; nodes[ti].vy -= fy }
        }

        // Apply + measure total velocity
        var totalV: CGFloat = 0
        for i in 0..<nodes.count {
            if nodes[i].fixed { continue }
            nodes[i].x += nodes[i].vx
            nodes[i].y += nodes[i].vy
            nodes[i].x = max(60, min(canvasSize.width - 60, nodes[i].x))
            nodes[i].y = max(40, min(canvasSize.height - 40, nodes[i].y))
            totalV += abs(nodes[i].vx) + abs(nodes[i].vy)
        }
        return totalV
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 13))
                    .foregroundStyle(T.accent)
                Text("Citation Network")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("\(nodes.count) Knoten · \(edges.count) Kanten")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
                Spacer()
                Button {
                    showAddRelation = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Relation")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(T.accent)
                }.buttonStyle(.plain)

                Button { runSimulation() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11))
                        .foregroundStyle(T.text2)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.05))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(T.bg)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            // Canvas
            GeometryReader { geo in
                ZStack {
                    // Edges
                    ForEach(edges) { edge in
                        if let s = nodes.first(where: { $0.id == edge.source }),
                           let t = nodes.first(where: { $0.id == edge.target }) {
                            Path { p in
                                p.move(to: CGPoint(x: s.x, y: s.y))
                                p.addLine(to: CGPoint(x: t.x, y: t.y))
                            }
                            .stroke(relationColor(edge.type).opacity(0.55), lineWidth: 1.2)
                            // Arrow head
                            ArrowHead(from: CGPoint(x: s.x, y: s.y), to: CGPoint(x: t.x, y: t.y))
                                .fill(relationColor(edge.type))
                        }
                    }
                    // Nodes
                    ForEach(nodes) { node in
                        let isSelected = selectedNodeId == node.id
                        Button {
                            selectedNodeId = node.id
                            Task { await entriesStore.loadDetail(node.id) }
                        } label: {
                            Text(node.title)
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(T.text1)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8).padding(.vertical, 5)
                                .frame(maxWidth: 150)
                                .background(isSelected ? T.accent : T.card)
                                .overlay(Rectangle().stroke(isSelected ? T.text1 : T.line, lineWidth: isSelected ? 1.5 : 0.5))
                        }
                        .buttonStyle(.plain)
                        .position(x: node.x, y: node.y)
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    if let i = nodes.firstIndex(where: { $0.id == node.id }) {
                                        nodes[i].x = v.location.x
                                        nodes[i].y = v.location.y
                                        nodes[i].fixed = true
                                    }
                                }
                                .onEnded { _ in
                                    if let i = nodes.firstIndex(where: { $0.id == node.id }) {
                                        nodes[i].fixed = false
                                    }
                                }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    canvasSize = geo.size
                }
                .onChange(of: geo.size) { _, newSize in
                    canvasSize = newSize
                }
            }
            .background(T.bg.opacity(0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
        .task {
            await loadAndLayout()
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
        .sheet(isPresented: $showAddRelation) {
            AddRelationModal(onClose: { showAddRelation = false }, onAdded: {
                Task { await loadAndLayout() }
            })
        }
    }
}

struct ArrowHead: Shape {
    let from: CGPoint
    let to: CGPoint
    let size: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return p }
        // Pull back from target by node radius (approx 25)
        let pullBack: CGFloat = 60
        let tx = to.x - dx / length * pullBack
        let ty = to.y - dy / length * pullBack
        let angle = atan2(dy, dx)
        let a1 = angle + .pi - .pi / 6
        let a2 = angle + .pi + .pi / 6
        p.move(to: CGPoint(x: tx, y: ty))
        p.addLine(to: CGPoint(x: tx + cos(a1) * size, y: ty + sin(a1) * size))
        p.addLine(to: CGPoint(x: tx + cos(a2) * size, y: ty + sin(a2) * size))
        p.closeSubpath()
        return p
    }
}

struct EntrySearchPicker: View {
    let label: String
    let selectedId: Int?
    let onSelect: (Int) -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var search: String = ""
    @State private var open = false

    var filtered: [LiteratureEntry] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = entriesStore.entries.sorted { $0.title < $1.title }
        if q.isEmpty { return Array(sorted.prefix(30)) }
        return sorted.filter { $0.title.lowercased().contains(q) ||
            $0.authors.contains(where: { $0.last.lowercased().contains(q) }) }
    }

    var body: some View {
        Button { open = true } label: {
            Text(selectedId.flatMap { id in entriesStore.entries.first { $0.id == id }?.title } ?? "Wählen…")
                .font(.system(size: 11))
                .foregroundStyle(selectedId == nil ? T.text3 : T.text1)
                .lineLimit(2)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $open, arrowEdge: .top) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(T.text3)
                    TextField("Paper suchen…", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                }
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white.opacity(0.04))
                Divider().background(T.line)
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(filtered) { e in
                            Button {
                                onSelect(e.id)
                                open = false
                            } label: {
                                HStack(spacing: 6) {
                                    Text(e.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(T.text1)
                                        .lineLimit(2)
                                    Spacer()
                                    if e.id == selectedId {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(T.accent)
                                    }
                                }
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .frame(width: 380)
            .background(T.bg)
        }
    }
}

struct AddRelationModal: View {
    let onClose: () -> Void
    let onAdded: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var relationsStore: RelationsStore
    @State private var sourceId: Int? = nil
    @State private var targetId: Int? = nil
    @State private var relationType: String = "cites"
    @State private var notes: String = ""
    @State private var saving = false

    let types = ["cites","cited_by","extends","contradicts","replicates","reviews","related","builds_on"]

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Text("Neue Relation")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("VON")
                EntrySearchPicker(label: "Quelle", selectedId: sourceId, onSelect: { sourceId = $0 })

                fieldLabel("TYP")
                Menu {
                    ForEach(types, id: \.self) { t in
                        Button(relationLabel(t)) { relationType = t }
                    }
                } label: {
                    HStack {
                        Circle().fill(relationColor(relationType)).frame(width: 8, height: 8)
                        Text(relationLabel(relationType))
                            .font(.system(size: 11))
                            .foregroundStyle(T.text1)
                        Spacer()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden)

                fieldLabel("ZU")
                EntrySearchPicker(label: "Ziel", selectedId: targetId, onSelect: { targetId = $0 })

                fieldLabel("NOTIZ")
                TextField("Optional", text: $notes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider().background(T.line)
            HStack {
                Spacer()
                Button("Abbrechen", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                Button {
                    guard let s = sourceId, let t = targetId else { return }
                    saving = true
                    Task {
                        await relationsStore.create(sourceId: s, targetId: t, type: relationType, notes: notes)
                        saving = false
                        onAdded()
                        onClose()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().controlSize(.mini).tint(.white) }
                        Text("Hinzufügen")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(T.accent)
                }.buttonStyle(.plain)
                .disabled(saving || sourceId == nil || targetId == nil)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 480)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
    }

    func fieldLabel(_ s: String) -> some View {
        Text(s).font(.system(size: 9, weight: .semibold)).tracking(0.6).foregroundStyle(T.text3)
    }
}

// ============================================================
// MARK: - RAG Search View
// ============================================================

let ragSections = ["all","finding","methodology","summary","quote","positioning","variables","limitations","statistical_methods","research_questions","theoretical_framework","dissertation_relevance","hypotheses"]
let ragSectionLabels: [String: String] = [
    "all": "Alle", "finding": "Ergebnisse", "methodology": "Methodik", "summary": "Zusammenfassung",
    "quote": "Zitate", "positioning": "Positionierung", "variables": "Variablen",
    "limitations": "Limitationen", "statistical_methods": "Stat. Methoden",
    "research_questions": "Forschungsfragen", "theoretical_framework": "Theorien",
    "dissertation_relevance": "Dissertation", "hypotheses": "Hypothesen"
]

struct RAGSearchView: View {
    @EnvironmentObject var ragStore: RAGStore
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var sectionFilter: String = "all"

    var filteredResults: [[String: Any]] {
        if sectionFilter == "all" { return ragStore.results }
        return ragStore.results.filter { ($0["section"] as? String) == sectionFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(T.text3)
                    TextField("Semantische Suche über alle Papers…", text: $ragStore.query, onCommit: {
                        Task { await ragStore.search() }
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    Button {
                        Task { await ragStore.search() }
                    } label: {
                        if ragStore.loading {
                            ProgressView().controlSize(.mini).tint(.white)
                        } else {
                            Text("Suchen")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(T.accent)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                // Section filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(ragSections, id: \.self) { sec in
                            Button { sectionFilter = sec } label: {
                                Text(ragSectionLabels[sec] ?? sec)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(sectionFilter == sec ? T.text1 : T.text3)
                                    .padding(.horizontal, 7).padding(.vertical, 3)
                                    .background(sectionFilter == sec ? T.accentSoft : Color.white.opacity(0.04))
                                    .overlay(Rectangle().stroke(sectionFilter == sec ? T.accent.opacity(0.55) : Color.clear, lineWidth: 0.5))
                            }.buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text("\(filteredResults.count) Treffer")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                    Spacer()
                    Button {
                        Task { await ragStore.indexAll() }
                    } label: {
                        HStack(spacing: 4) {
                            if ragStore.indexing {
                                ProgressView().controlSize(.mini).tint(T.text2)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 9))
                            }
                            Text(ragStore.indexing ? "Indiziere…" : "Alle indizieren")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(T.bg.opacity(0.4))
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(filteredResults.enumerated()), id: \.offset) { _, result in
                        RAGResultRow(result: result)
                    }
                    if filteredResults.isEmpty && !ragStore.loading {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(T.text3)
                            Text("Stelle eine Frage oder nutze Stichworte")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(14)
            }
        }
    }
}

struct RAGResultRow: View {
    let result: [String: Any]
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var hover = false

    var entryId: Int? { result["entry_id"] as? Int }
    var section: String { result["section"] as? String ?? "" }
    var text: String { result["text"] as? String ?? "" }
    var pages: [Int] { (result["pages"] as? [Int]) ?? [] }
    var score: Double { (result["score"] as? Double) ?? 0 }

    var entry: LiteratureEntry? {
        entryId.flatMap { id in entriesStore.entries.first { $0.id == id } }
    }

    var body: some View {
        Button {
            if let id = entryId {
                Task { await entriesStore.loadDetail(id) }
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let e = entry {
                        Text(e.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(T.text1)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !section.isEmpty {
                        Text(section.uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.4)
                            .foregroundStyle(T.accent)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(T.accentSoft)
                    }
                    if score > 0 {
                        Text(String(format: "%.2f", score))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(T.text3)
                    }
                }
                Text(text)
                    .font(.system(size: 11))
                    .foregroundStyle(T.text2)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                if !pages.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(pages, id: \.self) { p in
                            Text("S. \(p)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(T.accent)
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(T.accentSoft)
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hover ? T.cardHover : T.card)
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

// ============================================================
// MARK: - Journal Ratings Modal (VHB)
// ============================================================

struct JournalRatingsModal: View {
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var ratings: [[String: Any]] = []
    @State private var loading = true
    @State private var search: String = ""

    var filtered: [[String: Any]] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return ratings }
        return ratings.filter {
            ($0["journal_name"] as? String ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Image(systemName: "rosette")
                    .font(.system(size: 12))
                    .foregroundStyle(T.accent)
                Text("Journal-Ratings (VHB-JOURQUAL / CORE)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text3)
                TextField("Journal suchen…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.04))
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            .padding(.horizontal, 18).padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    if loading {
                        ProgressView().controlSize(.small).tint(T.text2).padding()
                    }
                    ForEach(Array(filtered.enumerated()), id: \.offset) { _, r in
                        let name = r["journal_name"] as? String ?? ""
                        let rating = r["rating"] as? String ?? ""
                        let source = r["source"] as? String ?? ""
                        HStack(spacing: 10) {
                            Text(rating)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .frame(width: 30)
                                .padding(.vertical, 3)
                                .background(T.journalRatingColor(rating))
                            Text(name)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(T.text1)
                                .lineLimit(1)
                            Spacer()
                            Text(source)
                                .font(.system(size: 9))
                                .foregroundStyle(T.text3)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(T.card)
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(width: 600, height: 460)

            Divider().background(T.line)
            HStack {
                Spacer()
                Button("Schließen", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 600)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .task {
            if let r = try? await entriesStore.api.listJournalRatings() {
                ratings = r
            }
            loading = false
        }
    }
}

// ============================================================
// MARK: - Global Dictionary + Method Book Views
// ============================================================

struct DictionaryView: View {
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var items: [[String: Any]] = []
    @State private var loading = true
    @State private var search: String = ""

    var filtered: [[String: Any]] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return items }
        return items.filter {
            ($0["word"] as? String ?? "").lowercased().contains(q) ||
            ($0["translated"] as? String ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(T.accent)
                Text("Wörterbuch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("\(items.count) Einträge")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                    TextField("Suchen…", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(maxWidth: 240)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.05))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(T.bg)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if loading {
                        ProgressView().controlSize(.small).tint(T.text2).padding()
                    }
                    ForEach(Array(filtered.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item["word"] as? String ?? "")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(T.text1)
                                Text(item["translated"] as? String ?? "")
                                    .font(.system(size: 12))
                                    .foregroundStyle(T.accent)
                            }
                            Spacer()
                            Button {
                                if let id = item["id"] as? Int {
                                    Task { try? await entriesStore.api.request("DELETE", "/api/literature/dictionary/\(id)") }
                                    items.removeAll { ($0["id"] as? Int) == id }
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.red.opacity(0.7))
                            }.buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(T.card)
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
        .task {
            if let data = try? await entriesStore.api.request("GET", "/api/literature/dictionary"),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                items = arr
            }
            loading = false
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }
}

struct MethodBookView: View {
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var items: [[String: Any]] = []
    @State private var loading = true
    @State private var search: String = ""

    var filtered: [[String: Any]] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return items }
        return items.filter {
            ($0["method_name"] as? String ?? "").lowercased().contains(q) ||
            ($0["source_text"] as? String ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "function")
                    .font(.system(size: 14))
                    .foregroundStyle(T.accent)
                Text("Methodenbuch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("\(items.count) Methoden")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                    TextField("Suchen…", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                }
                .padding(.horizontal, 10).padding(.vertical, 5)
                .frame(maxWidth: 240)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.05))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(T.bg)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 8) {
                    if loading {
                        ProgressView().controlSize(.small).tint(T.text2).padding()
                    }
                    ForEach(Array(filtered.enumerated()), id: \.offset) { _, item in
                        let methodData = item["method_data"] as? [String: Any] ?? [:]
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(item["method_name"] as? String ?? "")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(T.text1)
                                Spacer()
                                Button {
                                    if let id = item["id"] as? Int {
                                        Task { try? await entriesStore.api.request("DELETE", "/api/literature/methods/\(id)") }
                                        items.removeAll { ($0["id"] as? Int) == id }
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.red.opacity(0.7))
                                }.buttonStyle(.plain)
                            }
                            if let desc = methodData["description"] as? String, !desc.isEmpty {
                                Text(desc)
                                    .font(.system(size: 11))
                                    .foregroundStyle(T.text2)
                                    .lineLimit(4)
                            }
                            if let how = methodData["how_it_works"] as? String, !how.isEmpty {
                                Text(how)
                                    .font(.system(size: 10))
                                    .foregroundStyle(T.text3)
                                    .lineLimit(3)
                            }
                        }
                        .padding(10)
                        .background(T.card)
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    }
                }
                .padding(14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
        .task {
            if let data = try? await entriesStore.api.request("GET", "/api/literature/methods"),
               let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                items = arr
            }
            loading = false
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }
}

// ============================================================
// MARK: - Analysis View (full-screen modal)
// ============================================================

struct AnalysisView: View {
    let entry: LiteratureEntry
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var annotationsStore: AnnotationsStore
    @EnvironmentObject var analysisStore: AnalysisStore
    @State private var activeTool: ActiveTool = .read
    @State private var jumpToPage: Int? = nil
    @State private var pdfZoom: CGFloat = 1.0
    @AppStorage("lit.pdfSepia") private var pdfSepia: Bool = false
    @State private var analysisPanelWidth: CGFloat = 480
    @State private var panelDragStart: CGFloat? = nil
    @State private var currentPage: Int = 1
    @State private var pageCount: Int = 0
    @State private var processing = false

    @ViewBuilder
    func pdfViewContent(url: URL) -> some View {
        let viewer = PDFViewerWrapper(
            pdfURL: url,
            highlights: annotationsStore.highlights,
            activeTool: activeTool,
            zoomLevel: pdfZoom,
            sepiaMode: pdfSepia,
            onHighlightAdded: { h in annotationsStore.addHighlight(h) },
            onTextSelected: { text, page, rects in handleSelection(text: text, page: page, rects: rects) },
            onPageChange: { page, total in currentPage = page; pageCount = total },
            jumpToPage: $jumpToPage
        )
        if pdfSepia {
            // Dark mode: dark gray background, white text — like the web version
            viewer
                .colorInvert()
                .brightness(0.08)
                .contrast(0.90)
        } else {
            viewer
        }
    }

    func handleSelection(text: String, page: Int, rects: [PdfHighlightRect]) {
        guard !processing else { return }
        let mode: String
        let highlightColor: String
        switch activeTool {
        case .translate:
            // 1-4 words → dictionary, else translation
            let wordCount = text.split(whereSeparator: { $0.isWhitespace }).count
            mode = wordCount <= 4 ? "dictionary" : "translation"
            highlightColor = "blue"
        case .method:
            mode = "method"
            highlightColor = "green"
        default:
            return
        }

        processing = true
        Task {
            do {
                if let result = try await entriesStore.api.translateText(text, mode: mode) {
                    let highlightId = UUID().uuidString
                    let highlight = PdfHighlight(
                        id: highlightId,
                        pageNumber: page,
                        color: highlightColor,
                        rects: rects,
                        text: text,
                        translated: result["translated"] as? String
                    )
                    annotationsStore.addHighlight(highlight)

                    if mode == "method", let methodDict = result["method"] as? [String: Any] {
                        let mData = MethodData(
                            method_name: methodDict["method_name"] as? String ?? text,
                            description: methodDict["description"] as? String ?? "",
                            how_it_works: methodDict["how_it_works"] as? String ?? "",
                            assumptions: methodDict["assumptions"] as? String,
                            example: methodDict["example"] as? String,
                            formulas: methodDict["formulas"] as? String,
                            interpretation: methodDict["interpretation"] as? String,
                            strengths_limitations: methodDict["strengths_limitations"] as? String,
                            use_cases: methodDict["use_cases"] as? String,
                            why_used_here: methodDict["why_used_here"] as? String,
                            related_methods: methodDict["related_methods"] as? [String]
                        )
                        let me = MethodEntry(
                            id: UUID().uuidString,
                            source: text,
                            page: page,
                            timestamp: Date().timeIntervalSince1970,
                            highlightId: highlightId,
                            cached: result["cached"] as? Bool,
                            method: mData
                        )
                        annotationsStore.addMethod(me)
                    } else {
                        var dictData: DictionaryData? = nil
                        if let d = result["dictionary"] as? [String: Any] {
                            dictData = DictionaryData(
                                word: d["word"] as? String,
                                phonetic: d["phonetic"] as? String,
                                pos: d["pos"] as? String,
                                translations: d["translations"] as? [String],
                                definition: d["definition"] as? String,
                                academic_context: d["academic_context"] as? String,
                                examples: d["examples"] as? [String],
                                synonyms: d["synonyms"] as? [String],
                                etymology: d["etymology"] as? String
                            )
                        }
                        let translated = result["translated"] as? String ?? ""
                        let tr = TranslationEntry(
                            id: UUID().uuidString,
                            source: text,
                            translated: translated,
                            page: page,
                            timestamp: Date().timeIntervalSince1970,
                            mode: mode,
                            dictionary: dictData,
                            highlightId: highlightId
                        )
                        annotationsStore.addTranslation(tr)
                    }
                }
            } catch {
                // ignore
            }
            processing = false
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(entry.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                    .lineLimit(1)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.05))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(T.bg)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    PDFToolbar(
                        activeTool: $activeTool,
                        sepiaMode: $pdfSepia,
                        onZoomIn: { pdfZoom = min(pdfZoom + 0.25, 4.0) },
                        onZoomOut: { pdfZoom = max(pdfZoom - 0.25, 0.3) },
                        onClose: onClose,
                        pageCount: pageCount,
                        currentPage: currentPage
                    )
                    if let url = T.absoluteURL(entry.pdf_url) {
                        pdfViewContent(url: url)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(T.text3)
                            Text("Kein PDF hochgeladen")
                                .font(.system(size: 12))
                                .foregroundStyle(T.text3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                AnalysisPanel(entry: entry, jumpToPage: $jumpToPage)
                    .frame(width: analysisPanelWidth)
                    .frame(maxHeight: .infinity)
                    .background(T.bg.opacity(0.4))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: 6)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 4, coordinateSpace: .local)
                                    .onChanged { v in
                                        if panelDragStart == nil { panelDragStart = analysisPanelWidth }
                                        let windowWidth = NSApp.keyWindow?.frame.width ?? 1400
                                        let maxWidth = windowWidth * 0.75
                                        let new = (panelDragStart ?? 480) - v.translation.width
                                        analysisPanelWidth = max(200, min(maxWidth, new))
                                    }
                                    .onEnded { _ in
                                        panelDragStart = nil
                                        UserDefaults.standard.set(analysisPanelWidth, forKey: "lit.analysisPanelWidth-\(entry.id)")
                                    }
                            )
                            .onHover { inside in
                                if inside { NSCursor.resizeLeftRight.push() }
                                else { NSCursor.pop() }
                            }
                    }
                    .overlay(
                        Rectangle().frame(width: 1).foregroundStyle(T.line),
                        alignment: .leading
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(T.bg)
        .task {
            await annotationsStore.load(entryId: entry.id)
            // Restore persisted panel width + zoom for this entry
            let savedWidth = UserDefaults.standard.double(forKey: "lit.analysisPanelWidth-\(entry.id)")
            if savedWidth >= 200 && savedWidth <= 2000 { analysisPanelWidth = savedWidth }
            let savedZoom = UserDefaults.standard.double(forKey: "lit.pdfZoom-\(entry.id)")
            if savedZoom >= 0.3 && savedZoom <= 4.0 { pdfZoom = savedZoom }
        }
        .onChange(of: pdfZoom) { _, new in
            UserDefaults.standard.set(new, forKey: "lit.pdfZoom-\(entry.id)")
        }
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }
}

// ============================================================
// MARK: - Main view (placeholder 3-pane layout)
// ============================================================

struct MainView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var collectionsStore: CollectionsStore
    @EnvironmentObject var tagsStore: TagsStore
    @State private var showLogout = false
    @State private var showNewEntry = false
    @State private var showImport = false
    @State private var showJournalRatings = false
    @State private var showNetwork = false
    @State private var showDictionary = false
    @State private var showMethodBook = false
    @State private var analysisEntry: LiteratureEntry? = nil
    @AppStorage("lit.sidebarWidth") private var sidebarWidth: Double = 260
    @AppStorage("lit.sidebarCollapsed") private var sidebarCollapsed: Bool = false
    @AppStorage("lit.detailWidth") private var detailWidth: Double = 340

    var body: some View {
        ZStack {
            mainContent
            if let entry = analysisEntry {
                AnalysisView(entry: entry, onClose: { analysisEntry = nil })
                    .transition(.opacity)
                    .zIndex(10)
            }
            if showNetwork {
                CitationNetworkView(onClose: { showNetwork = false })
                    .transition(.opacity)
                    .zIndex(11)
            }
            if showDictionary {
                DictionaryView(onClose: { showDictionary = false })
                    .transition(.opacity)
                    .zIndex(12)
            }
            if showMethodBook {
                MethodBookView(onClose: { showMethodBook = false })
                    .transition(.opacity)
                    .zIndex(12)
            }
        }
        .animation(.easeOut(duration: 0.15), value: analysisEntry?.id)
        .animation(.easeOut(duration: 0.15), value: showNetwork)
        .animation(.easeOut(duration: 0.15), value: showDictionary)
        .animation(.easeOut(duration: 0.15), value: showMethodBook)
        .onReceive(NotificationCenter.default.publisher(for: .init("collapseSidebar"))) { _ in
            withAnimation(.easeOut(duration: 0.2)) { sidebarCollapsed = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("openAnalysis"))) { notif in
            if let detail = entriesStore.selectedDetail, detail.pdf_url != nil {
                analysisEntry = detail
            }
        }
        .background(
            Group {
                Button("") { showNewEntry = true }
                    .keyboardShortcut("n", modifiers: .command)
                    .opacity(0)
            }
        )
    }

    var mainContent: some View {
        VStack(spacing: 0) {
            TopBar(
                showLogout: $showLogout,
                onNew: { showNewEntry = true },
                onImport: { showImport = true },
                onExport: { exportBibtex() },
                onJournalRatings: { showJournalRatings = true },
                onNetwork: { showNetwork = true },
                onDictionary: { showDictionary = true },
                onMethodBook: { showMethodBook = true },
                onReload: { Task { await reload() } }
            )

            HStack(alignment: .top, spacing: 0) {
                // Sidebar (resizable + collapsible)
                if sidebarCollapsed {
                    VStack(spacing: 12) {
                        Button { sidebarCollapsed = false } label: {
                            Image(systemName: "sidebar.left")
                                .font(.system(size: 13))
                                .foregroundStyle(T.text2)
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.04))
                        }.buttonStyle(.plain)
                        Button { entriesStore.sidebarFilter = .smart(.all) } label: {
                            Image(systemName: "books.vertical")
                                .font(.system(size: 11))
                                .foregroundStyle(entriesStore.sidebarFilter == .smart(.all) ? T.accent : T.text3)
                                .frame(width: 32, height: 32)
                        }.buttonStyle(.plain)
                        Button { entriesStore.sidebarFilter = .smart(.favorites) } label: {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(entriesStore.sidebarFilter == .smart(.favorites) ? T.accent : T.text3)
                                .frame(width: 32, height: 32)
                        }.buttonStyle(.plain)
                        Button { entriesStore.sidebarFilter = .smart(.unread) } label: {
                            Image(systemName: "doc")
                                .font(.system(size: 11))
                                .foregroundStyle(entriesStore.sidebarFilter == .smart(.unread) ? T.accent : T.text3)
                                .frame(width: 32, height: 32)
                        }.buttonStyle(.plain)
                        Button { entriesStore.sidebarFilter = .smart(.rag) } label: {
                            Image(systemName: "magnifyingglass.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(entriesStore.sidebarFilter == .smart(.rag) ? T.accent : T.text3)
                                .frame(width: 32, height: 32)
                        }.buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .frame(width: 48)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(T.bg.opacity(0.4))
                    .overlay(
                        Rectangle().frame(width: 1).foregroundStyle(T.line),
                        alignment: .trailing
                    )
                } else {
                Sidebar()
                    .frame(width: sidebarWidth)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(T.bg.opacity(0.4))
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.white.opacity(0.001))
                            .frame(width: 6)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                    .onChanged { v in
                                        let new = sidebarWidth + v.translation.width
                                        sidebarWidth = max(160, min(400, new))
                                    }
                            )
                            .onHover { inside in
                                if inside { NSCursor.resizeLeftRight.push() }
                                else { NSCursor.pop() }
                            }
                    }
                    .overlay(
                        Rectangle().frame(width: 1).foregroundStyle(T.line),
                        alignment: .trailing
                    )
                } // end else (sidebar expanded)

                // Center pane
                Group {
                    if entriesStore.sidebarFilter == .smart(.rag) {
                        RAGSearchView()
                    } else {
                        VStack(spacing: 0) {
                            EntryListHeader()
                            EntryListView()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(
                    Rectangle().frame(width: 1).foregroundStyle(T.line),
                    alignment: .trailing
                )

                // Detail pane (resizable)
                if let detail = entriesStore.selectedDetail {
                    DetailPane(entry: detail, onOpenAnalysis: { analysisEntry = detail })
                        .id(detail.id)
                        .frame(width: detailWidth)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .background(T.bg.opacity(0.4))
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.001))
                                .frame(width: 6)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                        .onChanged { v in
                                            let new = detailWidth - v.translation.width
                                            detailWidth = max(240, min(600, new))
                                        }
                                )
                                .onHover { inside in
                                    if inside { NSCursor.resizeLeftRight.push() }
                                    else { NSCursor.pop() }
                                }
                        }
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 28, weight: .light))
                            .foregroundStyle(T.text3)
                        Text("Eintrag wählen")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(T.text2)
                    }
                    .frame(width: detailWidth)
                    .frame(maxHeight: .infinity)
                    .background(T.bg.opacity(0.4))
                }
            }
        }
        .sheet(isPresented: $showNewEntry) {
            EntryFormModal(existing: nil, onClose: { showNewEntry = false })
        }
        .sheet(isPresented: $showImport) {
            ImportBibtexModal(onClose: { showImport = false })
        }
        .sheet(isPresented: $showJournalRatings) {
            JournalRatingsModal(onClose: { showJournalRatings = false })
        }
        .confirmationDialog(
            "Wirklich abmelden?",
            isPresented: $showLogout,
            titleVisibility: .visible
        ) {
            Button("Abmelden", role: .destructive) { authStore.clear() }
            Button("Abbrechen", role: .cancel) { }
        }
    }

    func reload() async {
        async let e: () = entriesStore.reload()
        async let c: () = collectionsStore.reload()
        async let t: () = tagsStore.reload()
        _ = await (e, c, t)
    }

    func exportBibtex() {
        Task {
            guard let data = try? await entriesStore.api.request("GET", "/api/literature/entries/export-bibtex"),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let bibtex = json["bibtex"] as? String else { return }
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.init(filenameExtension: "bib") ?? .plainText]
            panel.nameFieldStringValue = "literatur-export.bib"
            if panel.runModal() == .OK, let url = panel.url {
                try? bibtex.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}

// ============================================================
// MARK: - Root
// ============================================================

struct RootView: View {
    @StateObject private var authStore: AuthStore
    @StateObject private var entriesStore: EntriesStore
    @StateObject private var collectionsStore: CollectionsStore
    @StateObject private var tagsStore: TagsStore
    @StateObject private var annotationsStore: AnnotationsStore
    @StateObject private var analysisStore: AnalysisStore
    @StateObject private var ragStore: RAGStore
    @StateObject private var relationsStore: RelationsStore
    private let api: API

    init() {
        let auth = AuthStore()
        let api = API(auth)
        _authStore = StateObject(wrappedValue: auth)
        _entriesStore = StateObject(wrappedValue: EntriesStore(api: api))
        _collectionsStore = StateObject(wrappedValue: CollectionsStore(api: api))
        _tagsStore = StateObject(wrappedValue: TagsStore(api: api))
        _annotationsStore = StateObject(wrappedValue: AnnotationsStore(api: api))
        _analysisStore = StateObject(wrappedValue: AnalysisStore(api: api))
        _ragStore = StateObject(wrappedValue: RAGStore(api: api))
        _relationsStore = StateObject(wrappedValue: RelationsStore(api: api))
        self.api = api
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
                .background(TransparentWindow())
            if authStore.isLoggedIn {
                MainView()
                    .environmentObject(authStore)
                    .environmentObject(entriesStore)
                    .environmentObject(collectionsStore)
                    .environmentObject(tagsStore)
                    .environmentObject(annotationsStore)
                    .environmentObject(analysisStore)
                    .environmentObject(ragStore)
                    .environmentObject(relationsStore)
                    .task {
                        await api.refreshIfPossible()
                        async let e: () = entriesStore.reload()
                        async let c: () = collectionsStore.reload()
                        async let t: () = tagsStore.reload()
                        _ = await (e, c, t)
                    }
            } else {
                LoginView()
                    .environmentObject(authStore)
                    .background(T.bg.ignoresSafeArea())
            }
        }
        .preferredColorScheme(.dark)
    }
}

@main
struct LiteraturMacApp: App {
    init() {
        URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000)
    }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1400, height: 880)
    }
}
