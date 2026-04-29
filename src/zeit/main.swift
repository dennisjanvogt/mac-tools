// Zeit — Native SwiftUI client for ConsultingOS Zeiterfassung
// Auth: device-code → JWT (refresh-token = 30 days)
// Backend: https://1o618.com

import SwiftUI
import AppKit
import Security

// ============================================================
// MARK: - Config
// ============================================================

enum Config {
    static let apiBase = "https://1o618.com"
    static let authPath = NSHomeDirectory() + "/.config/zeit/auth.json"
    static let deviceName = "macOS Zeit"
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

    static func snapMinutes(_ m: Int, to step: Int = 15) -> Int {
        return (m / step) * step
    }

    static func mondayOf(_ d: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return cal.date(from: comps) ?? d
    }

    static func weekDates(of d: Date) -> [Date] {
        let monday = mondayOf(d)
        let cal = Calendar.current
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
    }

    static func calendarWeek(of d: Date) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.minimumDaysInFirstWeek = 4
        return cal.component(.weekOfYear, from: d)
    }

    static func weekdayShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EE"
        return f.string(from: d)
    }

    static func dayMonthShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "d. MMM"
        return f.string(from: d)
    }

    static func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 && m == 0 { return "0 h" }
        if m == 0 { return "\(h) h" }
        return String(format: "%d:%02d h", h, m)
    }

    // Project color palette (mirrors PROJECT_COLORS in utils.ts)
    static func projectHex(_ name: String) -> String {
        switch name {
        case "gray":   return "#64748b"
        case "blue":   return "#7c99b5"
        case "green":  return "#6d9e8a"
        case "yellow": return "#c4a66a"
        case "red":    return "#c08b8b"
        case "purple": return "#9b8ec4"
        case "violet": return "#9b8ec4"
        case "pink":   return "#b08da0"
        case "orange": return "#818cf8"
        default:       return "#7c99b5"
        }
    }

    // Adaptive entry colors (mirrors getEntryColors in utils.ts, dark mode)
    static func entryColors(hex rawHex: String) -> (bg: Color, accent: Color, text: Color, secondary: Color) {
        var s = rawHex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count != 6 { s = "7c99b5" }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        var r = Double((rgb >> 16) & 0xFF)
        var g = Double((rgb >> 8) & 0xFF)
        var b = Double(rgb & 0xFF)
        let brightness = (r * 0.299 + g * 0.587 + b * 0.114)
        if brightness < 80 {
            let boost = 80.0 / max(brightness, 1)
            r = min(255, r * boost)
            g = min(255, g * boost)
            b = min(255, b * boost)
        }
        let bgColor = Color(.sRGB, red: r/255, green: g/255, blue: b/255, opacity: 0.30)
        let accentColor = Color(.sRGB, red: r/255, green: g/255, blue: b/255, opacity: 0.95)
        let textColor = Color(.sRGB, red: min(1, r/255 + 0.35), green: min(1, g/255 + 0.35), blue: min(1, b/255 + 0.35), opacity: 1.0)
        let secondary = textColor.opacity(0.75)
        return (bgColor, accentColor, textColor, secondary)
    }
}

// ============================================================
// MARK: - Grid constants
// ============================================================

enum Grid {
    static let startHour: Int = 6
    static let endHour: Int = 23
    static let pxPerMinute: CGFloat = 1.28
    static let snapMinutes: Int = 15
    static var totalHours: Int { endHour - startHour }
    static var totalHeight: CGFloat { CGFloat(totalHours * 60) * pxPerMinute }
    static let timeAxisWidth: CGFloat = 60
}

func overlapLayout(_ entries: [TimeEntry]) -> [Int: (col: Int, totalCols: Int)] {
    let sorted = entries.sorted { a, b in
        if a.start_time == b.start_time { return a.duration_minutes > b.duration_minutes }
        return a.start_time < b.start_time
    }
    func startMin(_ e: TimeEntry) -> Int { T.minutesFromTimeString(e.start_time) }
    func endMin(_ e: TimeEntry) -> Int { startMin(e) + e.duration_minutes }

    var columns: [[TimeEntry]] = []
    var assignment: [Int: Int] = [:]
    for entry in sorted {
        let s = startMin(entry)
        var placed = false
        for i in 0..<columns.count {
            if let last = columns[i].last, endMin(last) > s { continue }
            columns[i].append(entry)
            assignment[entry.id] = i
            placed = true
            break
        }
        if !placed {
            columns.append([entry])
            assignment[entry.id] = columns.count - 1
        }
    }
    var result: [Int: (col: Int, totalCols: Int)] = [:]
    for entry in sorted {
        let s = startMin(entry)
        let e = endMin(entry)
        var maxCols = 1
        for other in sorted {
            let os = startMin(other)
            let oe = endMin(other)
            if os < e && oe > s {
                maxCols = max(maxCols, (assignment[other.id] ?? 0) + 1)
            }
        }
        result[entry.id] = (col: assignment[entry.id] ?? 0, totalCols: maxCols)
    }
    return result
}

// ============================================================
// MARK: - Models
// ============================================================

struct AuthData: Codable {
    var access_token: String
    var refresh_token: String
    var username: String?
}

struct TimeEntry: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var project: Int?
    var project_name: String?
    var client_name: String?
    var date: String           // YYYY-MM-DD
    var start_time: String     // HH:MM
    var end_time: String       // HH:MM
    var duration_minutes: Int
    var description: String
    var billable: Bool
    var activity_type: String
    var created_at: String
}

struct ActiveTimer: Codable, Equatable {
    var project_id: Int?
    var project_name: String?
    var description: String
    var start_time: Int?       // unix ms
    var paused_time: Int       // ms
    var is_running: Bool
    var is_paused: Bool
}

struct Summary: Codable {
    var total_hours: Double
    var total_revenue: Double
    var entries_count: Int
    var by_project: [SummaryProject]
    var by_client: [SummaryClient]
}

struct SummaryProject: Codable, Identifiable, Hashable {
    var project_id: Int
    var project_name: String
    var hours: Double
    var revenue: Double
    var id: Int { project_id }
}

struct SummaryClient: Codable, Identifiable, Hashable {
    var client_id: Int
    var client_name: String
    var hours: Double
    var id: Int { client_id }
}

struct DayNote: Codable, Identifiable, Hashable {
    let id: Int
    let date: String
    var text: String
    var updated_at: String
}

struct TTClient: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var company: String
    var email: String
    var phone: String
    var website: String
    var address: String
    var zip_code: String
    var city: String
    var country: String
    var tax_id: String
    var notes: String
    var logo_url: String?
    var primary_color: String
    var secondary_color: String
    var created_at: String
}

struct TTProject: Codable, Identifiable, Hashable {
    let id: Int
    let client: Int
    var client_name: String
    var name: String
    var description: String
    var hourly_rate: Double
    var default_billable: Bool
    var color: String
    var status: String
    var client_primary_color: String
    var client_secondary_color: String
    var created_at: String
}

// ============================================================
// MARK: - AuthStore
// ============================================================

// Shared keychain auth across all ConsultingOS Mac apps (Kanban, Zeit, Termine).
// Keychain item: service "com.dennis.consultingos", account "default".
// Migrates legacy per-app file tokens on first run.
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
        if http.statusCode == 401, retryOn401, let r = auth.auth?.refresh_token {
            if try await refreshAccessToken(r) {
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

    // Clients
    func listClients() async throws -> [TTClient] {
        let data = try await request("GET", "/api/timetracking/clients/")
        return (try? JSONDecoder().decode([TTClient].self, from: data)) ?? []
    }

    func createClient(_ data: [String: Any]) async throws -> TTClient? {
        let resp = try await request("POST", "/api/timetracking/clients/", body: data)
        return try? JSONDecoder().decode(TTClient.self, from: resp)
    }

    func updateClient(_ id: Int, _ data: [String: Any]) async throws -> TTClient? {
        let resp = try await request("PUT", "/api/timetracking/clients/\(id)", body: data)
        return try? JSONDecoder().decode(TTClient.self, from: resp)
    }

    func deleteClient(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/timetracking/clients/\(id)")
    }

    func uploadClientLogo(_ id: Int, fileURL: URL) async throws -> TTClient? {
        let data = try await uploadMultipart("/api/timetracking/clients/\(id)/logo", fileURL: fileURL)
        return try? JSONDecoder().decode(TTClient.self, from: data)
    }

    func deleteClientLogo(_ id: Int) async throws -> TTClient? {
        let data = try await request("DELETE", "/api/timetracking/clients/\(id)/logo")
        return try? JSONDecoder().decode(TTClient.self, from: data)
    }

    // Projects
    func listProjects(status: String? = nil) async throws -> [TTProject] {
        var path = "/api/timetracking/projects/"
        if let s = status { path += "?status=\(s)" }
        let data = try await request("GET", path)
        return (try? JSONDecoder().decode([TTProject].self, from: data)) ?? []
    }

    func createProject(_ data: [String: Any]) async throws -> TTProject? {
        let resp = try await request("POST", "/api/timetracking/projects/", body: data)
        return try? JSONDecoder().decode(TTProject.self, from: resp)
    }

    func updateProject(_ id: Int, _ data: [String: Any]) async throws -> TTProject? {
        let resp = try await request("PUT", "/api/timetracking/projects/\(id)", body: data)
        return try? JSONDecoder().decode(TTProject.self, from: resp)
    }

    func deleteProject(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/timetracking/projects/\(id)")
    }

    // Entries
    func listEntries(dateFrom: String, dateTo: String) async throws -> [TimeEntry] {
        let path = "/api/timetracking/entries/?date_from=\(dateFrom)&date_to=\(dateTo)"
        let data = try await request("GET", path)
        return (try? JSONDecoder().decode([TimeEntry].self, from: data)) ?? []
    }

    func createEntry(_ data: [String: Any]) async throws -> TimeEntry? {
        let resp = try await request("POST", "/api/timetracking/entries/", body: data)
        return try? JSONDecoder().decode(TimeEntry.self, from: resp)
    }

    func updateEntry(_ id: Int, _ data: [String: Any]) async throws -> TimeEntry? {
        let resp = try await request("PUT", "/api/timetracking/entries/\(id)", body: data)
        return try? JSONDecoder().decode(TimeEntry.self, from: resp)
    }

    func deleteEntry(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/timetracking/entries/\(id)")
    }

    // Timer
    func getTimer() async throws -> ActiveTimer? {
        let data = try await request("GET", "/api/timetracking/timer/")
        return try? JSONDecoder().decode(ActiveTimer.self, from: data)
    }

    func putTimer(_ data: [String: Any]) async throws -> ActiveTimer? {
        let resp = try await request("PUT", "/api/timetracking/timer/", body: data)
        return try? JSONDecoder().decode(ActiveTimer.self, from: resp)
    }

    func deleteTimer() async throws {
        _ = try await request("DELETE", "/api/timetracking/timer/")
    }

    // Summary
    func getSummary(dateFrom: String, dateTo: String) async throws -> Summary? {
        let path = "/api/timetracking/summary/?date_from=\(dateFrom)&date_to=\(dateTo)"
        let data = try await request("GET", path)
        return try? JSONDecoder().decode(Summary.self, from: data)
    }

    // Day Notes
    func getDayNote(_ date: String) async throws -> DayNote? {
        do {
            let data = try await request("GET", "/api/timetracking/day-notes/\(date)")
            return try? JSONDecoder().decode(DayNote.self, from: data)
        } catch APIError.http(404) {
            return nil
        }
    }

    func putDayNote(_ date: String, text: String) async throws -> DayNote? {
        let resp = try await request("PUT", "/api/timetracking/day-notes/\(date)", body: ["text": text])
        return try? JSONDecoder().decode(DayNote.self, from: resp)
    }
}

// ============================================================
// MARK: - Stores
// ============================================================

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

    func create(_ data: [String: Any]) async -> TTClient? {
        guard let new = try? await api.createClient(data) else { return nil }
        withAnimation { clients.append(new) }
        return new
    }

    func update(_ id: Int, _ data: [String: Any]) async -> TTClient? {
        guard let updated = try? await api.updateClient(id, data) else { return nil }
        if let i = clients.firstIndex(where: { $0.id == id }) {
            withAnimation { clients[i] = updated }
        }
        return updated
    }

    func delete(_ id: Int) async {
        try? await api.deleteClient(id)
        withAnimation { clients.removeAll { $0.id == id } }
    }

    func uploadLogo(_ id: Int, fileURL: URL) async -> TTClient? {
        guard let updated = try? await api.uploadClientLogo(id, fileURL: fileURL) else { return nil }
        if let i = clients.firstIndex(where: { $0.id == id }) {
            withAnimation { clients[i] = updated }
        }
        return updated
    }

    func removeLogo(_ id: Int) async -> TTClient? {
        guard let updated = try? await api.deleteClientLogo(id) else { return nil }
        if let i = clients.firstIndex(where: { $0.id == id }) {
            withAnimation { clients[i] = updated }
        }
        return updated
    }
}

