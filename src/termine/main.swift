// Termine — Native SwiftUI client for ConsultingOS Termine (Meeting-Prep)
// Auth: shared keychain (com.dennis.consultingos / default)
// Backend: https://1o618.com

import SwiftUI
import AppKit
import Security

// ============================================================
// MARK: - Config
// ============================================================

enum Config {
    static let apiBase = "https://1o618.com"
    static let deviceName = "macOS Termine"
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
    static let danger      = Color(red: 0.96, green: 0.30, blue: 0.37)
    static let star        = Color(red: 0.98, green: 0.78, blue: 0.30)

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

    // Appointment color palette (matches backend enum)
    static func eventColor(_ name: String) -> Color {
        switch name {
        case "blue":   return Color(red: 0.42, green: 0.55, blue: 0.78)
        case "green":  return Color(red: 0.30, green: 0.72, blue: 0.50)
        case "red":    return Color(red: 0.92, green: 0.36, blue: 0.40)
        case "yellow": return Color(red: 0.95, green: 0.75, blue: 0.30)
        case "purple": return Color(red: 0.62, green: 0.45, blue: 0.82)
        case "orange": return Color(red: 0.96, green: 0.60, blue: 0.32)
        case "pink":   return Color(red: 0.92, green: 0.50, blue: 0.72)
        default:       return Color(red: 0.42, green: 0.55, blue: 0.78)
        }
    }

    // Special-day color palette (Tailwind colors as named in backend)
    static func specialDayColor(_ name: String) -> Color {
        switch name {
        case "red":    return Color(red: 0.92, green: 0.36, blue: 0.40)
        case "orange": return Color(red: 0.96, green: 0.60, blue: 0.32)
        case "yellow": return Color(red: 0.95, green: 0.75, blue: 0.30)
        case "green":  return Color(red: 0.30, green: 0.72, blue: 0.50)
        case "blue":   return Color(red: 0.42, green: 0.55, blue: 0.78)
        case "purple": return Color(red: 0.62, green: 0.45, blue: 0.82)
        case "pink":   return Color(red: 0.92, green: 0.50, blue: 0.72)
        case "cyan":   return Color(red: 0.36, green: 0.74, blue: 0.78)
        case "teal":   return Color(red: 0.30, green: 0.70, blue: 0.66)
        case "indigo": return Color(red: 0.45, green: 0.45, blue: 0.85)
        default:       return Color(red: 0.42, green: 0.55, blue: 0.78)
        }
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func dateString(_ d: Date) -> String { dateFormatter.string(from: d) }
    static func dateFrom(_ s: String) -> Date? { dateFormatter.date(from: s) }

    static func minutesFromTimeString(_ s: String) -> Int {
        let parts = s.split(separator: ":")
        guard parts.count >= 2 else { return 0 }
        return (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0)
    }

    static func timeStringFromMinutes(_ m: Int) -> String {
        let mm = max(0, min(24 * 60 - 1, m))
        return String(format: "%02d:%02d", mm / 60, mm % 60)
    }

    static func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return String(format: "%d:%02d h", h, m)
    }