@MainActor
final class ProjectsStore: ObservableObject {
    @Published var projects: [TTProject] = []
    let api: API
    init(api: API) { self.api = api }

    func reload() async {
        if let ps = try? await api.listProjects() { projects = ps }
    }

    func project(id: Int?) -> TTProject? {
        guard let id = id else { return nil }
        return projects.first { $0.id == id }
    }

    func grouped(clients: [TTClient], includeArchived: Bool = false) -> [(client: TTClient, projects: [TTProject])] {
        let filtered = projects.filter { includeArchived || $0.status == "active" }
        var byClient: [Int: [TTProject]] = [:]
        for p in filtered { byClient[p.client, default: []].append(p) }
        return clients
            .compactMap { c in
                guard let ps = byClient[c.id], !ps.isEmpty else { return nil }
                return (client: c, projects: ps.sorted { $0.name < $1.name })
            }
            .sorted { $0.client.name < $1.client.name }
    }

    func create(_ data: [String: Any]) async -> TTProject? {
        guard let new = try? await api.createProject(data) else { return nil }
        withAnimation { projects.append(new) }
        return new
    }

    func update(_ id: Int, _ data: [String: Any]) async -> TTProject? {
        guard let updated = try? await api.updateProject(id, data) else { return nil }
        if let i = projects.firstIndex(where: { $0.id == id }) {
            withAnimation { projects[i] = updated }
        }
        return updated
    }

    func delete(_ id: Int) async {
        try? await api.deleteProject(id)
        withAnimation { projects.removeAll { $0.id == id } }
    }
}

@MainActor
final class EntriesStore: ObservableObject {
    @Published var entries: [TimeEntry] = []
    @Published var loading: Bool = false
    @Published var lastError: String? = nil
    let api: API
    init(api: API) { self.api = api }

    func reload(from: String, to: String) async {
        loading = true
        if let e = try? await api.listEntries(dateFrom: from, dateTo: to) {
            withAnimation(.easeInOut(duration: 0.2)) { entries = e }
        }
        loading = false
    }

    func entries(on date: String) -> [TimeEntry] {
        entries.filter { $0.date == date }.sorted { $0.start_time < $1.start_time }
    }

    func create(_ data: [String: Any]) async -> TimeEntry? {
        do {
            guard let new = try await api.createEntry(data) else {
                lastError = "Eintrag konnte nicht erstellt werden"
                return nil
            }
            lastError = nil
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                entries.append(new)
            }
            return new
        } catch {
            lastError = "Fehler beim Erstellen: Verbindung fehlgeschlagen"
            return nil
        }
    }

    func update(_ id: Int, _ data: [String: Any]) async -> TimeEntry? {
        do {
            guard let updated = try await api.updateEntry(id, data) else {
                lastError = "Eintrag konnte nicht aktualisiert werden"
                return nil
            }
            lastError = nil
            if let i = entries.firstIndex(where: { $0.id == id }) {
                withAnimation(.easeInOut(duration: 0.2)) { entries[i] = updated }
            }
            return updated
        } catch {
            lastError = "Fehler beim Speichern: Verbindung fehlgeschlagen"
            return nil
        }
    }

    func delete(_ id: Int) async {
        do {
            try await api.deleteEntry(id)
            lastError = nil
            withAnimation(.easeOut(duration: 0.2)) {
                entries.removeAll { $0.id == id }
            }
        } catch {
            lastError = "Fehler beim Löschen"
        }
    }
}

final class SummaryStore: ObservableObject {
    @Published var summary: Summary?
    let api: API
    init(api: API) { self.api = api }

    func reload(from: String, to: String) async {
        if let s = try? await api.getSummary(dateFrom: from, dateTo: to) { summary = s }
    }
}

@MainActor
final class DayNotesStore: ObservableObject {
    @Published var notes: [String: String] = [:]   // date -> text
    let api: API
    init(api: API) { self.api = api }

    func load(date: String) async {
        if let n = try? await api.getDayNote(date) {
            notes[date] = n.text
        } else {
            notes[date] = ""
        }
    }

    func save(date: String, text: String) async {
        notes[date] = text
        _ = try? await api.putDayNote(date, text: text)
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

            Image(systemName: "clock.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(T.accent)

            VStack(spacing: 4) {
                Text("Zeit")
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

            Text("Token bleibt 30 Tage gültig")
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
            } catch {
                // continue polling
            }
        }
    }
}

// ============================================================
// MARK: - Top Bar
// ============================================================

enum AppTab: String, CaseIterable {
    case entries, projects, clients, reports

    var label: String {
        switch self {
        case .entries: return "Einträge"
        case .projects: return "Projekte"
        case .clients: return "Kunden"
        case .reports: return "Reports"
        }
    }

    var icon: String {
        switch self {
        case .entries: return "calendar"
        case .projects: return "folder.fill"
        case .clients: return "person.2.fill"
        case .reports: return "chart.bar.fill"
        }
    }
}

struct TabButton: View {
    let tab: AppTab
    let active: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(tab.label)
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(active ? T.text1 : T.text2)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(active ? T.accentSoft : Color.white.opacity(0.025))
            .overlay(
                Rectangle()
                    .stroke(active ? T.accent.opacity(0.55) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct TopBar: View {
    @Binding var activeTab: AppTab
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var entriesStore: EntriesStore
    @Binding var showLogout: Bool
    let onReload: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 8) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    TabButton(tab: tab, active: activeTab == tab) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            activeTab = tab
                        }
                    }
                }
            }

            HStack(spacing: 8) {
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
        }
        .padding(.horizontal, 14)
        .padding(.top, 12).padding(.bottom, 10)
        .background(WindowDragArea())
    }
}

// ============================================================
// MARK: - Projects tab
// ============================================================

struct ProjectsTab: View {
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var statusFilter: String = "active"  // "all", "active", "archived"
    @State private var editingProject: TTProject? = nil
    @State private var creatingNew: Bool = false

    var filteredGroups: [(client: TTClient, projects: [TTProject])] {
        let include = statusFilter == "all" || statusFilter == "archived"
        var result: [(client: TTClient, projects: [TTProject])] = []
        var byClient: [Int: [TTProject]] = [:]
        let filtered = projectsStore.projects.filter {
            switch statusFilter {
            case "active": return $0.status == "active"
            case "archived": return $0.status == "archived"
            default: return true
            }
        }
        _ = include
        for p in filtered { byClient[p.client, default: []].append(p) }
        for client in clientsStore.clients.sorted(by: { $0.name < $1.name }) {
            if let ps = byClient[client.id], !ps.isEmpty {
                result.append((client: client, projects: ps.sorted { $0.name < $1.name }))
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Sub-header
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach([("active", "Aktiv"), ("archived", "Archiviert"), ("all", "Alle")], id: \.0) { id, label in
                            Button { statusFilter = id } label: {
                                Text(label)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(statusFilter == id ? T.text1 : T.text2)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(statusFilter == id ? T.accentSoft : Color.white.opacity(0.04))
                                    .overlay(Rectangle().stroke(statusFilter == id ? T.accent.opacity(0.55) : Color.clear, lineWidth: 1))
                            }.buttonStyle(.plain)
                        }
                    }
                    Spacer()
                    Button { creatingNew = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                            Text("Neues Projekt").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

                // List
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        if filteredGroups.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "folder")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(T.text3)
                                Text("Keine Projekte")
                                    .font(.system(size: 12))
                                    .foregroundStyle(T.text3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }
                        ForEach(filteredGroups, id: \.client.id) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    if let url = T.absoluteURL(group.client.logo_url) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable().scaledToFit()
                                            default: Text(String(group.client.name.prefix(1)))
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .frame(width: 24, height: 24)
                                        .background(Color.white)
                                    } else {
                                        Text(String(group.client.name.prefix(1)).uppercased())
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 24, height: 24)
                                            .background(T.hexColor(group.client.primary_color) ?? T.accent)
                                    }
                                    Text(group.client.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(T.text1)
                                    Text("\(group.projects.count)")
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(T.text3)
                                    Spacer()
                                }
                                ForEach(group.projects) { project in
                                    ProjectRowItem(
                                        project: project,
                                        client: group.client,
                                        onEdit: { editingProject = project }
                                    )
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                        Color.clear.frame(height: 30)
                    }
                    .padding(.top, 14)
                }
            }

            if let project = editingProject {
                modalOverlay(onClose: { editingProject = nil }) {
                    ProjectEditor(
                        existing: project,
                        onClose: { editingProject = nil }
                    )
                }
            }
            if creatingNew {
                modalOverlay(onClose: { creatingNew = false }) {
                    ProjectEditor(
                        existing: nil,
                        onClose: { creatingNew = false }
                    )
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: editingProject?.id ?? -1)
        .animation(.easeOut(duration: 0.15), value: creatingNew)
    }
}

struct ProjectRowItem: View {
    let project: TTProject
    let client: TTClient
    let onEdit: () -> Void
    @EnvironmentObject var projectsStore: ProjectsStore
    @State private var hover = false

    var accent: Color {
        T.hexColor(project.client_primary_color) ?? T.hexColor(T.projectHex(project.color)) ?? T.accent
    }

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 10) {
                Rectangle().fill(accent).frame(width: 3, height: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(T.text1)
                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(String(format: "%.2f € / h", project.hourly_rate))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text2)
                Text(project.status == "active" ? "Aktiv" : "Archiviert")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(project.status == "active" ? T.success : T.text3)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background((project.status == "active" ? T.success : T.text3).opacity(0.15))
                Menu {
                    Button("Bearbeiten", action: onEdit)
                    if project.status == "active" {
                        Button("Archivieren") {
                            Task { _ = await projectsStore.update(project.id, ["status": "archived"]) }
                        }
                    } else {
                        Button("Aktivieren") {
                            Task { _ = await projectsStore.update(project.id, ["status": "active"]) }
                        }
                    }
                    Divider()
                    Button("Löschen", role: .destructive) {
                        Task { await projectsStore.delete(project.id) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.04))
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(hover ? T.cardHover : T.card)
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

struct ProjectEditor: View {
    let existing: TTProject?
    let onClose: () -> Void
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var clientId: Int?
    @State private var name: String
    @State private var description: String
    @State private var hourlyRate: Double
    @State private var defaultBillable: Bool
    @State private var status: String
    @State private var clientPickerOpen: Bool = false
    @State private var saving: Bool = false

    init(existing: TTProject?, onClose: @escaping () -> Void) {
        self.existing = existing
        self.onClose = onClose
        _clientId = State(initialValue: existing?.client)
        _name = State(initialValue: existing?.name ?? "")
        _description = State(initialValue: existing?.description ?? "")
        _hourlyRate = State(initialValue: existing?.hourly_rate ?? 0)
        _defaultBillable = State(initialValue: existing?.default_billable ?? true)
        _status = State(initialValue: existing?.status ?? "active")
    }

    var isEditing: Bool { existing != nil }
    var selectedClient: TTClient? { clientsStore.client(id: clientId) }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)

            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(T.accent)
                Text(isEditing ? "Projekt bearbeiten" : "Neues Projekt")
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
                fieldLabel("Allgemein")

                Button { clientPickerOpen = true } label: {
                    HStack(spacing: 8) {
                        if let c = selectedClient {
                            if let url = T.absoluteURL(c.logo_url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFit()
                                    default: Text(String(c.name.prefix(1))).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                    }
                                }
                                .frame(width: 22, height: 22)
                                .background(Color.white)
                            } else {
                                Text(String(c.name.prefix(1)).uppercased())
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(T.hexColor(c.primary_color) ?? T.accent)
                            }
                            Text(c.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(T.text1)
                        } else {
                            Image(systemName: "person.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                                .frame(width: 22, height: 22)
                                .background(Color.white.opacity(0.04))
                            Text("Kunde wählen")
                                .font(.system(size: 12))
                                .foregroundStyle(T.text3)
                        }
                        Spacer()
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $clientPickerOpen, arrowEdge: .top) {
                    ClientPickerPopover(
                        selectedId: clientId,
                        onSelect: { c in clientId = c?.id; clientPickerOpen = false }
                    )
                }

                TextField("Projektname", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                TextEditor(text: $description)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    .frame(height: 50)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                fieldLabel("Abrechnung")
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        TextField("0.00", value: $hourlyRate, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(T.text1)
                            .frame(width: 80)
                        Text("€ / h")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                    Button { defaultBillable.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: defaultBillable ? "checkmark.square.fill" : "square")
                                .font(.system(size: 13))
                                .foregroundStyle(defaultBillable ? T.accent : T.text3)
                            Text("Standardmäßig abrechenbar")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                }

                if isEditing {
                    fieldLabel("Status")
                    HStack(spacing: 6) {
                        statusToggle("Aktiv", value: "active", color: T.success)
                        statusToggle("Archiviert", value: "archived", color: T.text3)
                    }
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 14)

            Divider().background(T.line)

            HStack {
                if isEditing, let p = existing {
                    Button {
                        Task {
                            await projectsStore.delete(p.id)
                            onClose()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                    }.buttonStyle(.plain)
                }
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
                            "name": name,
                            "description": description,
                            "hourly_rate": hourlyRate,
                            "default_billable": defaultBillable,
                        ]
                        if isEditing {
                            fields["status"] = status
                            if let p = existing {
                                _ = await projectsStore.update(p.id, fields)
                            }
                        } else {
                            if let cid = clientId {
                                fields["client"] = cid
                                _ = await projectsStore.create(fields)
                            }
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
                .disabled(saving || (isEditing == false && (clientId == nil || name.isEmpty)))
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

    func statusToggle(_ label: String, value: String, color: Color) -> some View {
        Button { status = value } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(status == value ? T.text1 : T.text2)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(status == value ? color.opacity(0.18) : Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(status == value ? color.opacity(0.55) : T.line, lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// Helper for modal overlays (used by tabs)
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
// MARK: - Clients tab
// ============================================================

struct ClientsTab: View {
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var search: String = ""
    @State private var editingClient: TTClient? = nil
    @State private var creatingNew: Bool = false

    var filtered: [TTClient] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let sorted = clientsStore.clients.sorted { $0.name < $1.name }
        if q.isEmpty { return sorted }
        return sorted.filter {
            $0.name.lowercased().contains(q) || $0.company.lowercased().contains(q)
        }
    }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                        TextField("Suchen…", text: $search)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(T.text1)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(maxWidth: 240)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                    Spacer()
                    Button { creatingNew = true } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                            Text("Neuer Kunde").font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        if filtered.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 28, weight: .light))
                                    .foregroundStyle(T.text3)
                                Text("Keine Kunden")
                                    .font(.system(size: 12))
                                    .foregroundStyle(T.text3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                            .gridCellColumns(3)
                        }
                        ForEach(filtered) { client in
                            ClientCard(client: client, onEdit: { editingClient = client })
                        }
                    }
                    .padding(14)
                }
            }

            if let c = editingClient {
                modalOverlay(onClose: { editingClient = nil }) {
                    ClientEditor(existing: c, onClose: { editingClient = nil })
                }
            }
            if creatingNew {
                modalOverlay(onClose: { creatingNew = false }) {
                    ClientEditor(existing: nil, onClose: { creatingNew = false })
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: editingClient?.id ?? -1)
        .animation(.easeOut(duration: 0.15), value: creatingNew)
    }
}

struct ClientCard: View {
    let client: TTClient
    let onEdit: () -> Void
    @EnvironmentObject var projectsStore: ProjectsStore
    @State private var hover = false

    var projectCount: Int {
        projectsStore.projects.filter { $0.client == client.id }.count
    }

    var accent: Color { T.hexColor(client.primary_color) ?? T.accent }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let url = T.absoluteURL(client.logo_url) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFit()
                            default: Text(String(client.name.prefix(1)))
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 42, height: 42)
                        .background(Color.white)
                    } else {
                        Text(initials(of: client.name))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(client.name)
                            .font(.system(size: 13, weight: .semibold))
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
                }

                HStack(spacing: 10) {
                    Label("\(projectCount)", systemImage: "folder")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text2)
                    if !client.email.isEmpty {
                        Label(client.email, systemImage: "envelope")
                            .font(.system(size: 10))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(hover ? T.cardHover : T.card)
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }

    func initials(of name: String) -> String {
        let words = name.split(separator: " ")
        let first = words.first.map { String($0.prefix(1)) } ?? ""
        let second = words.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        return (first + second).uppercased()
    }
}

struct ClientEditor: View {
    let existing: TTClient?
    let onClose: () -> Void
    @EnvironmentObject var clientsStore: ClientsStore

    @State private var name: String
    @State private var company: String
    @State private var email: String
    @State private var phone: String
    @State private var website: String
    @State private var address: String
    @State private var zip: String
    @State private var city: String
    @State private var country: String
    @State private var taxId: String
    @State private var notes: String
    @State private var saving = false
    @State private var uploading = false
    @State private var dropTargeted = false

    init(existing: TTClient?, onClose: @escaping () -> Void) {
        self.existing = existing
        self.onClose = onClose
        _name = State(initialValue: existing?.name ?? "")
        _company = State(initialValue: existing?.company ?? "")
        _email = State(initialValue: existing?.email ?? "")
        _phone = State(initialValue: existing?.phone ?? "")
        _website = State(initialValue: existing?.website ?? "")
        _address = State(initialValue: existing?.address ?? "")
        _zip = State(initialValue: existing?.zip_code ?? "")
        _city = State(initialValue: existing?.city ?? "")
        _country = State(initialValue: existing?.country ?? "Deutschland")
        _taxId = State(initialValue: existing?.tax_id ?? "")
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var isEditing: Bool { existing != nil }

    func pickAndUploadLogo() {
        guard let id = existing?.id else { return }
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .webP, .svg, .image]
        if panel.runModal() == .OK, let url = panel.url {
            uploadLogo(url: url, id: id)
        }
    }

    func uploadLogo(url: URL, id: Int) {
        uploading = true
        Task {
            _ = await clientsStore.uploadLogo(id, fileURL: url)
            uploading = false
        }
    }

    func removeLogo() {
        guard let id = existing?.id else { return }
        Task { _ = await clientsStore.removeLogo(id) }
    }

    var currentClient: TTClient? {
        guard let id = existing?.id else { return nil }
        return clientsStore.client(id: id)
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)

            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(T.accent)
                Text(isEditing ? "Kunde bearbeiten" : "Neuer Kunde")
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
                VStack(alignment: .leading, spacing: 14) {
                    // Logo
                    if isEditing {
                        fieldLabel("Logo")
                        HStack(spacing: 12) {
                            if let c = currentClient, let url = T.absoluteURL(c.logo_url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFit()
                                    default: Image(systemName: "photo").foregroundStyle(T.text3)
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .background(Color.white)
                                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                                VStack(alignment: .leading, spacing: 6) {
                                    Button("Logo ersetzen", action: pickAndUploadLogo)
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(T.text2)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color.white.opacity(0.04))
                                    Button("Logo entfernen", action: removeLogo)
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.red.opacity(0.85))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Color.red.opacity(0.08))
                                }
                            } else {
                                Button(action: pickAndUploadLogo) {
                                    VStack(spacing: 6) {
                                        if uploading {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "arrow.up.doc")
                                                .font(.system(size: 18, weight: .light))
                                                .foregroundStyle(dropTargeted ? T.accent : T.text3)
                                        }
                                        Text("Logo hochladen")
                                            .font(.system(size: 10))
                                            .foregroundStyle(T.text3)
                                    }
                                    .frame(width: 140, height: 80)
                                    .background(Color.white.opacity(0.03))
                                    .overlay(
                                        Rectangle()
                                            .strokeBorder(
                                                dropTargeted ? T.accent : T.line,
                                                style: StrokeStyle(lineWidth: 1, dash: [4, 3])
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .onDrop(of: [.fileURL], isTargeted: $dropTargeted) { providers in
                                    for p in providers {
                                        _ = p.loadObject(ofClass: URL.self) { url, _ in
                                            if let u = url, let id = existing?.id {
                                                DispatchQueue.main.async {
                                                    uploadLogo(url: u, id: id)
                                                }
                                            }
                                        }
                                    }
                                    return true
                                }
                                Spacer()
                            }
                        }
                    }

                    fieldLabel("Allgemein")
                    HStack(spacing: 8) {
                        textInput("Name", text: $name)
                        textInput("Firma", text: $company)
                    }

                    fieldLabel("Kontakt")
                    HStack(spacing: 8) {
                        textInput("E-Mail", text: $email)
                        textInput("Telefon", text: $phone)
                        textInput("Website", text: $website)
                    }

                    fieldLabel("Adresse")
                    textInput("Straße", text: $address)
                    HStack(spacing: 8) {
                        textInput("PLZ", text: $zip).frame(maxWidth: 90)
                        textInput("Stadt", text: $city)
                        textInput("Land", text: $country)
                    }

                    fieldLabel("Geschäftlich")
                    textInput("Steuer-ID", text: $taxId)

                    fieldLabel("Notizen")
                    TextEditor(text: $notes)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                        .frame(height: 60)
                        .padding(.horizontal, 6).padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
            .frame(maxHeight: 540)

            Divider().background(T.line)

            HStack {
                if isEditing, let c = existing {
                    Button {
                        Task {
                            await clientsStore.delete(c.id)
                            onClose()
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundStyle(.red.opacity(0.85))
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                    }.buttonStyle(.plain)
                }
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
                            "name": name,
                            "company": company,
                            "email": email,
                            "phone": phone,
                            "website": website,
                            "address": address,
                            "zip_code": zip,
                            "city": city,
                            "country": country,
                            "tax_id": taxId,
                            "notes": notes,
                        ]
                        if let c = existing {
                            _ = await clientsStore.update(c.id, fields)
                        } else {
                            _ = await clientsStore.create(fields)
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
                .disabled(saving || name.isEmpty)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 600)
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

    func textInput(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(T.text1)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.04))
            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
    }
}