    static func weekdayShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE"
        return f.string(from: d)
    }

    static func longDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f.string(from: d)
    }

    static func mediumDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM yyyy"
        return f.string(from: d)
    }

    // Convert HTML (TipTap output) to a clean plain text representation
    // suitable for direct editing in a TextEditor. Lists become "• " bullets,
    // paragraphs become double newlines.
    static func htmlToPlainText(_ html: String) -> String {
        if html.isEmpty { return "" }
        var s = html
        // Unwrap nested <li><p>...</p></li>
        s = s.replacingOccurrences(of: "<li>\\s*<p>", with: "<li>", options: .regularExpression)
        s = s.replacingOccurrences(of: "</p>\\s*</li>", with: "</li>", options: .regularExpression)
        // Block tags → newlines
        s = s.replacingOccurrences(of: "</p>", with: "\n\n")
        s = s.replacingOccurrences(of: "<br[^>]*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "</li>", with: "\n")
        s = s.replacingOccurrences(of: "<li[^>]*>", with: "• ", options: .regularExpression)
        s = s.replacingOccurrences(of: "</h[1-6]>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "</div>", with: "\n")
        // Strip remaining tags
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common entities
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&#39;", with: "'")
        s = s.replacingOccurrences(of: "&apos;", with: "'")
        // Collapse 3+ newlines into 2
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Convert plain text back to simple HTML compatible with the web frontend.
    // Bullet lines (• / - / *) become <ul><li><p>...</p></li></ul>,
    // blank lines separate paragraphs, regular lines become <p>...</p>.
    static func plainTextToHTML(_ text: String) -> String {
        if text.isEmpty { return "" }
        let lines = text.components(separatedBy: "\n")
        var result: [String] = []
        var inList = false
        var paragraph: [String] = []

        func escape(_ s: String) -> String {
            return s
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }

        func flushParagraph() {
            if !paragraph.isEmpty {
                let joined = paragraph.map(escape).joined(separator: "<br>")
                if !joined.isEmpty { result.append("<p>\(joined)</p>") }
                paragraph = []
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isBullet = trimmed.hasPrefix("• ") || trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
            if isBullet {
                flushParagraph()
                if !inList { result.append("<ul>"); inList = true }
                let prefixLen = trimmed.hasPrefix("• ") ? 2 : 2
                let item = String(trimmed.dropFirst(prefixLen))
                result.append("<li><p>\(escape(item))</p></li>")
            } else if trimmed.isEmpty {
                flushParagraph()
                if inList { result.append("</ul>"); inList = false }
            } else {
                if inList { result.append("</ul>"); inList = false }
                paragraph.append(trimmed)
            }
        }
        flushParagraph()
        if inList { result.append("</ul>") }
        return result.joined(separator: "")
    }

    // Render HTML/markdown content from TipTap into an AttributedString.
    // Wraps with dark-mode CSS so the rendered text matches the app theme.
    static func attributedHTML(_ html: String) -> AttributedString {
        if html.isEmpty { return AttributedString("") }
        let styled = """
        <style>
        * { color: rgb(237, 237, 237); font-family: -apple-system, "SF Pro Text", sans-serif; font-size: 13px; line-height: 1.45; }
        body { margin: 0; padding: 0; }
        ul, ol { margin: 0 0 8px 0; padding-left: 18px; }
        li { margin-bottom: 3px; }
        p { margin: 0 0 8px 0; }
        h1 { font-size: 18px; color: rgb(245, 245, 245); margin: 8px 0; }
        h2 { font-size: 15px; color: rgb(245, 245, 245); margin: 8px 0; }
        h3 { font-size: 13px; color: rgb(245, 245, 245); margin: 6px 0; }
        a { color: rgb(160, 130, 210); text-decoration: underline; }
        code { font-family: ui-monospace, "SF Mono", monospace; background: rgba(255,255,255,0.06); padding: 1px 4px; border-radius: 2px; }
        strong, b { color: rgb(250, 250, 250); }
        blockquote { border-left: 2px solid rgba(140,107,191,0.5); padding-left: 8px; color: rgb(180,180,180); margin: 4px 0; }
        </style>
        """ + html
        guard let data = styled.data(using: .utf8) else { return AttributedString(html) }
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        if let nsAttr = try? NSAttributedString(data: data, options: opts, documentAttributes: nil),
           let result = try? AttributedString(nsAttr, including: \.swiftUI) {
            return result
        }
        return AttributedString(html)
    }

    static func mondayOf(_ d: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return cal.date(from: comps) ?? d
    }

    static func startOfMonth(_ d: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: d)
        return cal.date(from: comps) ?? d
    }

    static func endOfMonth(_ d: Date) -> Date {
        let cal = Calendar.current
        let start = startOfMonth(d)
        return cal.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? d
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

struct EventEmbedded: Codable, Equatable, Hashable {
    let id: Int
    var title: String
    var date: String              // YYYY-MM-DD
    var start_time: String        // HH:MM
    var end_time: String          // HH:MM
    var location: String
    var description: String
    var color: String
    var is_meeting: Bool
    var meeting_link: String?
}

struct ChecklistItem: Codable, Equatable, Hashable, Identifiable {
    let id: String
    var text: String
    var completed: Bool
    var kanban_card_id: Int?
}

struct AppointmentAttachment: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var file_url: String
    var file_type: String
    var file_size: Int
    var created_at: String
}

struct AppointmentList: Codable, Identifiable, Hashable {
    let id: Int
    let event_id: Int
    var event: EventEmbedded
    var client_id: Int?
    var client_name: String?
    var client_logo_url: String?
    var client_primary_color: String?
    var agenda_count: Int
    var checklist_open: Int
    var checklist_total: Int
    var has_notes: Bool
    var is_starred: Bool
    var attachment_count: Int
    var updated_at: String
}

struct AppointmentDetail: Codable, Identifiable, Hashable {
    let id: Int
    let event_id: Int
    var event: EventEmbedded
    var client_id: Int?
    var client_name: String?
    var client_logo_url: String?
    var client_primary_color: String?
    var agenda_items: [String]
    var preparation_notes: String
    var notes: String
    var is_starred: Bool
    var checklist: [ChecklistItem]
    var attachments: [AppointmentAttachment]
    var created_at: String
    var updated_at: String
}

struct SpecialDayType: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var color: String
    var icon: String
    var created_at: String
}

struct SpecialDay: Codable, Identifiable, Hashable {
    let id: Int
    var date: String
    var note: String
    var special_day_type: SpecialDayType
    var created_at: String
}

struct TTClient: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var company: String
    var logo_url: String?
    var primary_color: String?
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
            // Another app may have refreshed the token meanwhile
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

    func uploadMultipart(_ path: String, fileURL: URL, fieldName: String = "file") async throws -> Data {
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
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "svg": return "image/svg+xml"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "csv": return "text/csv"
        case "rtf": return "application/rtf"
        case "zip": return "application/zip"
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

    // Appointments
    func listAppointments(from: String? = nil, to: String? = nil, includePast: Bool = true) async throws -> [AppointmentList] {
        var params: [String] = ["include_past=\(includePast)"]
        if let from = from { params.append("start_date=\(from)") }
        if let to = to { params.append("end_date=\(to)") }
        let path = "/api/termine/?" + params.joined(separator: "&")
        let data = try await request("GET", path)
        return (try? JSONDecoder().decode([AppointmentList].self, from: data)) ?? []
    }

    func getAppointment(_ eventId: Int) async throws -> AppointmentDetail? {
        let data = try await request("GET", "/api/termine/\(eventId)")
        return try? JSONDecoder().decode(AppointmentDetail.self, from: data)
    }

    func createAppointment(_ data: [String: Any]) async throws -> AppointmentDetail? {
        let resp = try await request("POST", "/api/termine/", body: data)
        return try? JSONDecoder().decode(AppointmentDetail.self, from: resp)
    }

    func updateAppointment(_ eventId: Int, _ data: [String: Any]) async throws -> AppointmentDetail? {
        let resp = try await request("PUT", "/api/termine/\(eventId)", body: data)
        return try? JSONDecoder().decode(AppointmentDetail.self, from: resp)
    }

    func deleteAppointment(_ eventId: Int) async throws {
        _ = try await request("DELETE", "/api/termine/\(eventId)")
    }

    // Attachments
    func uploadAttachment(eventId: Int, fileURL: URL) async throws -> AppointmentAttachment? {
        let data = try await uploadMultipart("/api/termine/\(eventId)/attachments", fileURL: fileURL)
        return try? JSONDecoder().decode(AppointmentAttachment.self, from: data)
    }

    func deleteAttachment(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/termine/attachments/\(id)")
    }

    // Special-Day-Types
    func listSpecialDayTypes() async throws -> [SpecialDayType] {
        let data = try await request("GET", "/api/termine/special-day-types/")
        return (try? JSONDecoder().decode([SpecialDayType].self, from: data)) ?? []
    }

    func createSpecialDayType(_ data: [String: Any]) async throws -> SpecialDayType? {
        let resp = try await request("POST", "/api/termine/special-day-types/", body: data)
        return try? JSONDecoder().decode(SpecialDayType.self, from: resp)
    }

    func updateSpecialDayType(_ id: Int, _ data: [String: Any]) async throws -> SpecialDayType? {
        let resp = try await request("PUT", "/api/termine/special-day-types/\(id)", body: data)
        return try? JSONDecoder().decode(SpecialDayType.self, from: resp)
    }

    func deleteSpecialDayType(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/termine/special-day-types/\(id)")
    }

    // Special-Days
    func listSpecialDays(from: String? = nil, to: String? = nil) async throws -> [SpecialDay] {
        var params: [String] = []
        if let from = from { params.append("start_date=\(from)") }
        if let to = to { params.append("end_date=\(to)") }
        let suffix = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let data = try await request("GET", "/api/termine/special-days/" + suffix)
        return (try? JSONDecoder().decode([SpecialDay].self, from: data)) ?? []
    }

    func createSpecialDay(_ data: [String: Any]) async throws -> SpecialDay? {
        let resp = try await request("POST", "/api/termine/special-days/", body: data)
        return try? JSONDecoder().decode(SpecialDay.self, from: resp)
    }

    func createSpecialDaysBulk(_ data: [String: Any]) async throws -> [SpecialDay] {
        let resp = try await request("POST", "/api/termine/special-days/bulk/", body: data)
        return (try? JSONDecoder().decode([SpecialDay].self, from: resp)) ?? []
    }

    func updateSpecialDay(_ id: Int, _ data: [String: Any]) async throws -> SpecialDay? {
        let resp = try await request("PUT", "/api/termine/special-days/\(id)", body: data)
        return try? JSONDecoder().decode(SpecialDay.self, from: resp)
    }

    func deleteSpecialDay(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/termine/special-days/\(id)")
    }

    // Clients (read-only from timetracking)
    func listClients() async throws -> [TTClient] {
        let data = try await request("GET", "/api/timetracking/clients/")
        return (try? JSONDecoder().decode([TTClient].self, from: data)) ?? []
    }
}

// ============================================================
// MARK: - Stores
// ============================================================

@MainActor
final class AppointmentsStore: ObservableObject {
    @Published var appointments: [AppointmentList] = []
    @Published var selectedDetail: AppointmentDetail? = nil
    @Published var loading: Bool = false
    let api: API
    init(api: API) { self.api = api }

    func reload(month: Date) async {
        loading = true
        let from = T.dateString(T.startOfMonth(month))
        let to = T.dateString(T.endOfMonth(month))
        if let list = try? await api.listAppointments(from: from, to: to, includePast: true) {
            withAnimation(.easeInOut(duration: 0.2)) { appointments = list }
        }
        loading = false
    }

    func loadDetail(eventId: Int) async {
        if let d = try? await api.getAppointment(eventId) {
            selectedDetail = d
        }
    }

    func appointments(on date: String) -> [AppointmentList] {
        appointments
            .filter { $0.event.date == date }
            .sorted { $0.event.start_time < $1.event.start_time }
    }

    func create(_ data: [String: Any]) async -> AppointmentDetail? {
        guard let new = try? await api.createAppointment(data) else { return nil }
        // refresh list for the month containing the new event
        if let date = T.dateFrom(new.event.date) {
            await reload(month: date)
        }
        selectedDetail = new
        return new
    }

    func update(_ eventId: Int, _ data: [String: Any]) async -> AppointmentDetail? {
        guard let updated = try? await api.updateAppointment(eventId, data) else { return nil }
        selectedDetail = updated
        // Update list inline
        if let i = appointments.firstIndex(where: { $0.event_id == eventId }) {
            appointments[i].event = updated.event
            appointments[i].is_starred = updated.is_starred
            appointments[i].client_id = updated.client_id
            appointments[i].client_name = updated.client_name
            appointments[i].client_logo_url = updated.client_logo_url
            appointments[i].client_primary_color = updated.client_primary_color
            appointments[i].checklist_open = updated.checklist.filter { !$0.completed }.count
            appointments[i].checklist_total = updated.checklist.count
            appointments[i].attachment_count = updated.attachments.count
            appointments[i].has_notes = !updated.notes.isEmpty || !updated.preparation_notes.isEmpty
            appointments[i].updated_at = updated.updated_at
        }
        return updated
    }

    func delete(_ eventId: Int) async {
        try? await api.deleteAppointment(eventId)
        appointments.removeAll { $0.event_id == eventId }
        if selectedDetail?.event_id == eventId {
            selectedDetail = nil
        }
    }

    func addAttachment(_ a: AppointmentAttachment) {
        guard var d = selectedDetail else { return }
        d.attachments.append(a)
        selectedDetail = d
        if let i = appointments.firstIndex(where: { $0.event_id == d.event_id }) {
            appointments[i].attachment_count = d.attachments.count
        }
    }

    func removeAttachment(_ id: Int) async {
        try? await api.deleteAttachment(id)
        guard var d = selectedDetail else { return }
        d.attachments.removeAll { $0.id == id }
        selectedDetail = d
        if let i = appointments.firstIndex(where: { $0.event_id == d.event_id }) {
            appointments[i].attachment_count = d.attachments.count
        }
    }
}

@MainActor
final class SpecialDayTypesStore: ObservableObject {
    @Published var types: [SpecialDayType] = []
    let api: API
    init(api: API) { self.api = api }

    func reload() async {
        if let t = try? await api.listSpecialDayTypes() { types = t }
    }

    func create(_ data: [String: Any]) async {
        if let new = try? await api.createSpecialDayType(data) {
            types.append(new)
        }
    }

    func update(_ id: Int, _ data: [String: Any]) async {
        if let updated = try? await api.updateSpecialDayType(id, data),
           let i = types.firstIndex(where: { $0.id == id }) {
            types[i] = updated
        }
    }

    func delete(_ id: Int) async {
        try? await api.deleteSpecialDayType(id)
        types.removeAll { $0.id == id }
    }
}

@MainActor
final class SpecialDaysStore: ObservableObject {
    @Published var days: [SpecialDay] = []
    let api: API
    init(api: API) { self.api = api }

    func reload(from: String? = nil, to: String? = nil) async {
        if let d = try? await api.listSpecialDays(from: from, to: to) { days = d }
    }

    func day(on date: String) -> SpecialDay? {
        days.first { $0.date == date }
    }

    func mark(date: Date, typeId: Int, note: String, overwrite: Bool) async {
        let data: [String: Any] = [
            "date": T.dateString(date),
            "special_day_type_id": typeId,
            "note": note,
            "overwrite": overwrite,
        ]
        if let new = try? await api.createSpecialDay(data) {
            days.removeAll { $0.date == new.date }
            days.append(new)
        }
    }

    func markRange(from: Date, to: Date, typeId: Int, note: String, overwrite: Bool) async {
        let data: [String: Any] = [
            "start_date": T.dateString(from),
            "end_date": T.dateString(to),
            "special_day_type_id": typeId,
            "note": note,
            "overwrite": overwrite,
        ]
        if let created = try? await api.createSpecialDaysBulk(data) {
            for new in created {
                days.removeAll { $0.date == new.date }
                days.append(new)
            }
        }
    }

    func delete(_ id: Int) async {
        try? await api.deleteSpecialDay(id)
        days.removeAll { $0.id == id }
    }
}

@MainActor
final class ClientsStore: ObservableObject {
    @Published var clients: [TTClient] = []
    let api: API
    init(api: API) { self.api = api }

    func reload() async {
        if let cs = try? await api.listClients() { clients = cs }
    }

    func client(id: Int?) -> TTClient? {
        guard let id = id else { return nil }
        return clients.first { $0.id == id }
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
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(T.accent)

            VStack(spacing: 4) {
                Text("Termine")
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
                    }
                    .buttonStyle(.plain)

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

            Text("Geteilt mit Kanban + Zeit · Token bleibt 30 Tage gültig")
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
            w.minSize = NSSize(width: 1000, height: 640)
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
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @Binding var showLogout: Bool
    let onNew: () -> Void
    let onSpecialDays: () -> Void
    let onReload: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onNew) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                    Text("Neuer Termin")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(T.accent)
            }.buttonStyle(.plain)

            Button(action: onSpecialDays) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Spezial-Tage")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(T.text2)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Color.white.opacity(0.04))
            }.buttonStyle(.plain)

            Spacer()

            if appointmentsStore.loading {
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
// MARK: - MiniCalendar
// ============================================================

struct MiniCalendar: View {
    @Binding var month: Date
    @Binding var selectedDate: Date
    let onDragRange: (Date, Date) -> Void
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @EnvironmentObject var specialDaysStore: SpecialDaysStore
    @State private var dragStart: Date? = nil
    @State private var dragEnd: Date? = nil

    private let cal = Calendar.current

    private var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: month).capitalized
    }

    private var gridDates: [Date] {
        let start = T.startOfMonth(month)
        let weekday = cal.component(.weekday, from: start)
        // Sunday=1 → Monday=1: offset to previous Monday
        let offset = (weekday + 5) % 7
        guard let firstGridDate = cal.date(byAdding: .day, value: -offset, to: start) else { return [] }
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: firstGridDate) }
    }

    private func navigate(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: month) {
            month = d
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Button { navigate(-1) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(T.text2)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
                Text(monthLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.text1)
                    .frame(maxWidth: .infinity)
                Button { navigate(1) } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(T.text2)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
                Button {
                    let today = Date()
                    month = today
                    selectedDate = today
                } label: {
                    Text("Heute")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
            }

            HStack(spacing: 2) {
                ForEach(["MO","DI","MI","DO","FR","SA","SO"], id: \.self) { wd in
                    Text(wd)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.4)
                        .foregroundStyle(T.text3)
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 2) {
                ForEach(0..<6, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            if idx < gridDates.count {
                                let date = gridDates[idx]
                                MiniCalendarCell(
                                    date: date,
                                    inCurrentMonth: cal.isDate(date, equalTo: month, toGranularity: .month),
                                    isSelected: cal.isDate(date, inSameDayAs: selectedDate),
                                    isInDragRange: dateInDragRange(date),
                                    onTap: { selectedDate = date },
                                    onDragStart: {
                                        dragStart = date
                                        dragEnd = date
                                    },
                                    onDragOver: {
                                        if dragStart != nil { dragEnd = date }
                                    },
                                    onDragEnd: {
                                        if let s = dragStart, let e = dragEnd, !cal.isDate(s, inSameDayAs: e) {
                                            let lo = min(s, e)
                                            let hi = max(s, e)
                                            onDragRange(lo, hi)
                                        }
                                        dragStart = nil
                                        dragEnd = nil
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
        .task(id: T.dateString(T.startOfMonth(month))) {
            await appointmentsStore.reload(month: month)
            let from = T.dateString(T.startOfMonth(month))
            let to = T.dateString(T.endOfMonth(month))
            await specialDaysStore.reload(from: from, to: to)
        }
    }

    func dateInDragRange(_ date: Date) -> Bool {
        guard let s = dragStart, let e = dragEnd else { return false }
        let lo = min(s, e)
        let hi = max(s, e)
        return date >= cal.startOfDay(for: lo) && date <= cal.startOfDay(for: hi).addingTimeInterval(86400 - 1)
    }
}

struct MiniCalendarCell: View {
    let date: Date
    let inCurrentMonth: Bool
    let isSelected: Bool
    let isInDragRange: Bool
    let onTap: () -> Void
    let onDragStart: () -> Void
    let onDragOver: () -> Void
    let onDragEnd: () -> Void
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @EnvironmentObject var specialDaysStore: SpecialDaysStore

    private var dayNum: Int { Calendar.current.component(.day, from: date) }
    private var isToday: Bool { Calendar.current.isDateInToday(date) }
    private var hasAppointments: Bool {
        !appointmentsStore.appointments(on: T.dateString(date)).isEmpty
    }
    private var specialDay: SpecialDay? {
        specialDaysStore.day(on: T.dateString(date))
    }

    var body: some View {
        ZStack {
            if let sd = specialDay {
                Rectangle()
                    .fill(T.specialDayColor(sd.special_day_type.color).opacity(0.30))
            }
            if isInDragRange {
                Rectangle()
                    .fill(T.accent.opacity(0.30))
            } else if isSelected {
                Rectangle()
                    .fill(T.accent.opacity(0.20))
                    .overlay(Rectangle().stroke(T.accent.opacity(0.7), lineWidth: 1))
            } else if isToday {
                Rectangle()
                    .fill(T.accentSoft)
            }
            VStack(spacing: 1) {
                Text("\(dayNum)")
                    .font(.system(size: 11, weight: isToday ? .bold : .medium))
                    .foregroundStyle(
                        inCurrentMonth
                            ? (isToday ? T.accent : T.text1)
                            : T.text3.opacity(0.5)
                    )
                Circle()
                    .fill(hasAppointments ? T.accent : Color.clear)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .gesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .global)
                .onChanged { _ in
                    onDragOver()
                }
                .onEnded { _ in
                    onDragEnd()
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { v in
                    if v.translation == .zero {
                        onDragStart()
                    }
                }
        )
    }
}

// ============================================================
// MARK: - DayEventsList
// ============================================================

struct DayEventsList: View {
    @Binding var selectedDate: Date
    @Binding var selectedEventId: Int?
    @EnvironmentObject var appointmentsStore: AppointmentsStore

    var events: [AppointmentList] {
        appointmentsStore.appointments(on: T.dateString(selectedDate))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(T.longDate(selectedDate).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(T.text3)
                .padding(.horizontal, 4)

            if events.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(T.text3)
                    Text("Keine Termine")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 6) {
                        ForEach(events) { event in
                            DayEventRow(
                                event: event,
                                selected: selectedEventId == event.event_id,
                                onTap: {
                                    selectedEventId = event.event_id
                                    Task { await appointmentsStore.loadDetail(eventId: event.event_id) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

struct DayEventRow: View {
    let event: AppointmentList
    let selected: Bool
    let onTap: () -> Void
    @State private var hover = false

    var color: Color {
        T.hexColor(event.client_primary_color) ?? T.eventColor(event.event.color)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                Rectangle().fill(color).frame(width: 4)
                VStack(alignment: .leading, spacing: 4) {
                    // Row 1: Star + Title
                    HStack(spacing: 5) {
                        if event.is_starred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(T.star)
                        }
                        Text(event.event.title)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(T.text1)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }

                    // Row 2: Client (with logo if available)
                    HStack(spacing: 6) {
                        if let cn = event.client_name, !cn.isEmpty {
                            if let url = T.absoluteURL(event.client_logo_url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFit()
                                    default: Text(String(cn.prefix(1)))
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 16, height: 16)
                                .background(Color.white)
                            } else {
                                Text(String(cn.prefix(1)).uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(color)
                            }
                            Text(cn)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(T.text2)
                                .lineLimit(1)
                        } else {
                            Image(systemName: "person")
                                .font(.system(size: 9))
                                .foregroundStyle(T.text3)
                                .frame(width: 16, height: 16)
                            Text("Kein Kunde")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                        }
                        Spacer(minLength: 0)
                    }

                    // Row 3: Time + meta
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(T.text3)
                        Text("\(event.event.start_time)–\(event.event.end_time)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(T.text3)
                        Spacer(minLength: 0)
                        if event.attachment_count > 0 {
                            Image(systemName: "paperclip")
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                        if event.checklist_total > 0 {
                            Text("\(event.checklist_open)/\(event.checklist_total)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(T.text3)
                        }
                    }
                }
                .padding(.horizontal, 11).padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? T.accentSoft : (hover ? T.cardHover : T.card))
            .overlay(
                Rectangle().stroke(selected ? T.accent.opacity(0.5) : T.line, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

// ============================================================
// MARK: - Pickers (Client)
// ============================================================

struct ClientPickerPopover: View {
    let selectedId: Int?
    let onSelect: (TTClient?) -> Void
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var search: String = ""

    var filtered: [TTClient] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = clientsStore.clients.sorted { $0.name < $1.name }
        if q.isEmpty { return sorted }
        return sorted.filter { $0.name.lowercased().contains(q) || $0.company.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text3)
                TextField("Kunde suchen…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.white.opacity(0.04))
            Divider().background(T.line)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Button { onSelect(nil) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                                .frame(width: 22, height: 22)
                            Text("Kein Kunde")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(T.text2)
                            Spacer()
                            if selectedId == nil {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(T.accent)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)

                    ForEach(filtered) { c in
                        ClientPickerRow(
                            client: c,
                            isSelected: c.id == selectedId,
                            onTap: { onSelect(c) }
                        )
                    }
                    Color.clear.frame(height: 6)
                }
            }
            .frame(maxHeight: 360)
        }
        .frame(width: 280)
        .background(T.bg)
    }
}

struct ClientPickerRow: View {
    let client: TTClient
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hover = false

    var accent: Color { T.hexColor(client.primary_color) ?? T.accent }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if let url = T.absoluteURL(client.logo_url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFit()
                        default: Image(systemName: "person.fill").font(.system(size: 9)).foregroundStyle(accent)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .background(Color.white)
                } else {
                    Text(String(client.name.prefix(1)).uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(accent)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(client.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(T.text1)
                        .lineLimit(1)
                    if !client.company.isEmpty {
                        Text(client.company)
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(T.accent)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(hover ? Color.white.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in hover = h }
    }
}

// ============================================================
// MARK: - DualHandleSlider (time range)
// ============================================================

struct DualHandleSlider: View {
    @Binding var startMin: Int
    @Binding var endMin: Int

    let minMinutes = 6 * 60
    let maxMinutes = 23 * 60
    var range: Int { maxMinutes - minMinutes }

    func minutesFor(x: CGFloat, width: CGFloat) -> Int {
        let pct = max(0, min(1, x / width))
        let m = minMinutes + Int(round(Double(pct) * Double(range) / 15.0)) * 15
        return max(minMinutes, min(maxMinutes, m))
    }

    func position(for minutes: Int, width: CGFloat) -> CGFloat {
        let pct = CGFloat(minutes - minMinutes) / CGFloat(range)
        return pct * width
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(T.timeStringFromMinutes(startMin))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(T.text1)
                Spacer()
                Text(T.formatHours(endMin - startMin))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(T.accent)
                Spacer()
                Text(T.timeStringFromMinutes(endMin))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(T.text1)
            }

            GeometryReader { geo in
                let w = geo.size.width
                let startX = position(for: startMin, width: w)
                let endX = position(for: endMin, width: w)

                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Rectangle()
                        .fill(T.accent.opacity(0.6))
                        .frame(width: max(0, endX - startX), height: 6)
                        .offset(x: startX)
                        .frame(maxHeight: .infinity, alignment: .center)

                    Circle()
                        .fill(T.accent)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: startX - 8)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onChanged { v in
                                    let m = minutesFor(x: startX + v.translation.width, width: w)
                                    if m < endMin { startMin = m }
                                }
                        )

                    Circle()
                        .fill(T.accent)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: endX - 8)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                                .onChanged { v in
                                    let m = minutesFor(x: endX + v.translation.width, width: w)
                                    if m > startMin { endMin = m }
                                }
                        )
                }
            }
            .frame(height: 22)

            HStack(spacing: 0) {
                ForEach(stride(from: 6, through: 22, by: 2).map { $0 }, id: \.self) { h in
                    Text("\(h)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// ============================================================
// MARK: - Color picker
// ============================================================

let eventColorOptions = ["blue", "green", "red", "yellow", "purple", "orange", "pink"]

struct ColorDotPicker: View {
    @Binding var selected: String

    var body: some View {
        HStack(spacing: 8) {
            ForEach(eventColorOptions, id: \.self) { c in
                Button { selected = c } label: {
                    ZStack {
                        Circle()
                            .fill(T.eventColor(c))
                            .frame(width: 18, height: 18)
                        if selected == c {
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 24, height: 24)
                }.buttonStyle(.plain)
            }
        }
    }
}

// ============================================================
// MARK: - CreateTerminModal
// ============================================================

struct CreateTerminModal: View {
    let initialDate: Date
    let onClose: () -> Void
    let onCreated: (AppointmentDetail) -> Void
    @EnvironmentObject var appointmentsStore: AppointmentsStore

    @State private var title: String = ""
    @State private var date: Date
    @State private var startMin: Int = 9 * 60
    @State private var endMin: Int = 10 * 60
    @State private var location: String = ""
    @State private var color: String = "blue"
    @State private var isMeeting: Bool = false
    @State private var saving: Bool = false

    init(initialDate: Date, onClose: @escaping () -> Void, onCreated: @escaping (AppointmentDetail) -> Void) {
        self.initialDate = initialDate
        self.onClose = onClose
        self.onCreated = onCreated
        _date = State(initialValue: initialDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            T.eventColor(color).frame(height: 3)

            HStack {
                Text("Neuer Termin")
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

            VStack(alignment: .leading, spacing: 14) {
                fieldLabel("Titel")
                TextField("Titel", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                fieldLabel("Datum")
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .labelsHidden()

                fieldLabel("Zeitraum")
                DualHandleSlider(startMin: $startMin, endMin: $endMin)

                fieldLabel("Ort")
                TextField("Optional", text: $location)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                fieldLabel("Farbe")
                ColorDotPicker(selected: $color)

                Button {
                    isMeeting.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isMeeting ? "checkmark.square.fill" : "square")
                            .font(.system(size: 14))
                            .foregroundStyle(isMeeting ? T.accent : T.text3)
                        Image(systemName: "video")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                        Text("Online-Meeting (Link generieren)")
                            .font(.system(size: 12))
                            .foregroundStyle(T.text1)
                        Spacer()
                    }
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

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
                        let fields: [String: Any] = [
                            "title": title,
                            "date": T.dateString(date),
                            "start_time": T.timeStringFromMinutes(startMin),
                            "end_time": T.timeStringFromMinutes(endMin),
                            "location": location,
                            "color": color,
                            "is_meeting": isMeeting,
                        ]
                        if let new = await appointmentsStore.create(fields) {
                            onCreated(new)
                        }
                        saving = false
                        onClose()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if saving { ProgressView().controlSize(.mini).tint(.white) }
                        Text("Erstellen")
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
        .frame(width: 480)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }

    func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(T.text3)
            .tracking(0.6)
    }
}

// ============================================================
// MARK: - TerminDetailHeader
// ============================================================

struct TerminDetailHeader: View {
    let detail: AppointmentDetail
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @EnvironmentObject var clientsStore: ClientsStore

    @State private var title: String
    @State private var date: Date
    @State private var startMin: Int
    @State private var endMin: Int
    @State private var location: String
    @State private var color: String
    @State private var isMeeting: Bool
    @State private var isStarred: Bool
    @State private var clientId: Int?
    @State private var clientPickerOpen: Bool = false
    @State private var editingTitle: Bool = false
    @State private var pendingDeleteId: Int? = nil

    init(detail: AppointmentDetail) {
        self.detail = detail
        _title = State(initialValue: detail.event.title)
        _date = State(initialValue: T.dateFrom(detail.event.date) ?? Date())
        _startMin = State(initialValue: T.minutesFromTimeString(detail.event.start_time))
        _endMin = State(initialValue: T.minutesFromTimeString(detail.event.end_time))
        _location = State(initialValue: detail.event.location)
        _color = State(initialValue: detail.event.color)
        _isMeeting = State(initialValue: detail.event.is_meeting)
        _isStarred = State(initialValue: detail.is_starred)
        _clientId = State(initialValue: detail.client_id)
    }

    var accent: Color { T.eventColor(color) }
    var selectedClient: TTClient? { clientsStore.client(id: clientId) }

    func saveField(_ fields: [String: Any]) {
        Task { _ = await appointmentsStore.update(detail.event_id, fields) }
    }

    var body: some View {
        VStack(spacing: 0) {
            accent.frame(height: 4)

            VStack(alignment: .leading, spacing: 12) {
                // Title row
                HStack(spacing: 8) {
                    if editingTitle {
                        TextField("Titel", text: $title, onCommit: {
                            editingTitle = false
                            saveField(["title": title])
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(T.text1)
                    } else {
                        Text(title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(T.text1)
                            .onTapGesture(count: 2) { editingTitle = true }
                    }
                    Button {
                        isStarred.toggle()
                        saveField(["is_starred": isStarred])
                    } label: {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundStyle(isStarred ? T.star : T.text3)
                    }.buttonStyle(.plain)
                    Button { editingTitle.toggle() } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                    Spacer()
                    Button {
                        pendingDeleteId = detail.event_id
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(7)
                            .background(Color.red.opacity(0.08))
                    }.buttonStyle(.plain)
                }

                // Date + Time row
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.field)
                            .labelsHidden()
                            .onChange(of: date) { _, new in
                                saveField(["date": T.dateString(new)])
                            }
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                        Text("\(T.timeStringFromMinutes(startMin))–\(T.timeStringFromMinutes(endMin))")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(T.text1)
                    }
                }

                DualHandleSlider(startMin: $startMin, endMin: $endMin)
                    .onChange(of: startMin) { _, new in
                        saveField(["start_time": T.timeStringFromMinutes(new)])
                    }
                    .onChange(of: endMin) { _, new in
                        saveField(["end_time": T.timeStringFromMinutes(new)])
                    }

                // Client + Location row
                HStack(spacing: 10) {
                    Button { clientPickerOpen = true } label: {
                        HStack(spacing: 6) {
                            if let c = selectedClient {
                                if let url = T.absoluteURL(c.logo_url) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img): img.resizable().scaledToFit()
                                        default: Text(String(c.name.prefix(1))).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 22, height: 22)
                                    .background(Color.white)
                                } else {
                                    Text(String(c.name.prefix(1)).uppercased())
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(T.hexColor(c.primary_color) ?? T.accent)
                                }
                                Text(c.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(T.text1)
                                    .lineLimit(1)
                            } else {
                                Image(systemName: "person")
                                    .font(.system(size: 11))
                                    .foregroundStyle(T.text3)
                                Text("Kunde wählen")
                                    .font(.system(size: 12))
                                    .foregroundStyle(T.text3)
                            }
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundStyle(T.text3)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $clientPickerOpen, arrowEdge: .top) {
                        ClientPickerPopover(
                            selectedId: clientId,
                            onSelect: { c in
                                clientId = c?.id
                                clientPickerOpen = false
                                saveField(["client_id": c?.id ?? 0])
                            }
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                        TextField("Ort", text: $location, onCommit: {
                            saveField(["location": location])
                        })
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }

                HStack(spacing: 14) {
                    Button {
                        isMeeting.toggle()
                        saveField(["is_meeting": isMeeting])
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isMeeting ? "checkmark.square.fill" : "square")
                                .font(.system(size: 13))
                                .foregroundStyle(isMeeting ? T.accent : T.text3)
                            Image(systemName: "video")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                            Text("Meeting")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                        }
                    }.buttonStyle(.plain)

                    if isMeeting, let link = detail.event.meeting_link, !link.isEmpty {
                        Button {
                            if let u = URL(string: link) { NSWorkspace.shared.open(u) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 9))
                                Text(link)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(T.accent)
                        }.buttonStyle(.plain)
                    }

                    Spacer()

                    ColorDotPicker(selected: $color)
                        .onChange(of: color) { _, new in
                            saveField(["color": new])
                        }
                }
            }
            .padding(18)
        }
        .background(T.bg.opacity(0.4))
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(T.line),
            alignment: .bottom
        )
        .confirmationDialog(
            "Termin wirklich löschen?",
            isPresented: Binding(
                get: { pendingDeleteId != nil },
                set: { if !$0 { pendingDeleteId = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await appointmentsStore.delete(id) }
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
    }
}

// ============================================================
// MARK: - Layout mode + Sections
// ============================================================

enum LayoutMode: String, CaseIterable {
    case tabs, split, segmented
    var label: String {
        switch self {
        case .tabs: return "Tabs"
        case .split: return "Split"
        case .segmented: return "Segmented"
        }
    }
}

enum DetailSection: String, CaseIterable, Identifiable {
    case notes, tasks, files
    var id: String { rawValue }
    var label: String {
        switch self {
        case .notes: return "Notizen"
        case .tasks: return "Aufgaben"
        case .files: return "Dateien"
        }
    }
    var icon: String {
        switch self {
        case .notes: return "pencil.and.outline"
        case .tasks: return "checklist"
        case .files: return "paperclip"
        }
    }
}

struct LayoutModeSwitcher: View {
    @Binding var mode: LayoutMode
    var body: some View {
        HStack(spacing: 0) {
            ForEach(LayoutMode.allCases, id: \.self) { m in
                Button { mode = m } label: {
                    Text(m.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(mode == m ? T.text1 : T.text3)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(mode == m ? T.accentSoft : Color.white.opacity(0.03))
                        .overlay(Rectangle().stroke(mode == m ? T.accent.opacity(0.5) : T.line, lineWidth: 0.5))
                }.buttonStyle(.plain)
            }
        }
    }
}

// ============================================================
// MARK: - PreparationSection / NotesSection (text editor + debounce)
// ============================================================

struct DebouncedTextSection: View {
    let title: String
    let icon: String
    let placeholder: String
    let initialText: String
    let onSave: (String) -> Void

    @State private var text: String = ""
    @State private var debounceTask: Task<Void, Never>? = nil
    @State private var savedHint: Bool = false
    @State private var editing: Bool = true

    init(title: String, icon: String, placeholder: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.icon = icon
        self.placeholder = placeholder
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: T.htmlToPlainText(initialText))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.text3)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(T.text3)
                Spacer()
                if savedHint {
                    Text("gespeichert")
                        .font(.system(size: 9))
                        .foregroundStyle(T.text3)
                        .transition(.opacity)
                }
                Button {
                    editing.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: editing ? "eye" : "pencil")
                            .font(.system(size: 9))
                        Text(editing ? "Vorschau" : "Bearbeiten")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
            }

            if editing {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 13))
                            .foregroundStyle(T.text3.opacity(0.7))
                            .padding(.horizontal, 10).padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 13))
                        .foregroundStyle(T.text1)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .frame(minHeight: 140)
                }
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.accent.opacity(0.3), lineWidth: 0.5))
            } else {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text3.opacity(0.7))
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color.white.opacity(0.02))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                } else {
                    Text(T.attributedHTML(T.plainTextToHTML(text)))
                        .font(.system(size: 13))
                        .foregroundStyle(T.text1)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .textSelection(.enabled)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.white.opacity(0.02))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
            }
        }
        .onChange(of: text) { _, newVal in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                onSave(T.plainTextToHTML(newVal))
                await MainActor.run {
                    withAnimation { savedHint = true }
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    withAnimation { savedHint = false }
                }
            }
        }
    }
}

// ============================================================
// MARK: - ChecklistSection
// ============================================================

struct ChecklistSection: View {
    let detail: AppointmentDetail
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @State private var items: [ChecklistItem]
    @State private var newText: String = ""
    @State private var debounceTask: Task<Void, Never>? = nil

    init(detail: AppointmentDetail) {
        self.detail = detail
        _items = State(initialValue: detail.checklist)
    }

    var completed: Int { items.filter { $0.completed }.count }
    var total: Int { items.count }
    var pct: Double { total > 0 ? Double(completed) / Double(total) : 0 }

    func saveItems() {
        let payload = items.map { item -> [String: Any] in
            var d: [String: Any] = [
                "id": item.id,
                "text": item.text,
                "completed": item.completed,
            ]
            if let cid = item.kanban_card_id { d["kanban_card_id"] = cid }
            return d
        }
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            if let updated = await appointmentsStore.update(detail.event_id, [
                "checklist": payload,
                "sync_checklist_to_kanban": true,
            ]) {
                // Sync IDs back so newly created kanban cards are reflected locally
                await MainActor.run {
                    items = updated.checklist
                }
            }
        }
    }

    func addItem() {
        let trimmed = newText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(ChecklistItem(id: UUID().uuidString, text: trimmed, completed: false, kanban_card_id: nil))
        newText = ""
        saveItems()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.text3)
                Text("AUFGABEN")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(T.text3)
                Spacer()
                Text("\(completed)/\(total)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(T.text2)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 4)
                    Rectangle()
                        .fill(T.success)
                        .frame(width: max(0, geo.size.width * CGFloat(pct)), height: 4)
                }
            }
            .frame(height: 4)

            VStack(spacing: 4) {
                ForEach($items) { $item in
                    HStack(spacing: 8) {
                        Button {
                            item.completed.toggle()
                            saveItems()
                        } label: {
                            Image(systemName: item.completed ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14))
                                .foregroundStyle(item.completed ? T.success : T.text3)
                        }.buttonStyle(.plain)

                        TextField("", text: $item.text, onCommit: { saveItems() })
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(item.completed ? T.text3 : T.text1)
                            .strikethrough(item.completed, color: T.text3)

                        if item.kanban_card_id != nil {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 9))
                                .foregroundStyle(T.text3)
                        }

                        Button {
                            items.removeAll { $0.id == item.id }
                            saveItems()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(T.text3)
                                .frame(width: 20, height: 20)
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.03))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(T.text3)
                TextField("Aufgabe hinzufügen…", text: $newText, onCommit: addItem)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color.white.opacity(0.04))
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
    }
}

// ============================================================
// MARK: - AttachmentsSection
// ============================================================

struct AttachmentsSection: View {
    let detail: AppointmentDetail
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @State private var dropTargeted: Bool = false
    @State private var uploading: Bool = false

    var attachments: [AppointmentAttachment] {
        appointmentsStore.selectedDetail?.attachments ?? detail.attachments
    }

    func formatBytes(_ b: Int) -> String {
        if b >= 1_000_000 { return String(format: "%.1f MB", Double(b) / 1_000_000.0) }
        if b >= 1_000 { return String(format: "%.0f KB", Double(b) / 1_000.0) }
        return "\(b) B"
    }

    func iconFor(_ type: String) -> String {
        switch type.lowercased() {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx", "csv": return "tablecells"
        case "ppt", "pptx": return "rectangle.on.rectangle"
        case "zip": return "archivebox"
        case "txt", "rtf": return "doc.plaintext"
        default: return "doc"
        }
    }

    func pickAndUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            for url in panel.urls { upload(url: url) }
        }
    }

    func upload(url: URL) {
        uploading = true
        Task {
            if let new = try? await appointmentsStore.api.uploadAttachment(eventId: detail.event_id, fileURL: url) {
                appointmentsStore.addAttachment(new)
            }
            uploading = false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.text3)
                Text("DATEIEN")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(T.text3)
                Spacer()
                if uploading { ProgressView().controlSize(.mini).tint(T.text2) }
                Button(action: pickAndUpload) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Hochladen")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
            }

            VStack(spacing: 4) {
                ForEach(attachments) { att in
                    AttachmentRow(attachment: att, iconName: iconFor(att.file_type), sizeLabel: formatBytes(att.file_size)) {
                        Task { await appointmentsStore.removeAttachment(att.id) }
                    }
                }
                if attachments.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(T.text3)
                        Text("Datei hierher ziehen oder Hochladen klicken")
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(dropTargeted ? 0.06 : 0.02))
            .overlay(
                Rectangle()
                    .strokeBorder(
                        dropTargeted ? T.accent : T.line,
                        style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                    )
            )
            .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                for p in providers {
                    _ = p.loadObject(ofClass: URL.self) { url, _ in
                        if let u = url {
                            DispatchQueue.main.async { upload(url: u) }
                        }
                    }
                }
                return true
            }
        }
    }
}