// ============================================================
// MARK: - Reports tab
// ============================================================

struct ReportsTab: View {
    @EnvironmentObject var summaryStore: SummaryStore
    @EnvironmentObject var entriesStore: EntriesStore
    @State private var monthAnchor: Date = Date()

    var monthRange: (from: String, to: String) {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        guard let first = cal.date(from: comps),
              let nextMonth = cal.date(byAdding: .month, value: 1, to: first),
              let last = cal.date(byAdding: .day, value: -1, to: nextMonth) else {
            return (T.dateString(monthAnchor), T.dateString(monthAnchor))
        }
        return (T.dateString(first), T.dateString(last))
    }

    var monthLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthAnchor).capitalized
    }

    var dailyHours: [Double] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: monthAnchor)
        guard let first = cal.date(from: comps) else { return [] }
        let daysInMonth = cal.range(of: .day, in: .month, for: monthAnchor)?.count ?? 30
        var values: [Double] = Array(repeating: 0, count: daysInMonth)
        let range = monthRange
        let entries = entriesStore.entries.filter { $0.date >= range.from && $0.date <= range.to }
        for entry in entries {
            if let d = T.dateFrom(entry.date) {
                let day = cal.component(.day, from: d)
                if day - 1 < values.count {
                    values[day - 1] += Double(entry.duration_minutes) / 60.0
                }
            }
        }
        _ = first
        return values
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sub-header
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Button {
                        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) {
                            monthAnchor = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(T.text2)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                    Text(monthLabel)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(T.text1)
                        .frame(minWidth: 140)
                    Button {
                        if let next = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) {
                            monthAnchor = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(T.text2)
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                    Button("Heute") {
                        monthAnchor = Date()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.04))
                }
                Spacer()
                if let s = summaryStore.summary {
                    statPill(icon: "clock", label: String(format: "%.1f h", s.total_hours))
                    statPill(icon: "eurosign", label: String(format: "%.2f €", s.total_revenue))
                    statPill(icon: "list.bullet", label: "\(s.entries_count)")
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(Rectangle().frame(height: 1).foregroundStyle(T.line), alignment: .bottom)

            ScrollView {
                if let s = summaryStore.summary {
                    HStack(alignment: .top, spacing: 14) {
                        // Charts column
                        VStack(spacing: 14) {
                            chartCard(title: "Stunden pro Projekt") {
                                BarChartV(
                                    bars: s.by_project.map { p in
                                        BarItem(label: p.project_name, value: p.hours, color: T.accent)
                                    },
                                    unit: "h"
                                )
                            }
                            chartCard(title: "Umsatz pro Projekt") {
                                BarChartV(
                                    bars: s.by_project.map { p in
                                        BarItem(label: p.project_name, value: p.revenue, color: T.success)
                                    },
                                    unit: "€"
                                )
                            }
                            chartCard(title: "Tägliche Stunden") {
                                BarChartV(
                                    bars: dailyHours.enumerated().map { i, v in
                                        BarItem(label: "\(i + 1)", value: v, color: T.accent)
                                    },
                                    unit: "h",
                                    compact: true
                                )
                            }
                            chartCard(title: "Verteilung pro Kunde") {
                                BarChartH(
                                    bars: s.by_client.map { c in
                                        BarItem(label: c.client_name, value: c.hours, color: T.accent)
                                    },
                                    unit: "h"
                                )
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Breakdown column
                        VStack(alignment: .leading, spacing: 14) {
                            breakdownCard(title: "Nach Projekt") {
                                ForEach(s.by_project) { p in
                                    BreakdownRow(
                                        name: p.project_name,
                                        hours: p.hours,
                                        revenue: p.revenue,
                                        total: s.total_hours,
                                        color: T.accent
                                    )
                                }
                            }
                            breakdownCard(title: "Nach Kunde") {
                                ForEach(s.by_client) { c in
                                    BreakdownRow(
                                        name: c.client_name,
                                        hours: c.hours,
                                        revenue: nil,
                                        total: s.total_hours,
                                        color: T.success
                                    )
                                }
                            }
                        }
                        .frame(width: 280)
                    }
                    .padding(14)
                } else {
                    VStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(T.text2)
                        Text("Lade Reports…")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }
            }
        }
        .task(id: monthRange.from) {
            await summaryStore.reload(from: monthRange.from, to: monthRange.to)
            await entriesStore.reload(from: monthRange.from, to: monthRange.to)
        }
    }

    func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(label).font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(T.text1)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(T.accentSoft)
        .overlay(Rectangle().stroke(T.accent.opacity(0.4), lineWidth: 0.5))
    }

    @ViewBuilder
    func chartCard<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(T.text3)
            content()
                .frame(height: 120)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
    }

    @ViewBuilder
    func breakdownCard<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(T.text3)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
    }
}

// ============================================================
// MARK: - Charts (custom, no external lib)
// ============================================================

struct BarItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct BarChartV: View {
    let bars: [BarItem]
    let unit: String
    var compact: Bool = false

    var maxValue: Double {
        max(bars.map { $0.value }.max() ?? 1, 0.01)
    }

    var body: some View {
        GeometryReader { geo in
            let totalW = geo.size.width
            let totalH = geo.size.height - (compact ? 12 : 18)
            let count = max(bars.count, 1)
            let barW = max(2, (totalW / CGFloat(count)) - 2)

            HStack(alignment: .bottom, spacing: 2) {
                ForEach(bars) { bar in
                    VStack(spacing: 2) {
                        if !compact {
                            Text(String(format: bar.value >= 100 ? "%.0f" : "%.1f", bar.value))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(T.text3)
                        }
                        Rectangle()
                            .fill(bar.color)
                            .frame(width: barW, height: max(1, CGFloat(bar.value / maxValue) * totalH))
                        if !compact {
                            Text(bar.label)
                                .font(.system(size: 8))
                                .foregroundStyle(T.text3)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
            }
            .frame(width: totalW, height: geo.size.height, alignment: .bottom)
        }
    }
}

struct BarChartH: View {
    let bars: [BarItem]
    let unit: String

    var maxValue: Double {
        max(bars.map { $0.value }.max() ?? 1, 0.01)
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(bars.prefix(6)) { bar in
                HStack(spacing: 6) {
                    Text(bar.label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(T.text2)
                        .frame(width: 80, alignment: .trailing)
                        .lineLimit(1)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(height: 8)
                            Rectangle()
                                .fill(bar.color)
                                .frame(width: max(1, CGFloat(bar.value / maxValue) * geo.size.width), height: 8)
                        }
                    }
                    .frame(height: 8)
                    Text(String(format: "%.1f", bar.value))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(T.text2)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}

struct BreakdownRow: View {
    let name: String
    let hours: Double
    let revenue: Double?
    let total: Double
    let color: Color

    var pct: Double { total > 0 ? hours / total : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(T.text1)
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.1fh", hours))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(T.text2)
                if let r = revenue {
                    Text(String(format: "%.0f €", r))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(T.success)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 3)
                    Rectangle().fill(color).frame(width: max(1, geo.size.width * CGFloat(pct)), height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.vertical, 2)
    }
}

// ============================================================
// MARK: - Time axis
// ============================================================

struct TimeAxis: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ForEach(Grid.startHour...Grid.endHour, id: \.self) { h in
                Text(String(format: "%02d", h))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text3)
                    .padding(.trailing, 6)
                    .offset(y: CGFloat((h - Grid.startHour) * 60) * Grid.pxPerMinute - 6)
            }
        }
        .frame(width: Grid.timeAxisWidth, height: Grid.totalHeight + 12, alignment: .topTrailing)
    }
}

// ============================================================
// MARK: - Day header
// ============================================================

struct DayHeader: View {
    let date: Date
    let entries: [TimeEntry]
    let onDropEntry: ((Int) -> Void)?

    var dayTotalMin: Int { entries.reduce(0) { $0 + $1.duration_minutes } }
    var isToday: Bool { Calendar.current.isDateInToday(date) }
    var dayNum: Int { Calendar.current.component(.day, from: date) }
    @State private var dropTargeted = false

    var body: some View {
        VStack(spacing: 1) {
            Text(T.weekdayShort(date))
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(T.text3)
                .textCase(.uppercase)
                .fixedSize()
            Text("\(dayNum)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isToday ? T.accent : T.text1)
                .fixedSize()
            Text(T.formatHours(dayTotalMin))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(dayTotalMin > 0 ? T.text2 : T.text3)
                .fixedSize()
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(
            dropTargeted ? T.accent.opacity(0.15) :
            (isToday ? T.accentSoft.opacity(0.4) : Color.clear)
        )
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(T.line),
            alignment: .bottom
        )
        .dropDestination(for: String.self) { items, _ in
            guard let item = items.first, item.hasPrefix("entry-"),
                  let id = Int(String(item.dropFirst(6))) else { return false }
            onDropEntry?(id)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.1)) { dropTargeted = targeted }
        }
    }
}

// ============================================================
// MARK: - Entry block
// ============================================================

struct EntryBlock: View {
    @EnvironmentObject var projectsStore: ProjectsStore
    let entry: TimeEntry
    let availableHeight: CGFloat

    var entryHex: String {
        if let pid = entry.project, let p = projectsStore.project(id: pid) {
            if !p.client_primary_color.isEmpty { return p.client_primary_color }
            return T.projectHex(p.color)
        }
        return T.projectHex("blue")
    }

    var colors: (bg: Color, accent: Color, text: Color, secondary: Color) {
        T.entryColors(hex: entryHex)
    }

    var activityIcon: String? {
        switch entry.activity_type {
        case "powerpoint":  return "rectangle.on.rectangle"
        case "coding":      return "chevron.left.forwardslash.chevron.right"
        case "claude_code": return "sparkle"
        case "meeting":     return "person.2.fill"
        case "research":    return "magnifyingglass"
        case "writing":     return "pencil.and.outline"
        case "email":       return "envelope.fill"
        case "rpa":         return "gearshape.2.fill"
        case "travel":      return "car.fill"
        case "walk":        return "figure.walk"
        case "gym":         return "figure.strengthtraining.traditional"
        case "chill":       return "moon.zzz.fill"
        case "fun":         return "party.popper.fill"
        default:            return nil
        }
    }

    // Decide what fits given the block height
    var showProject: Bool { availableHeight >= 38 }
    var showDescription: Bool { availableHeight >= 64 && !entry.description.isEmpty }
    var descriptionLines: Int { availableHeight >= 100 ? 3 : (availableHeight >= 80 ? 2 : 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top, spacing: 4) {
                Text("\(entry.start_time)–\(entry.end_time)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(colors.secondary)
                Spacer(minLength: 0)
                if let icon = activityIcon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colors.secondary)
                }
            }
            if showProject, let proj = entry.project_name {
                Text(proj)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(colors.text)
                    .lineLimit(1)
            }
            if showDescription {
                Text(entry.description)
                    .font(.system(size: 12))
                    .foregroundStyle(colors.secondary)
                    .lineLimit(descriptionLines)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(colors.bg)
        .overlay(alignment: .leading) {
            Rectangle().fill(colors.accent).frame(width: 3)
        }
        .overlay(
            Rectangle().stroke(colors.accent.opacity(0.4), lineWidth: 0.5)
        )
        .clipped()
    }
}

// ============================================================
// MARK: - Now line
// ============================================================

struct NowLine: View {
    @State private var nowTick = Date()
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var offset: CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: nowTick)
        let m = cal.component(.minute, from: nowTick)
        let totalMin = h * 60 + m
        return CGFloat(totalMin - Grid.startHour * 60) * Grid.pxPerMinute
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(T.danger)
                .frame(height: 1.5)
            Circle()
                .fill(T.danger)
                .frame(width: 7, height: 7)
                .offset(x: -3)
        }
        .offset(y: offset - 1)
        .onReceive(timer) { now in nowTick = now }
    }
}

// ============================================================
// MARK: - Day column with drag mechanics
// ============================================================

struct DragSession: Equatable {
    enum Kind { case create, move, resize }
    let kind: Kind
    let entryId: Int?
    let originalStart: Int
    let originalEnd: Int
    var currentStart: Int
    var currentEnd: Int
}

struct SelectionRect: View {
    let startMin: Int
    let endMin: Int
    let width: CGFloat

    var topPx: CGFloat { CGFloat(startMin - Grid.startHour * 60) * Grid.pxPerMinute }
    var height: CGFloat { max(20, CGFloat(endMin - startMin) * Grid.pxPerMinute) }

    var body: some View {
        VStack(spacing: 0) {
            Text(T.timeStringFromMinutes(startMin))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(T.timeStringFromMinutes(endMin))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(2)
        .frame(width: max(20, width - 4), height: height, alignment: .topLeading)
        .background(T.accent.opacity(0.30))
        .overlay(Rectangle().stroke(T.accent, lineWidth: 1.5))
        .offset(x: 2, y: topPx)
        .allowsHitTesting(false)
    }
}

struct DayColumn: View {
    let date: Date
    let entries: [TimeEntry]
    let onCreate: (Date, Int, Int?) -> Void
    let onEdit: (TimeEntry) -> Void
    let onMoveCommit: (TimeEntry, Int) -> Void
    let onResizeCommit: (TimeEntry, Int) -> Void

    @State private var dragSession: DragSession? = nil

    var isToday: Bool { Calendar.current.isDateInToday(date) }

    func displayedRange(for entry: TimeEntry) -> (start: Int, end: Int) {
        if let s = dragSession, s.entryId == entry.id {
            return (s.currentStart, s.currentEnd)
        }
        let start = T.minutesFromTimeString(entry.start_time)
        return (start, start + entry.duration_minutes)
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let layouts = overlapLayout(entries)

            ZStack(alignment: .topLeading) {
                // Background drag layer (create + click)
                Color.white.opacity(0.001)
                    .frame(width: width, height: Grid.totalHeight)
                    .contentShape(Rectangle())
                    .gesture(createDrag(width: width))

                // Hour lines
                ForEach(Grid.startHour...Grid.endHour, id: \.self) { h in
                    Rectangle()
                        .fill(T.line)
                        .frame(height: 0.5)
                        .offset(y: CGFloat((h - Grid.startHour) * 60) * Grid.pxPerMinute)
                        .allowsHitTesting(false)
                }

                // Right border
                Rectangle()
                    .fill(T.line)
                    .frame(width: 0.5)
                    .frame(maxHeight: .infinity)
                    .offset(x: width - 0.5)
                    .allowsHitTesting(false)

                // Entries
                ForEach(entries) { entry in
                    let layout = layouts[entry.id] ?? (col: 0, totalCols: 1)
                    let range = displayedRange(for: entry)
                    let topPx = CGFloat(range.start - Grid.startHour * 60) * Grid.pxPerMinute
                    let realH = CGFloat(range.end - range.start) * Grid.pxPerMinute
                    let h = max(20, realH)
                    let colW = (width - 2) / CGFloat(layout.totalCols)
                    let xOff = CGFloat(layout.col) * colW + 1
                    let blockW = colW - 2
                    let isDragging = (dragSession?.entryId == entry.id)

                    ZStack(alignment: .bottom) {
                        EntryBlock(entry: entry, availableHeight: h)
                            .opacity(isDragging ? 0.85 : 1)
                            .gesture(moveDrag(for: entry))
                            .onTapGesture(count: 2) { onEdit(entry) }
                            .draggable("entry-\(entry.id)")

                        // Resize handle (bottom 6px)
                        Color.white.opacity(0.001)
                            .frame(height: 6)
                            .contentShape(Rectangle())
                            .gesture(resizeDrag(for: entry))
                            .onHover { inside in
                                if inside {
                                    NSCursor.resizeUpDown.push()
                                } else {
                                    NSCursor.pop()
                                }
                            }
                    }
                    .frame(width: blockW, height: h, alignment: .topLeading)
                    .clipped()
                    .offset(x: xOff, y: topPx)
                }

                // Selection rect during create-drag
                if let s = dragSession, s.kind == .create {
                    SelectionRect(startMin: s.currentStart, endMin: s.currentEnd, width: width)
                }

                // Now line (has its own timer, doesn't re-render parent)
                if isToday {
                    NowLine()
                        .frame(width: width)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: width, height: Grid.totalHeight, alignment: .topLeading)
        }
        .frame(height: Grid.totalHeight)
    }

    // MARK: - Gestures

    func minutesAt(y: CGFloat) -> Int {
        let raw = Int(y / Grid.pxPerMinute) + Grid.startHour * 60
        let snapped = T.snapMinutes(raw, to: 15)
        return max(Grid.startHour * 60, min(Grid.endHour * 60, snapped))
    }

    func createDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                let m = minutesAt(y: v.startLocation.y)
                let cur = minutesAt(y: v.location.y)
                if dragSession == nil {
                    dragSession = DragSession(
                        kind: .create, entryId: nil,
                        originalStart: m, originalEnd: m + 30,
                        currentStart: m, currentEnd: max(m + 15, m + 30)
                    )
                }
                let lo = min(m, cur)
                let hi = max(m, cur)
                dragSession?.currentStart = lo
                dragSession?.currentEnd = max(hi, lo + 15)
            }
            .onEnded { v in
                if let s = dragSession {
                    let dy = abs(v.location.y - v.startLocation.y)
                    if dy < 6 {
                        // tap
                        onCreate(date, s.originalStart, nil)
                    } else {
                        onCreate(date, s.currentStart, s.currentEnd)
                    }
                }
                dragSession = nil
            }
    }

    func moveDrag(for entry: TimeEntry) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .local)
            .onChanged { v in
                let originalStart = T.minutesFromTimeString(entry.start_time)
                let originalEnd = originalStart + entry.duration_minutes
                if dragSession?.entryId != entry.id || dragSession?.kind != .move {
                    dragSession = DragSession(
                        kind: .move, entryId: entry.id,
                        originalStart: originalStart, originalEnd: originalEnd,
                        currentStart: originalStart, currentEnd: originalEnd
                    )
                }
                let deltaMin = T.snapMinutes(Int(v.translation.height / Grid.pxPerMinute), to: 15)
                let maxStart = Grid.endHour * 60 - entry.duration_minutes
                let newStart = max(Grid.startHour * 60, min(maxStart, originalStart + deltaMin))
                dragSession?.currentStart = newStart
                dragSession?.currentEnd = newStart + entry.duration_minutes
            }
            .onEnded { _ in
                if let s = dragSession, s.kind == .move, s.entryId == entry.id {
                    if s.currentStart != s.originalStart {
                        onMoveCommit(entry, s.currentStart)
                    }
                }
                dragSession = nil
            }
    }

    func resizeDrag(for entry: TimeEntry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { v in
                let originalStart = T.minutesFromTimeString(entry.start_time)
                let originalEnd = originalStart + entry.duration_minutes
                if dragSession?.entryId != entry.id || dragSession?.kind != .resize {
                    dragSession = DragSession(
                        kind: .resize, entryId: entry.id,
                        originalStart: originalStart, originalEnd: originalEnd,
                        currentStart: originalStart, currentEnd: originalEnd
                    )
                }
                let deltaMin = T.snapMinutes(Int(v.translation.height / Grid.pxPerMinute), to: 15)
                let newEnd = max(originalStart + 15, min(Grid.endHour * 60, originalEnd + deltaMin))
                dragSession?.currentEnd = newEnd
            }
            .onEnded { _ in
                if let s = dragSession, s.kind == .resize, s.entryId == entry.id {
                    if s.currentEnd != s.originalEnd {
                        onResizeCommit(entry, s.currentEnd)
                    }
                }
                dragSession = nil
            }
    }
}