struct AttachmentRow: View {
    let attachment: AppointmentAttachment
    let iconName: String
    let sizeLabel: String
    let onDelete: () -> Void
    @State private var hover = false

    var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "svg"].contains(attachment.file_type.lowercased())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inline image preview for image types
            if isImage, let url = T.absoluteURL(attachment.file_url) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                            .frame(maxHeight: 120)
                            .frame(maxWidth: .infinity)
                    default:
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .light))
                            .foregroundStyle(T.text3)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                    }
                }
                .background(Color.black.opacity(0.2))
            }

            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(T.accent)
                    .frame(width: 28, height: 28)
                    .background(T.accentSoft)
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(T.text1)
                        .lineLimit(1)
                    Text("\(attachment.file_type.uppercased()) · \(sizeLabel)")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                }
                Spacer()
                if hover {
                    Button {
                        if let u = T.absoluteURL(attachment.file_url) { NSWorkspace.shared.open(u) }
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                            .frame(width: 22, height: 22)
                    }.buttonStyle(.plain)
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 22, height: 22)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .background(hover ? T.cardHover : T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
        .onTapGesture {
            if let u = T.absoluteURL(attachment.file_url) { NSWorkspace.shared.open(u) }
        }
    }
}

// ============================================================
// MARK: - TerminDetailBody (layout modes)
// ============================================================