// ============================================================
// MARK: - Project picker
// ============================================================

struct ProjectPickerPopover: View {
    let selectedId: Int?
    let onSelect: (TTProject?) -> Void
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var search: String = ""

    var grouped: [(client: TTClient, projects: [TTProject])] {
        let all = projectsStore.grouped(clients: clientsStore.clients)
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return all }
        return all.compactMap { g in
            let matchClient = g.client.name.lowercased().contains(q)
            let filtered = g.projects.filter { matchClient || $0.name.lowercased().contains(q) }
            return filtered.isEmpty ? nil : (client: g.client, projects: filtered)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(T.text3)
                TextField("Suchen…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(Color.white.opacity(0.04))

            Divider().background(T.line)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Button {
                        onSelect(nil)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                                .frame(width: 22, height: 22)
                            Text("Kein Projekt")
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
                    }
                    .buttonStyle(.plain)

                    if grouped.isEmpty {
                        Text(projectsStore.projects.isEmpty ? "Keine Projekte geladen" : "Keine Treffer")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 12).padding(.vertical, 14)
                    }

                    ForEach(grouped, id: \.client.id) { group in
                        Text(group.client.name.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 4)

                        ForEach(group.projects) { project in
                            ProjectPickerRow(
                                project: project,
                                client: group.client,
                                isSelected: project.id == selectedId,
                                onTap: { onSelect(project) }
                            )
                        }
                    }
                    Color.clear.frame(height: 6)
                }
            }
            .frame(maxHeight: 360)
        }
        .frame(width: 320)
        .background(T.bg)
    }
}

struct ProjectPickerRow: View {
    let project: TTProject
    let client: TTClient
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hover = false