struct TerminDetailBody: View {
    let detail: AppointmentDetail
    @Binding var layoutMode: LayoutMode
    @State private var activeTab: DetailSection = .notes
    @State private var leftPick: DetailSection = .notes
    @State private var rightPick: DetailSection = .tasks
    @EnvironmentObject var appointmentsStore: AppointmentsStore

    @ViewBuilder
    func sectionView(_ s: DetailSection) -> some View {
        switch s {
        case .notes:
            DebouncedTextSection(
                title: "Notizen",
                icon: "pencil.and.outline",
                placeholder: "Notizen aus dem Termin…",
                initialText: detail.notes,
                onSave: { newText in
                    Task { _ = await appointmentsStore.update(detail.event_id, ["notes": newText]) }
                }
            )
        case .tasks:
            ChecklistSection(detail: detail)
        case .files:
            AttachmentsSection(detail: detail)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                LayoutModeSwitcher(mode: $layoutMode)
                Spacer()
            }
            .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)

            ScrollView {
                Group {
                    switch layoutMode {
                    case .tabs:
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 6) {
                                ForEach(DetailSection.allCases) { s in
                                    Button { activeTab = s } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: s.icon)
                                                .font(.system(size: 10, weight: .semibold))
                                            Text(s.label)
                                                .font(.system(size: 11, weight: .semibold))
                                        }
                                        .foregroundStyle(activeTab == s ? T.text1 : T.text2)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(activeTab == s ? T.accentSoft : Color.white.opacity(0.03))
                                        .overlay(Rectangle().stroke(activeTab == s ? T.accent.opacity(0.55) : T.line, lineWidth: 0.5))
                                    }.buttonStyle(.plain)
                                }
                                Spacer()
                            }
                            sectionView(activeTab)
                        }
                    case .split:
                        HStack(alignment: .top, spacing: 14) {
                            sectionView(.notes)
                                .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 14) {
                                sectionView(.tasks)
                                sectionView(.files)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    case .segmented:
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 6) {
                                Picker("Links", selection: $leftPick) {
                                    ForEach(DetailSection.allCases) { Text($0.label).tag($0) }
                                }
                                .labelsHidden()
                                .frame(width: 140)
                                Text("|").foregroundStyle(T.text3)
                                Picker("Rechts", selection: $rightPick) {
                                    ForEach(DetailSection.allCases) { Text($0.label).tag($0) }
                                }
                                .labelsHidden()
                                .frame(width: 140)
                                Spacer()
                            }
                            HStack(alignment: .top, spacing: 14) {
                                sectionView(leftPick).frame(maxWidth: .infinity)
                                sectionView(rightPick).frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }
}

// ============================================================
// MARK: - Special Days Panel
// ============================================================

let specialDayColorOptions = ["red","orange","yellow","green","blue","purple","pink","cyan","teal","indigo"]

struct SpecialDaysPanel: View {
    let onClose: () -> Void
    @EnvironmentObject var typesStore: SpecialDayTypesStore
    @EnvironmentObject var daysStore: SpecialDaysStore
    @State private var tab: Tab = .types
    enum Tab { case types, days }

    @State private var newTypeName: String = ""
    @State private var newTypeColor: String = "blue"
    @State private var newDayDate: Date = Date()
    @State private var newDayTypeId: Int? = nil
    @State private var newDayNote: String = ""
    @State private var editingType: SpecialDayType? = nil

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 12))
                    .foregroundStyle(T.accent)
                Text("Spezial-Tage")
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
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 8)

            HStack(spacing: 6) {
                tabButton("Tag-Typen", active: tab == .types) { tab = .types }
                tabButton("Markierte Tage", active: tab == .days) { tab = .days }
            }
            .padding(.horizontal, 18).padding(.bottom, 10)

            Divider().background(T.line)

            ScrollView {
                Group {
                    if tab == .types {
                        typesView
                    } else {
                        daysView
                    }
                }
                .padding(18)
            }
            .frame(width: 540, height: 460)

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
        .frame(width: 540)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }

    func tabButton(_ label: String, active: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? T.text1 : T.text2)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(active ? T.accentSoft : Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(active ? T.accent.opacity(0.55) : Color.clear, lineWidth: 1))
        }.buttonStyle(.plain)
    }

    var typesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(typesStore.types) { type in
                HStack(spacing: 10) {
                    Circle()
                        .fill(T.specialDayColor(type.color))
                        .frame(width: 14, height: 14)
                    Text(type.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(T.text1)
                    Spacer()
                    Button {
                        editingType = type
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                    Button {
                        Task { await typesStore.delete(type.id) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 22, height: 22)
                            .background(Color.red.opacity(0.08))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(T.card)
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            }

            Text("NEUER TYP")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(T.text3)
                .padding(.top, 8)
            HStack(spacing: 8) {
                TextField("Name", text: $newTypeName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                Menu {
                    ForEach(specialDayColorOptions, id: \.self) { c in
                        Button(c.capitalized) { newTypeColor = c }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(T.specialDayColor(newTypeColor)).frame(width: 12, height: 12)
                        Text(newTypeColor.capitalized).font(.system(size: 11)).foregroundStyle(T.text2)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton).fixedSize()
                Button {
                    Task {
                        await typesStore.create(["name": newTypeName, "color": newTypeColor])
                        newTypeName = ""
                    }
                } label: {
                    Text("Hinzufügen")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(T.accent)
                }.buttonStyle(.plain)
                .disabled(newTypeName.isEmpty)
            }
        }
    }

    var daysView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Add new
            Text("TAG MARKIEREN")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(T.text3)
            HStack(spacing: 8) {
                DatePicker("", selection: $newDayDate, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .labelsHidden()
                Menu {
                    ForEach(typesStore.types) { t in
                        Button {
                            newDayTypeId = t.id
                        } label: {
                            HStack { Circle().fill(T.specialDayColor(t.color)).frame(width: 8, height: 8); Text(t.name) }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let id = newDayTypeId, let t = typesStore.types.first(where: { $0.id == id }) {
                            Circle().fill(T.specialDayColor(t.color)).frame(width: 12, height: 12)
                            Text(t.name).font(.system(size: 11)).foregroundStyle(T.text1)
                        } else {
                            Text("Typ wählen…").font(.system(size: 11)).foregroundStyle(T.text3)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton).fixedSize()
                TextField("Notiz (optional)", text: $newDayNote)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                Button {
                    if let id = newDayTypeId {
                        Task {
                            await daysStore.mark(date: newDayDate, typeId: id, note: newDayNote, overwrite: true)
                            newDayNote = ""
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(T.accent)
                }.buttonStyle(.plain)
                .disabled(newDayTypeId == nil)
            }

            Divider().background(T.line).padding(.vertical, 8)

            ForEach(daysStore.days.sorted { $0.date > $1.date }) { day in
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(T.specialDayColor(day.special_day_type.color))
                        .frame(width: 4)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(day.date)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(T.text1)
                            Text(day.special_day_type.name)
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                        }
                        if !day.note.isEmpty {
                            Text(day.note)
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                    }
                    Spacer()
                    Button {
                        Task { await daysStore.delete(day.id) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 22, height: 22)
                    }.buttonStyle(.plain)
                }
                .frame(height: 36)
                .background(T.card)
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            }
        }
    }
}

// ============================================================
// MARK: - QuickMarkingDialog
// ============================================================

struct QuickMarkingDialog: View {
    let from: Date
    let to: Date
    let onClose: () -> Void
    @EnvironmentObject var typesStore: SpecialDayTypesStore
    @EnvironmentObject var daysStore: SpecialDaysStore
    @State private var typeId: Int? = nil
    @State private var note: String = ""
    @State private var overwrite: Bool = true

    var dayCount: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: cal.startOfDay(for: from), to: cal.startOfDay(for: to))
        return (comps.day ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)
            HStack {
                Text("Tage markieren")
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

            VStack(alignment: .leading, spacing: 14) {
                Text("\(dayCount) Tag\(dayCount == 1 ? "" : "e") · \(T.mediumDate(from)) – \(T.mediumDate(to))")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text2)

                Text("TYP")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(T.text3)
                VStack(spacing: 4) {
                    ForEach(typesStore.types) { t in
                        Button { typeId = t.id } label: {
                            HStack(spacing: 8) {
                                Circle().fill(T.specialDayColor(t.color)).frame(width: 12, height: 12)
                                Text(t.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(typeId == t.id ? T.text1 : T.text2)
                                Spacer()
                                if typeId == t.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(T.accent)
                                }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(typeId == t.id ? T.accentSoft : Color.white.opacity(0.04))
                            .overlay(Rectangle().stroke(typeId == t.id ? T.accent.opacity(0.55) : T.line, lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
                }

                Text("NOTIZ")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(T.text3)
                TextField("Optional", text: $note)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                Button { overwrite.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: overwrite ? "checkmark.square.fill" : "square")
                            .font(.system(size: 13))
                            .foregroundStyle(overwrite ? T.accent : T.text3)
                        Text("Bestehende Markierungen überschreiben")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text2)
                    }
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

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
                    if let id = typeId {
                        Task {
                            await daysStore.markRange(from: from, to: to, typeId: id, note: note, overwrite: overwrite)
                            onClose()
                        }
                    }
                } label: {
                    Text("Markieren")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(T.accent)
                }
                .buttonStyle(.plain)
                .disabled(typeId == nil)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 420)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }
}

// ============================================================
// MARK: - Main view
// ============================================================

struct MainView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var appointmentsStore: AppointmentsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @EnvironmentObject var specialDayTypesStore: SpecialDayTypesStore
    @EnvironmentObject var specialDaysStore: SpecialDaysStore
    @State private var showLogout = false
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date = Date()
    @State private var selectedEventId: Int? = nil
    @State private var creatingNew: Bool = false
    @State private var showSpecialDays: Bool = false
    @State private var quickMarkRange: (Date, Date)? = nil
    @AppStorage("termine.layoutMode") private var layoutModeRaw: String = LayoutMode.tabs.rawValue
    private var layoutModeBinding: Binding<LayoutMode> {
        Binding(
            get: { LayoutMode(rawValue: layoutModeRaw) ?? .tabs },
            set: { layoutModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopBar(
                    showLogout: $showLogout,
                    onNew: { creatingNew = true },
                    onSpecialDays: { showSpecialDays = true },
                    onReload: { Task { await reload() } }
                )

                HStack(alignment: .top, spacing: 0) {
                    // Sidebar (scrollable)
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            MiniCalendar(
                                month: $currentMonth,
                                selectedDate: $selectedDate,
                                onDragRange: { from, to in quickMarkRange = (from, to) }
                            )
                            Rectangle().fill(T.line).frame(height: 1)
                            DayEventsList(selectedDate: $selectedDate, selectedEventId: $selectedEventId)
                        }
                        .padding(14)
                    }
                    .frame(width: 300)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
                    .background(T.bg.opacity(0.4))
                    .overlay(
                        Rectangle().frame(width: 1).foregroundStyle(T.line),
                        alignment: .trailing
                    )

                    // Detail pane
                    if let detail = appointmentsStore.selectedDetail {
                        VStack(spacing: 0) {
                            TerminDetailHeader(detail: detail)
                                .id("header-\(detail.event_id)")
                            TerminDetailBody(detail: detail, layoutMode: layoutModeBinding)
                                .id("body-\(detail.event_id)")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 36, weight: .light))
                                .foregroundStyle(T.text3)
                            Text("Wähle einen Termin")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(T.text2)
                            Text("Klicke links auf einen Tag und wähle einen Termin aus")
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }

            if creatingNew {
                modalOverlay(onClose: { creatingNew = false }) {
                    CreateTerminModal(
                        initialDate: selectedDate,
                        onClose: { creatingNew = false },
                        onCreated: { new in
                            selectedEventId = new.event_id
                            selectedDate = T.dateFrom(new.event.date) ?? selectedDate
                        }
                    )
                }
            }

            if showSpecialDays {
                modalOverlay(onClose: { showSpecialDays = false }) {
                    SpecialDaysPanel(onClose: { showSpecialDays = false })
                }
            }

            if let range = quickMarkRange {
                modalOverlay(onClose: { quickMarkRange = nil }) {
                    QuickMarkingDialog(
                        from: range.0,
                        to: range.1,
                        onClose: { quickMarkRange = nil }
                    )
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: creatingNew)
        .animation(.easeOut(duration: 0.15), value: showSpecialDays)
        .animation(.easeOut(duration: 0.15), value: quickMarkRange?.0)
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
        async let a: () = appointmentsStore.reload(month: currentMonth)
        async let c: () = clientsStore.reload()
        async let st: () = specialDayTypesStore.reload()
        async let sd: () = specialDaysStore.reload()
        _ = await (a, c, st, sd)
    }
}

// ============================================================
// MARK: - Root
// ============================================================

struct RootView: View {
    @StateObject private var authStore: AuthStore
    @StateObject private var appointmentsStore: AppointmentsStore
    @StateObject private var clientsStore: ClientsStore
    @StateObject private var specialDayTypesStore: SpecialDayTypesStore
    @StateObject private var specialDaysStore: SpecialDaysStore
    private let api: API

    init() {
        let auth = AuthStore()
        let api = API(auth)
        _authStore = StateObject(wrappedValue: auth)
        _appointmentsStore = StateObject(wrappedValue: AppointmentsStore(api: api))
        _clientsStore = StateObject(wrappedValue: ClientsStore(api: api))
        _specialDayTypesStore = StateObject(wrappedValue: SpecialDayTypesStore(api: api))
        _specialDaysStore = StateObject(wrappedValue: SpecialDaysStore(api: api))
        self.api = api
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
                .background(TransparentWindow())
            if authStore.isLoggedIn {
                MainView()
                    .environmentObject(authStore)
                    .environmentObject(appointmentsStore)
                    .environmentObject(clientsStore)
                    .environmentObject(specialDayTypesStore)
                    .environmentObject(specialDaysStore)
                    .task {
                        await api.refreshIfPossible()
                        async let a: () = appointmentsStore.reload(month: Date())
                        async let c: () = clientsStore.reload()
                        async let st: () = specialDayTypesStore.reload()
                        async let sd: () = specialDaysStore.reload()
                        _ = await (a, c, st, sd)
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
struct TermineMacApp: App {
    init() { URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000) }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
    }
}