    var accent: Color {
        T.hexColor(project.client_primary_color) ?? T.hexColor(T.projectHex(project.color)) ?? T.accent
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if let logoURL = T.absoluteURL(client.logo_url) {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFit()
                        default: Image(systemName: "briefcase.fill").font(.system(size: 9)).foregroundStyle(accent)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .background(Color.white)
                } else {
                    Image(systemName: "briefcase.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(accent)
                        .frame(width: 22, height: 22)
                        .background(accent.opacity(0.15))
                }
                Text(project.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(T.text1)
                    .lineLimit(1)
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
// MARK: - Activity type grid
// ============================================================

let zeitActivityTypes: [(id: String, label: String, icon: String)] = [
    ("powerpoint",  "PowerPoint",   "rectangle.on.rectangle"),
    ("coding",      "Coding",       "chevron.left.forwardslash.chevron.right"),
    ("claude_code", "Claude Code",  "sparkle"),
    ("meeting",     "Meeting",      "person.2.fill"),
    ("research",    "Research",     "magnifyingglass"),
    ("writing",     "Schreiben",    "pencil.and.outline"),
    ("email",       "E-Mail",       "envelope.fill"),
    ("rpa",         "RPA",          "gearshape.2.fill"),
    ("travel",      "Reise",        "car.fill"),
    ("walk",        "Spaziergang",  "figure.walk"),
    ("gym",         "Gym",          "figure.strengthtraining.traditional"),
    ("chill",       "Chill",        "moon.zzz.fill"),
    ("fun",         "Fun",          "party.popper.fill"),
    ("",            "Keine",        "circle.dashed"),
]

struct ActivityGrid: View {
    @Binding var selected: String

    let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(zeitActivityTypes, id: \.id) { item in
                let isActive = selected == item.id
                Button {
                    selected = item.id
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(item.label)
                            .font(.system(size: 8, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isActive ? T.text1 : T.text2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(isActive ? T.accentSoft : Color.white.opacity(0.03))
                    .overlay(
                        Rectangle()
                            .stroke(isActive ? T.accent.opacity(0.55) : T.line, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// ============================================================
// MARK: - Dual handle time slider
// ============================================================

struct DualHandleSlider: View {
    @Binding var startMin: Int
    @Binding var endMin: Int

    let minMinutes = Grid.startHour * 60
    let maxMinutes = Grid.endHour * 60
    var range: Int { maxMinutes - minMinutes }

    @State private var dragging: Handle? = nil
    enum Handle { case start, end }

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
            // Value labels above the slider
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
                    // Track background
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                        .frame(maxHeight: .infinity, alignment: .center)

                    // Selected range
                    Rectangle()
                        .fill(T.accent.opacity(0.6))
                        .frame(width: max(0, endX - startX), height: 6)
                        .offset(x: startX)
                        .frame(maxHeight: .infinity, alignment: .center)

                    // Start handle
                    Circle()
                        .fill(T.accent)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: startX - 8)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("timeSlider"))
                                .onChanged { v in
                                    let m = minutesFor(x: v.location.x, width: w)
                                    if m < endMin { startMin = m }
                                }
                        )

                    // End handle
                    Circle()
                        .fill(T.accent)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: endX - 8)
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("timeSlider"))
                                .onChanged { v in
                                    let m = minutesFor(x: v.location.x, width: w)
                                    if m > startMin { endMin = m }
                                }
                        )
                }
                .coordinateSpace(name: "timeSlider")
            }
            .frame(height: 22)

            // Hour ticks
            HStack(spacing: 0) {
                ForEach(stride(from: Grid.startHour, through: Grid.endHour, by: 2).map { $0 }, id: \.self) { h in
                    Text("\(h)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// ============================================================
// MARK: - Entry editor (custom overlay)
// ============================================================

struct EntryDraft: Equatable {
    var id: Int?
    var date: Date
    var startMin: Int
    var endMin: Int
    var description: String
    var billable: Bool
    var activity_type: String
    var project_id: Int?
    var project_name: String?
    var client_id: Int?
}

struct EntryEditor: View {
    @State var draft: EntryDraft
    let onClose: () -> Void
    let onSaved: (TimeEntry) -> Void
    let onDeleted: (Int) -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var projectPickerOpen = false
    @State private var clientPickerOpen = false
    @State private var saving = false

    init(draft: EntryDraft, onClose: @escaping () -> Void, onSaved: @escaping (TimeEntry) -> Void, onDeleted: @escaping (Int) -> Void) {
        _draft = State(initialValue: draft)
        self.onClose = onClose
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    var isEditing: Bool { draft.id != nil }

    var selectedClient: TTClient? {
        if let cid = draft.client_id { return clientsStore.client(id: cid) }
        if let pid = draft.project_id, let p = projectsStore.project(id: pid) {
            return clientsStore.client(id: p.client)
        }
        return nil
    }

    var accent: Color {
        if let pid = draft.project_id, let p = projectsStore.project(id: pid) {
            return T.hexColor(p.client_primary_color) ?? T.hexColor(T.projectHex(p.color)) ?? T.accent
        }
        return T.accent
    }

    var body: some View {
        VStack(spacing: 0) {
            accent.frame(height: 3)

            // Header
            HStack(spacing: 10) {
                Text(isEditing ? "Eintrag bearbeiten" : "Neuer Eintrag")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                if isEditing, let id = draft.id {
                    Button {
                        Task {
                            await entriesStore.delete(id)
                            onDeleted(id)
                            onClose()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                            Text("Löschen")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.red.opacity(0.1))
                    }.buttonStyle(.plain)
                }
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
                VStack(alignment: .leading, spacing: 14) {
                    // Project + Client picker row
                    HStack(spacing: 10) {
                        // Client logo button
                        Button {
                            clientPickerOpen = true
                        } label: {
                            ZStack {
                                if let c = selectedClient, let url = T.absoluteURL(c.logo_url) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let img): img.resizable().scaledToFit()
                                        default: Text(initials(of: c.name))
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    .frame(width: 40, height: 40)
                                    .background(Color.white)
                                } else if let c = selectedClient {
                                    Text(initials(of: c.name))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 40, height: 40)
                                        .background(accent)
                                } else {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(T.text3)
                                        .frame(width: 40, height: 40)
                                        .background(Color.white.opacity(0.04))
                                }
                            }
                            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $clientPickerOpen, arrowEdge: .top) {
                            ClientPickerPopover(
                                selectedId: selectedClient?.id,
                                onSelect: { c in
                                    draft.client_id = c?.id
                                    if let c = c {
                                        // If current project doesn't belong to this client, clear it
                                        if let pid = draft.project_id, let p = projectsStore.project(id: pid), p.client != c.id {
                                            draft.project_id = nil
                                            draft.project_name = nil
                                        }
                                    }
                                    clientPickerOpen = false
                                }
                            )
                        }

                        // Project picker
                        Button {
                            projectPickerOpen = true
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(accent)
                                    .frame(width: 8, height: 8)
                                Text(draft.project_name ?? "Projekt auswählen")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(draft.project_name != nil ? T.text1 : T.text3)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(T.text3)
                            }
                            .padding(.horizontal, 10).padding(.vertical, 11)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.04))
                            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $projectPickerOpen, arrowEdge: .top) {
                            ProjectPickerPopover(
                                selectedId: draft.project_id,
                                onSelect: { p in
                                    if let p = p {
                                        draft.project_id = p.id
                                        draft.project_name = p.name
                                        draft.client_id = p.client
                                    } else {
                                        draft.project_id = nil
                                        draft.project_name = nil
                                    }
                                    projectPickerOpen = false
                                }
                            )
                        }
                    }

                    // Date
                    fieldLabel("Datum")
                    DatePicker("", selection: $draft.date, displayedComponents: .date)
                        .datePickerStyle(.field)
                        .labelsHidden()

                    // Time slider
                    fieldLabel("Zeitraum")
                    DualHandleSlider(
                        startMin: $draft.startMin,
                        endMin: $draft.endMin
                    )

                    // Quick durations
                    let durations: [(label: String, minutes: Int)] = [
                        ("15m", 15), ("30m", 30), ("45m", 45),
                        ("1h", 60), ("1:30", 90), ("2h", 120),
                        ("3h", 180), ("4h", 240), ("5h", 300),
                        ("6h", 360), ("7h", 420), ("8h", 480)
                    ]
                    let durColumns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 6)
                    LazyVGrid(columns: durColumns, spacing: 5) {
                        ForEach(durations, id: \.minutes) { d in
                            Button {
                                let newEnd = draft.startMin + d.minutes
                                if newEnd <= Grid.endHour * 60 {
                                    draft.endMin = newEnd
                                }
                            } label: {
                                Text(d.label)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(T.text2)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.04))
                                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Description
                    fieldLabel("Beschreibung")
                    TextField("Was hast du getan?", text: $draft.description)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(T.text1)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                    // Activity grid
                    fieldLabel("Tätigkeit")
                    ActivityGrid(selected: $draft.activity_type)

                    // Billable
                    Button {
                        draft.billable.toggle()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: draft.billable ? "checkmark.square.fill" : "square")
                                .font(.system(size: 14))
                                .foregroundStyle(draft.billable ? T.accent : T.text3)
                            Image(systemName: "eurosign.circle")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text2)
                            Text("Abrechenbar")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(T.text1)
                            Spacer()
                        }
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }
            .frame(maxHeight: 500)

            Divider().background(T.line)

            // Footer
            HStack(spacing: 8) {
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
                            "date": T.dateString(draft.date),
                            "start_time": T.timeStringFromMinutes(draft.startMin),
                            "end_time": T.timeStringFromMinutes(draft.endMin),
                            "description": draft.description,
                            "billable": draft.billable,
                            "activity_type": draft.activity_type,
                        ]
                        if isEditing {
                            // For PUT, project is optional Int
                            if let pid = draft.project_id { fields["project"] = pid }
                            if let id = draft.id, let updated = await entriesStore.update(id, fields) {
                                onSaved(updated)
                            }
                        } else {
                            if let pid = draft.project_id { fields["project"] = pid }
                            if let new = await entriesStore.create(fields) {
                                onSaved(new)
                            }
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
                }.buttonStyle(.plain)
                .disabled(saving)
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
                .frame(width: 0, height: 0)
        )
    }

    func fieldLabel(_ s: String) -> some View {
        Text(s.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(T.text3)
            .tracking(0.6)
    }

    func initials(of name: String) -> String {
        let words = name.split(separator: " ")
        let first = words.first.map { String($0.prefix(1)) } ?? ""
        let second = words.dropFirst().first.map { String($0.prefix(1)) } ?? ""
        return (first + second).uppercased()
    }
}

// ============================================================
// MARK: - Client picker
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
        return sorted.filter { $0.name.lowercased().contains(q) }
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

                    if filtered.isEmpty {
                        Text(clientsStore.clients.isEmpty ? "Keine Kunden geladen" : "Keine Treffer")
                            .font(.system(size: 11))
                            .foregroundStyle(T.text3)
                            .padding(.horizontal, 12).padding(.vertical, 14)
                    }

                    ForEach(filtered) { c in
                        ClientPickerRow(client: c, isSelected: c.id == selectedId, onTap: { onSelect(c) })
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
// MARK: - Bulk entry editor
// ============================================================

struct BulkRow: Identifiable, Equatable {
    let id = UUID()
    var project_id: Int? = nil
    var project_name: String? = nil
    var start_time: String = "09:00"
    var duration_minutes: Int = 0
    var description: String = ""
    var billable: Bool = true
}

struct BulkEntryEditor: View {
    let initialDate: Date
    let onClose: () -> Void
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var date: Date
    @State private var rows: [BulkRow]
    @State private var saving = false
    @State private var pickerOpenForRow: UUID? = nil

    init(date: Date, onClose: @escaping () -> Void) {
        self.initialDate = date
        self.onClose = onClose
        _date = State(initialValue: date)
        _rows = State(initialValue: (0..<5).map { _ in BulkRow() })
    }

    func cascadeStartTimes() {
        for i in 1..<rows.count {
            let prevStart = T.minutesFromTimeString(rows[i - 1].start_time)
            let prevDur = rows[i - 1].duration_minutes
            if prevDur > 0 {
                rows[i].start_time = T.timeStringFromMinutes(prevStart + prevDur)
            }
        }
    }

    func saveAll() {
        saving = true
        Task {
            for row in rows {
                guard row.duration_minutes > 0 else { continue }
                let startMin = T.minutesFromTimeString(row.start_time)
                let endMin = startMin + row.duration_minutes
                var fields: [String: Any] = [
                    "date": T.dateString(date),
                    "start_time": T.timeStringFromMinutes(startMin),
                    "end_time": T.timeStringFromMinutes(endMin),
                    "description": row.description,
                    "billable": row.billable,
                    "activity_type": "",
                ]
                if let pid = row.project_id { fields["project"] = pid }
                _ = await entriesStore.create(fields)
            }
            saving = false
            onClose()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)

            HStack {
                Text("Bulk-Eintrag")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.field)
                    .labelsHidden()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.top, 14).padding(.bottom, 10)

            // Header row
            HStack(spacing: 6) {
                Text("#").frame(width: 22).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                Text("PROJEKT").frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                Text("START").frame(width: 60).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                Text("DAUER").frame(width: 60).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                Text("BESCHREIBUNG").frame(maxWidth: .infinity, alignment: .leading).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
                Text("€").frame(width: 24).font(.system(size: 9, weight: .semibold)).foregroundStyle(T.text3)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 6)

            VStack(spacing: 4) {
                ForEach($rows) { $row in
                    BulkRowView(
                        row: $row,
                        rowNumber: rows.firstIndex(where: { $0.id == row.id }).map { $0 + 1 } ?? 0,
                        onDurationChange: { cascadeStartTimes() },
                        pickerOpen: Binding(
                            get: { pickerOpenForRow == row.id },
                            set: { pickerOpenForRow = $0 ? row.id : nil }
                        )
                    )
                }
            }
            .padding(.horizontal, 18)

            HStack {
                Button {
                    rows.append(BulkRow())
                    cascadeStartTimes()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Zeile")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)

            Divider().background(T.line).padding(.top, 12)

            HStack(spacing: 8) {
                Spacer()
                Button(action: onClose) {
                    Text("Abbrechen")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                }.buttonStyle(.plain)

                Button(action: saveAll) {
                    HStack(spacing: 6) {
                        if saving { ProgressView().controlSize(.mini).tint(.white) }
                        Text("Alle speichern")
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(T.accent)
                }
                .buttonStyle(.plain)
                .disabled(saving)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 720)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
    }
}

struct BulkRowView: View {
    @Binding var row: BulkRow
    let rowNumber: Int
    let onDurationChange: () -> Void
    @Binding var pickerOpen: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("\(rowNumber)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(T.text3)
                .frame(width: 22)

            Button {
                pickerOpen = true
            } label: {
                HStack(spacing: 4) {
                    Text(row.project_name ?? "Projekt…")
                        .font(.system(size: 11))
                        .foregroundStyle(row.project_name != nil ? T.text1 : T.text3)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundStyle(T.text3)
                }
                .padding(.horizontal, 6).padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $pickerOpen, arrowEdge: .top) {
                ProjectPickerPopover(
                    selectedId: row.project_id,
                    onSelect: { p in
                        if let p = p {
                            row.project_id = p.id
                            row.project_name = p.name
                        } else {
                            row.project_id = nil
                            row.project_name = nil
                        }
                        pickerOpen = false
                    }
                )
            }

            TextField("09:00", text: $row.start_time)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(T.text1)
                .padding(.horizontal, 6).padding(.vertical, 5)
                .frame(width: 60)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

            TextField("min", value: $row.duration_minutes, format: .number)
                .textFieldStyle(.plain)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(T.text1)
                .padding(.horizontal, 6).padding(.vertical, 5)
                .frame(width: 60)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                .onChange(of: row.duration_minutes) { _, _ in onDurationChange() }

            TextField("Beschreibung", text: $row.description)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(T.text1)
                .padding(.horizontal, 6).padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

            Button {
                row.billable.toggle()
            } label: {
                Image(systemName: row.billable ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13))
                    .foregroundStyle(row.billable ? T.accent : T.text3)
                    .frame(width: 24)
            }.buttonStyle(.plain)
        }
    }
}

// ============================================================
// MARK: - Day note editor
// ============================================================

struct DayNoteEditor: View {
    let date: Date
    let onClose: () -> Void
    @EnvironmentObject var dayNotesStore: DayNotesStore
    @State private var text: String = ""
    @State private var loaded = false
    @State private var debounceTask: Task<Void, Never>? = nil
    @FocusState private var focused: Bool

    var dateLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "EEEE, d. MMMM yyyy"
        return f.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            T.accent.frame(height: 3)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tagebuch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(T.text1)
                    Text(dateLabel)
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                }
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

            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 13))
                .foregroundStyle(T.text1)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(height: 280)
                .background(Color.white.opacity(0.04))
                .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                .padding(.horizontal, 18)
                .focused($focused)
                .onChange(of: text) { _, newVal in
                    debounceTask?.cancel()
                    debounceTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        if Task.isCancelled { return }
                        await dayNotesStore.save(date: T.dateString(date), text: newVal)
                    }
                }

            HStack {
                Text("Wird automatisch gespeichert")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
                Spacer()
                Button("Schließen", action: onClose)
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 14).padding(.vertical, 7)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 520)
        .background(T.bg)
        .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        .background(
            Button("") { onClose() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
        )
        .task {
            if !loaded {
                await dayNotesStore.load(date: T.dateString(date))
                text = dayNotesStore.notes[T.dateString(date)] ?? ""
                loaded = true
                focused = true
            }
        }
    }
}

// ============================================================
// MARK: - Entries tab
// ============================================================

struct EntriesTab: View {
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var currentDate: Date = Date()
    @State private var viewMode: ViewMode = ViewMode(rawValue: UserDefaults.standard.string(forKey: "zeit.viewMode") ?? "week") ?? .week
    @State private var showWeekends: Bool = UserDefaults.standard.bool(forKey: "zeit.showWeekends")
    @State private var editorDraft: EntryDraft? = nil
    @State private var bulkOpen: Bool = false
    @State private var noteDate: Date? = nil

    enum ViewMode: String { case day, week }

    var visibleDates: [Date] {
        switch viewMode {
        case .day:
            return [currentDate]
        case .week:
            let all = T.weekDates(of: currentDate)
            return showWeekends ? all : Array(all.prefix(5))
        }
    }

    var rangeFrom: String { T.dateString(visibleDates.first ?? currentDate) }
    var rangeTo: String { T.dateString(visibleDates.last ?? currentDate) }
    var rangeKey: String { "\(rangeFrom)|\(rangeTo)" }

    var totalMinutes: Int {
        let dateSet = Set(visibleDates.map { T.dateString($0) })
        return entriesStore.entries
            .filter { dateSet.contains($0.date) }
            .reduce(0) { $0 + $1.duration_minutes }
    }

    var rangeLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        if viewMode == .day {
            f.dateFormat = "EEEE, d. MMMM yyyy"
            return f.string(from: currentDate)
        }
        guard let first = visibleDates.first, let last = visibleDates.last else { return "" }
        let kw = T.calendarWeek(of: currentDate)
        f.dateFormat = "d. MMM"
        let firstStr = f.string(from: first)
        f.dateFormat = "d. MMM yyyy"
        let lastStr = f.string(from: last)
        return "KW \(kw) · \(firstStr) – \(lastStr)"
    }

    func openCreate(date: Date, startMin: Int, endMin: Int? = nil) {
        editorDraft = EntryDraft(
            id: nil,
            date: date,
            startMin: startMin,
            endMin: endMin ?? min(Grid.endHour * 60, startMin + 60),
            description: "",
            billable: true,
            activity_type: "",
            project_id: nil,
            project_name: nil,
            client_id: nil
        )
    }

    func commitMove(_ entry: TimeEntry, newStart: Int) {
        let newEnd = newStart + entry.duration_minutes
        Task {
            await entriesStore.update(entry.id, [
                "start_time": T.timeStringFromMinutes(newStart),
                "end_time": T.timeStringFromMinutes(newEnd),
            ])
        }
    }

    func commitResize(_ entry: TimeEntry, newEnd: Int) {
        Task {
            await entriesStore.update(entry.id, [
                "end_time": T.timeStringFromMinutes(newEnd),
            ])
        }
    }

    func openEdit(_ entry: TimeEntry) {
        editorDraft = EntryDraft(
            id: entry.id,
            date: T.dateFrom(entry.date) ?? Date(),
            startMin: T.minutesFromTimeString(entry.start_time),
            endMin: T.minutesFromTimeString(entry.start_time) + entry.duration_minutes,
            description: entry.description,
            billable: entry.billable,
            activity_type: entry.activity_type,
            project_id: entry.project,
            project_name: entry.project_name,
            client_id: nil
        )
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                EntriesSubHeader(
                    currentDate: $currentDate,
                    viewMode: $viewMode,
                    showWeekends: $showWeekends,
                    rangeLabel: rangeLabel,
                    totalMinutes: totalMinutes,
                    onBulk: { bulkOpen = true },
                    onNew: { openCreate(date: currentDate, startMin: 9 * 60) }
                )

                HStack(spacing: 0) {
                    ForEach(visibleDates, id: \.self) { date in
                        DayHeader(
                            date: date,
                            entries: entriesStore.entries(on: T.dateString(date)),
                            onDropEntry: { entryId in
                                // Cross-day drag: move entry to this date
                                Task {
                                    _ = await entriesStore.update(entryId, [
                                        "date": T.dateString(date)
                                    ])
                                }
                            }
                        )
                        .overlay(
                            Rectangle().frame(width: 1).foregroundStyle(T.line),
                            alignment: .trailing
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            noteDate = date
                        }
                    }
                }
                .padding(.leading, Grid.timeAxisWidth)
                .background(T.bg.opacity(0.3))
                .fixedSize(horizontal: false, vertical: true)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        HStack(alignment: .top, spacing: 0) {
                            TimeAxis()
                            ForEach(visibleDates, id: \.self) { date in
                                DayColumn(
                                    date: date,
                                    entries: entriesStore.entries(on: T.dateString(date)),
                                    onCreate: { d, s, e in openCreate(date: d, startMin: s, endMin: e) },
                                    onEdit: { e in openEdit(e) },
                                    onMoveCommit: { e, ns in commitMove(e, newStart: ns) },
                                    onResizeCommit: { e, ne in commitResize(e, newEnd: ne) }
                                )
                            }
                        }
                        .padding(.bottom, 20)
                        // Invisible anchors per hour for scrollTo
                        .background(
                            GeometryReader { _ in
                                ForEach(Grid.startHour...Grid.endHour, id: \.self) { h in
                                    Color.clear.frame(height: 1)
                                        .id("hour-\(h)")
                                        .offset(y: CGFloat((h - Grid.startHour) * 60) * Grid.pxPerMinute)
                                }
                            }
                        )
                    }
                    .onAppear {
                        // Auto-scroll to current hour (or 8 AM, whichever is more useful)
                        let currentHour = Calendar.current.component(.hour, from: Date())
                        let scrollTarget = max(Grid.startHour, min(Grid.endHour - 2, currentHour - 1))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            proxy.scrollTo("hour-\(scrollTarget)", anchor: .top)
                        }
                    }
                }
            }

            if let draft = editorDraft {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { editorDraft = nil }
                    EntryEditor(
                        draft: draft,
                        onClose: { editorDraft = nil },
                        onSaved: { _ in editorDraft = nil },
                        onDeleted: { _ in editorDraft = nil }
                    )
                    .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                }
                .transition(.opacity)
            }

            if bulkOpen {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { bulkOpen = false }
                    BulkEntryEditor(date: currentDate, onClose: { bulkOpen = false })
                        .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                }
                .transition(.opacity)
            }

            if let nd = noteDate {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { noteDate = nil }
                    DayNoteEditor(date: nd, onClose: { noteDate = nil })
                        .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: editorDraft?.id ?? -1)
        .animation(.easeOut(duration: 0.15), value: bulkOpen)
        .animation(.easeOut(duration: 0.15), value: noteDate)
        .task(id: rangeKey) {
            await entriesStore.reload(from: rangeFrom, to: rangeTo)
        }
        .onChange(of: viewMode) { _, new in UserDefaults.standard.set(new.rawValue, forKey: "zeit.viewMode") }
        .onChange(of: showWeekends) { _, new in UserDefaults.standard.set(new, forKey: "zeit.showWeekends") }
    }
}

// ============================================================
// MARK: - Entries sub-header
// ============================================================

struct EntriesSubHeader: View {
    @Binding var currentDate: Date
    @Binding var viewMode: EntriesTab.ViewMode
    @Binding var showWeekends: Bool
    let rangeLabel: String
    let totalMinutes: Int
    let onBulk: () -> Void
    let onNew: () -> Void

    func navigate(_ direction: Int) {
        let cal = Calendar.current
        let step = viewMode == .week ? 7 : 1
        if let new = cal.date(byAdding: .day, value: direction * step, to: currentDate) {
            currentDate = new
        }
    }

    var body: some View {
        ZStack {
            // Truly centered range label
            VStack(spacing: 1) {
                Text(rangeLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text(T.formatHours(totalMinutes))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.accent)
            }

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    navButton(icon: "chevron.left") { navigate(-1) }
                    Button("Heute") { currentDate = Date() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.white.opacity(0.04))
                    navButton(icon: "chevron.right") { navigate(1) }
                }
                Spacer()
                HStack(spacing: 6) {
                    segmentButton(label: "Tag",   active: viewMode == .day)  { viewMode = .day }
                    segmentButton(label: "Woche", active: viewMode == .week) { viewMode = .week }
                    if viewMode == .week {
                        segmentButton(label: showWeekends ? "Mo–So" : "Mo–Fr", active: false) {
                            showWeekends.toggle()
                        }
                    }
                    Button(action: onBulk) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(T.text2)
                            .frame(width: 26, height: 24)
                            .background(Color.white.opacity(0.04))
                    }.buttonStyle(.plain)
                    Button(action: onNew) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Neu")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(T.accent)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(WindowDragArea())
        .overlay(
            Rectangle().frame(height: 1).foregroundStyle(T.line),
            alignment: .bottom
        )
    }

    func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(T.text2)
                .frame(width: 24, height: 24)
                .background(Color.white.opacity(0.04))
        }
        .buttonStyle(.plain)
    }

    func segmentButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? T.text1 : T.text2)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(active ? T.accentSoft : Color.white.opacity(0.04))
                .overlay(
                    Rectangle()
                        .stroke(active ? T.accent.opacity(0.55) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - Main view
// ============================================================

struct MainView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var entriesStore: EntriesStore
    @EnvironmentObject var projectsStore: ProjectsStore
    @EnvironmentObject var clientsStore: ClientsStore
    @State private var activeTab: AppTab = .entries
    @State private var showLogout = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(
                activeTab: $activeTab,
                showLogout: $showLogout,
                onReload: { Task { await reload() } }
            )

            Group {
                switch activeTab {
                case .entries:  EntriesTab()
                case .projects: ProjectsTab()
                case .clients:  ClientsTab()
                case .reports:  ReportsTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        async let p: () = projectsStore.reload()
        async let c: () = clientsStore.reload()
        _ = await (p, c)
    }
}

// ============================================================
// MARK: - Transparent window
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
            w.minSize = NSSize(width: 900, height: 600)
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

// View whose empty areas drag the window. Buttons placed on top still receive clicks.
final class WindowDragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { WindowDragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

// ============================================================
// MARK: - Root
// ============================================================

struct RootView: View {
    @StateObject private var authStore: AuthStore
    @StateObject private var entriesStore: EntriesStore
    @StateObject private var projectsStore: ProjectsStore
    @StateObject private var clientsStore: ClientsStore
    @StateObject private var summaryStore: SummaryStore
    @StateObject private var dayNotesStore: DayNotesStore
    private let api: API

    init() {
        let auth = AuthStore()
        let api = API(auth)
        _authStore = StateObject(wrappedValue: auth)
        _entriesStore = StateObject(wrappedValue: EntriesStore(api: api))
        _projectsStore = StateObject(wrappedValue: ProjectsStore(api: api))
        _clientsStore = StateObject(wrappedValue: ClientsStore(api: api))
        _summaryStore = StateObject(wrappedValue: SummaryStore(api: api))
        _dayNotesStore = StateObject(wrappedValue: DayNotesStore(api: api))
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
                    .environmentObject(projectsStore)
                    .environmentObject(clientsStore)
                    .environmentObject(summaryStore)
                    .environmentObject(dayNotesStore)
                    .task {
                        await api.refreshIfPossible()
                        async let p: () = projectsStore.reload()
                        async let c: () = clientsStore.reload()
                        _ = await (p, c)
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

// ============================================================
// MARK: - App
// ============================================================

@main
struct ZeitMacApp: App {
    init() { URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000) }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
    }
}
