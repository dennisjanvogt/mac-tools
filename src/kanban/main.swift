// Kanban — Native SwiftUI client for ConsultingOS Kanban
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
    static let authPath = NSHomeDirectory() + "/.config/kanban/auth.json"
    static let deviceName = "macOS Kanban"
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

    static func cardColor(_ name: String) -> Color {
        switch name {
        case "gray":   return Color(red: 0.45, green: 0.48, blue: 0.55)
        case "violet": return Color(red: 0.55, green: 0.42, blue: 0.75)
        case "green":  return Color(red: 0.20, green: 0.74, blue: 0.50)
        case "yellow": return Color(red: 0.98, green: 0.75, blue: 0.18)
        case "red":    return Color(red: 0.96, green: 0.30, blue: 0.37)
        case "purple": return Color(red: 0.40, green: 0.27, blue: 0.58)
        case "pink":   return Color(red: 0.95, green: 0.45, blue: 0.71)
        case "orange": return Color(red: 0.98, green: 0.58, blue: 0.24)
        default:       return Color(red: 0.45, green: 0.48, blue: 0.55)
        }
    }

    static func priorityColor(_ p: String) -> Color {
        switch p {
        case "high":   return Color(red: 0.96, green: 0.30, blue: 0.37)
        case "medium": return Color(red: 0.96, green: 0.62, blue: 0.04)
        case "low":    return Color(red: 0.20, green: 0.74, blue: 0.50)
        default:       return text3
        }
    }

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

    static let columnIcons: [String: String] = [
        "backlog":     "tray",
        "todo":        "checklist",
        "in_progress": "bolt.fill",
        "done":        "checkmark.circle.fill",
    ]
    static let columnLabels: [String: String] = [
        "backlog":     "Backlog",
        "todo":        "To-Do",
        "in_progress": "In Arbeit",
        "done":        "Erledigt",
    ]
    static let boardIcons: [String: String] = [
        "work":    "briefcase.fill",
        "private": "person.fill",
        "archive": "archivebox.fill",
    ]
    static let boardLabels: [String: String] = [
        "work":    "Work",
        "private": "Private",
        "archive": "Archive",
    ]
}

// ============================================================
// MARK: - Models
// ============================================================

struct KanbanCard: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var board: String
    var column: String
    var position: Int
    var title: String
    var description: String
    var priority: String
    var color: String
    var due_date: String?
    var project_id: Int?
    var project_name: String?
    var client_logo_url: String?
    var client_primary_color: String?
    var completed_at: String?
    var original_board: String?
    var created_at: String
    var updated_at: String
}

struct AuthData: Codable {
    var access_token: String
    var refresh_token: String
    var username: String?
}

struct TTClient: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let logo_url: String?
    let primary_color: String?
}

struct TTProject: Codable, Identifiable, Hashable {
    let id: Int
    let client: Int
    let client_name: String?
    let name: String
    let client_primary_color: String?
    let status: String?
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
        // Reload first in case another app refreshed in the meantime
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

    func listCards() async throws -> [KanbanCard] {
        let data = try await request("GET", "/api/kanban/")
        return (try? JSONDecoder().decode([KanbanCard].self, from: data)) ?? []
    }

    func createCard(_ data: [String: Any]) async throws -> KanbanCard? {
        let resp = try await request("POST", "/api/kanban/", body: data)
        return try? JSONDecoder().decode(KanbanCard.self, from: resp)
    }

    func updateCard(_ id: Int, _ data: [String: Any]) async throws -> KanbanCard? {
        let resp = try await request("PUT", "/api/kanban/\(id)", body: data)
        return try? JSONDecoder().decode(KanbanCard.self, from: resp)
    }

    func moveCard(_ id: Int, board: String, column: String, position: Int) async throws -> KanbanCard? {
        let resp = try await request("POST", "/api/kanban/\(id)/move",
                                     body: ["board": board, "column": column, "position": position])
        return try? JSONDecoder().decode(KanbanCard.self, from: resp)
    }

    func deleteCard(_ id: Int) async throws {
        _ = try await request("DELETE", "/api/kanban/\(id)")
    }

    func archiveCard(_ id: Int) async throws -> KanbanCard? {
        let resp = try await request("POST", "/api/kanban/\(id)/archive")
        return try? JSONDecoder().decode(KanbanCard.self, from: resp)
    }

    func unarchiveCard(_ id: Int) async throws -> KanbanCard? {
        let resp = try await request("POST", "/api/kanban/\(id)/unarchive")
        return try? JSONDecoder().decode(KanbanCard.self, from: resp)
    }

    func listClients() async throws -> [TTClient] {
        let data = try await request("GET", "/api/timetracking/clients/")
        return (try? JSONDecoder().decode([TTClient].self, from: data)) ?? []
    }

    func listProjects() async throws -> [TTProject] {
        let data = try await request("GET", "/api/timetracking/projects/")
        return (try? JSONDecoder().decode([TTProject].self, from: data)) ?? []
    }
}

// ============================================================
// MARK: - BoardStore
// ============================================================

@MainActor
final class BoardStore: ObservableObject {
    @Published var cards: [KanbanCard] = []
    @Published var clients: [TTClient] = []
    @Published var projects: [TTProject] = []
    @Published var activeBoard: String = UserDefaults.standard.string(forKey: "kanban.activeBoard") ?? "work" {
        didSet { UserDefaults.standard.set(activeBoard, forKey: "kanban.activeBoard") }
    }
    @Published var loading: Bool = false
    @Published var error: String?

    let api: API
    init(api: API) { self.api = api }

    static let columns = ["backlog", "todo", "in_progress", "done"]

    func cards(in column: String) -> [KanbanCard] {
        cards.filter { $0.board == activeBoard && $0.column == column }
            .sorted { $0.position < $1.position }
    }

    func archived(originalBoard: String) -> [KanbanCard] {
        cards.filter { $0.board == "archive" && ($0.original_board ?? "work") == originalBoard }
            .sorted { $0.updated_at > $1.updated_at }
    }

    func project(id: Int?) -> TTProject? {
        guard let id = id else { return nil }
        return projects.first { $0.id == id }
    }

    func client(id: Int?) -> TTClient? {
        guard let id = id else { return nil }
        return clients.first { $0.id == id }
    }

    var projectsGroupedByClient: [(client: TTClient, projects: [TTProject])] {
        let activeProjects = projects.filter { ($0.status ?? "active") == "active" }
        var byClient: [Int: [TTProject]] = [:]
        for p in activeProjects { byClient[p.client, default: []].append(p) }
        return clients
            .compactMap { c in
                guard let ps = byClient[c.id], !ps.isEmpty else { return nil }
                return (client: c, projects: ps.sorted { $0.name < $1.name })
            }
            .sorted { $0.client.name < $1.client.name }
    }

    func reload() async {
        if cards.isEmpty { loading = true }
        do {
            let fetched = try await api.listCards()
            withAnimation(.easeInOut(duration: 0.25)) { cards = fetched }
            error = nil
        } catch API.APIError.unauthorized {
            // Auth got cleared by API; LoginView will appear
        } catch {
            self.error = "Verbindung fehlgeschlagen"
        }
        loading = false
        if let cs = try? await api.listClients() { clients = cs }
        if let ps = try? await api.listProjects() { projects = ps }
    }

    func create(title: String, column: String) async {
        do {
            if let c = try await api.createCard([
                "title": title,
                "board": activeBoard,
                "column": column
            ]) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cards.append(c)
                }
            }
        } catch { self.error = "Verbindung fehlgeschlagen" }
    }

    func update(_ card: KanbanCard, fields: [String: Any]) async {
        do {
            if let c = try await api.updateCard(card.id, fields) {
                if let i = cards.firstIndex(where: { $0.id == c.id }) {
                    withAnimation(.easeInOut(duration: 0.2)) { cards[i] = c }
                }
            }
        } catch { self.error = "Verbindung fehlgeschlagen" }
    }

    func move(_ card: KanbanCard, toColumn col: String) async {
        guard card.column != col || card.board != activeBoard else { return }
        let maxPos = cards.filter { $0.board == activeBoard && $0.column == col }
                          .map { $0.position }.max() ?? 0
        let newPos = maxPos + 1
        do {
            if let c = try await api.moveCard(card.id, board: activeBoard, column: col, position: newPos) {
                if let i = cards.firstIndex(where: { $0.id == c.id }) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) { cards[i] = c }
                }
            }
        } catch { self.error = "Verbindung fehlgeschlagen" }
    }

    func delete(_ card: KanbanCard) async {
        do {
            try await api.deleteCard(card.id)
            withAnimation(.easeOut(duration: 0.2)) { cards.removeAll { $0.id == card.id } }
        } catch { self.error = "Verbindung fehlgeschlagen" }
    }

    func archive(_ card: KanbanCard) async {
        do {
            if let c = try await api.archiveCard(card.id) {
                if let i = cards.firstIndex(where: { $0.id == c.id }) {
                    withAnimation(.easeInOut(duration: 0.25)) { cards[i] = c }
                }
            }
        } catch { self.error = "Verbindung fehlgeschlagen" }
    }

    func archiveAllDone() async {
        let doneCards = cards.filter { $0.board == activeBoard && $0.column == "done" }
        guard !doneCards.isEmpty else { return }
        for card in doneCards {
            do {
                if let c = try await api.archiveCard(card.id) {
                    if let i = cards.firstIndex(where: { $0.id == c.id }) {
                        withAnimation(.easeInOut(duration: 0.25)) { cards[i] = c }
                    }
                }
            } catch {
                self.error = "Verbindung fehlgeschlagen"
                return
            }
        }
    }

    func unarchive(_ card: KanbanCard) async {
        do {
            if let c = try await api.unarchiveCard(card.id) {
                if let i = cards.firstIndex(where: { $0.id == c.id }) {
                    withAnimation(.easeInOut(duration: 0.25)) { cards[i] = c }
                }
            }
        } catch { self.error = "Verbindung fehlgeschlagen" }
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

            Image(systemName: "rectangle.3.group.fill")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(T.accent)

            VStack(spacing: 4) {
                Text("Kanban")
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

struct BoardTab: View {
    let id: String
    let active: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 6) {
                Image(systemName: T.boardIcons[id] ?? "square")
                    .font(.system(size: 10, weight: .semibold))
                Text(T.boardLabels[id] ?? id)
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
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var authStore: AuthStore
    @Binding var showLogout: Bool

    var body: some View {
        ZStack {
            // Centered board tabs
            HStack(spacing: 8) {
                ForEach(["work", "private", "archive"], id: \.self) { board in
                    BoardTab(id: board, active: store.activeBoard == board) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            store.activeBoard = board
                        }
                    }
                }
            }

            // Right-aligned controls
            HStack(spacing: 8) {
                Spacer()
                if store.loading {
                    ProgressView().controlSize(.mini).tint(T.text2)
                }
                Button {
                    Task { await store.reload() }
                } label: {
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
                    Button("Aktualisieren") { Task { await store.reload() } }
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
        .background(T.bg.opacity(0.001))
    }
}

// ============================================================
// MARK: - Card components
// ============================================================

struct NewCardRow: View {
    @Binding var title: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Neue Karte…", text: $title)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .foregroundStyle(T.text1)
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Rectangle().fill(.ultraThinMaterial).opacity(0.55))
            .overlay(Rectangle().stroke(T.accent, lineWidth: 1))
            .focused($focused)
            .onAppear { focused = true }
            .onSubmit { onSubmit() }
            .onExitCommand { onCancel() }
    }
}

struct CardRow: View {
    let card: KanbanCard
    let onEdit: () -> Void
    @State private var hover = false

    var clientColor: Color? { T.hexColor(card.client_primary_color) }
    var accentColor: Color { clientColor ?? T.cardColor(card.color) }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(T.priorityColor(card.priority))
                        .frame(width: 9, height: 9)
                        .padding(.top, 6)
                    Text(card.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(T.text1)
                        .lineLimit(3)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)
                    // Balance-Spacer, damit der Titel optisch mittig sitzt trotz Priority-Dot links
                    Color.clear.frame(width: 9, height: 9)
                }

                if !card.description.isEmpty {
                    Text(card.description)
                        .font(.system(size: 13))
                        .foregroundStyle(T.text2)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 18)
                }

                if let due = card.due_date, !due.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(formatDate(due))
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(isOverdue(due) ? Color(red: 0.96, green: 0.40, blue: 0.42) : T.text3)
                    .padding(.leading, 18)
                }

                Spacer(minLength: 0)

                // Project badge — always anchored bottom-right
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if let proj = card.project_name {
                        HStack(spacing: 7) {
                            if let logoURL = T.absoluteURL(card.client_logo_url) {
                                AsyncImage(url: logoURL) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFit()
                                    default:
                                        Image(systemName: "briefcase.fill")
                                            .font(.system(size: 9))
                                            .foregroundStyle(accentColor)
                                    }
                                }
                                .frame(width: 18, height: 18)
                                .background(Color.white)
                            } else {
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(accentColor)
                                    .frame(width: 18, height: 18)
                                    .background(accentColor.opacity(0.15))
                            }
                            Text(proj)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(T.text1)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 7).padding(.vertical, 5)
                        .background(accentColor.opacity(0.12))
                        .overlay(
                            Rectangle()
                                .stroke(accentColor.opacity(0.35), lineWidth: 0.5)
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(hover ? 0.62 : 0.45)
            )
            .overlay(alignment: .leading) {
                Rectangle().fill(accentColor).frame(width: 4)
            }
            .overlay(
                Rectangle().stroke(T.line, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.15)) { hover = h }
        }
    }

    func formatDate(_ s: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return s }
        let out = DateFormatter()
        out.locale = Locale(identifier: "de_DE")
        out.dateFormat = "d. MMM"
        return out.string(from: d)
    }

    func isOverdue(_ s: String) -> Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return false }
        return Calendar.current.startOfDay(for: d) < Calendar.current.startOfDay(for: Date())
    }
}

// ============================================================
// MARK: - Column / Board
// ============================================================

struct ColumnView: View {
    let column: String
    @Binding var editingCard: KanbanCard?
    @EnvironmentObject var store: BoardStore
    @State private var addingCard = false
    @State private var newCardTitle = ""
    @State private var dropTargeted = false

    var cards: [KanbanCard] { store.cards(in: column) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: T.columnIcons[column] ?? "circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.text2)
                Text(T.columnLabels[column] ?? column)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("\(cards.count)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text3)
                Spacer()
                if column == "done" && !cards.isEmpty {
                    Button {
                        Task { await store.archiveAllDone() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Alle archivieren")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.white.opacity(0.04))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { addingCard = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(T.text2)
                        .frame(width: 22, height: 22)
                        .background(Color.white.opacity(0.04))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)

            GeometryReader { geo in
                // 6 Cards sollen die Spalte füllen; mehr → scrollen.
                let cardSpacing: CGFloat = 8
                let visibleCount: CGFloat = 6
                let cardH: CGFloat = max(150, floor((geo.size.height - cardSpacing * (visibleCount - 1) - 8) / visibleCount))
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: cardSpacing) {
                        if addingCard {
                            NewCardRow(
                                title: $newCardTitle,
                                onSubmit: {
                                    let title = newCardTitle.trimmingCharacters(in: .whitespaces)
                                    if !title.isEmpty {
                                        Task { await store.create(title: title, column: column) }
                                    }
                                    newCardTitle = ""
                                    addingCard = false
                                },
                                onCancel: {
                                    newCardTitle = ""
                                    addingCard = false
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        ForEach(cards) { card in
                            CardRow(card: card, onEdit: { editingCard = card })
                                .frame(height: cardH)
                                .clipped()
                                .draggable("card-\(card.id)") {
                                    CardRow(card: card, onEdit: {})
                                        .frame(width: 220, height: cardH)
                                        .clipped()
                                        .opacity(0.85)
                                        .environmentObject(store)
                                }
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 10)),
                                        removal: .opacity.combined(with: .scale(scale: 0.96))
                                    )
                                )
                        }

                        // Empty state
                        if cards.isEmpty && !addingCard {
                            VStack(spacing: 6) {
                                Image(systemName: columnEmptyIcon(column))
                                    .font(.system(size: 22, weight: .light))
                                    .foregroundStyle(T.text3)
                                Text(columnEmptyLabel(column))
                                    .font(.system(size: 11))
                                    .foregroundStyle(T.text3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                        }

                        Color.clear.frame(height: 8)
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(dropTargeted ? T.accent.opacity(0.08) : Color.white.opacity(0.015))
            .overlay(
                Rectangle()
                    .stroke(dropTargeted ? T.accent.opacity(0.5) : T.line,
                            lineWidth: dropTargeted ? 1.5 : 1)
            )
            .dropDestination(for: String.self) { items, _ in
                guard let item = items.first,
                      item.hasPrefix("card-"),
                      let id = Int(String(item.dropFirst(5))),
                      let card = store.cards.first(where: { $0.id == id })
                else { return false }
                Task { await store.move(card, toColumn: column) }
                return true
            } isTargeted: { targeted in
                withAnimation(.easeOut(duration: 0.15)) { dropTargeted = targeted }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct SkeletonCard: View {
    @State private var shimmer = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 14).frame(maxWidth: .infinity)
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 10).frame(width: 120)
            Rectangle().fill(Color.white.opacity(0.03)).frame(height: 8).frame(width: 80)
        }
        .padding(14)
        .background(T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        .opacity(shimmer ? 0.4 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

struct SkeletonLoadingState: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCard()
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(14)
    }
}

func columnEmptyIcon(_ col: String) -> String {
    switch col {
    case "backlog": return "tray"
    case "todo": return "checklist"
    case "in_progress": return "bolt"
    case "done": return "checkmark.circle"
    default: return "tray"
    }
}

func columnEmptyLabel(_ col: String) -> String {
    switch col {
    case "backlog": return "Backlog ist leer"
    case "todo": return "Keine To-Dos"
    case "in_progress": return "Nichts in Arbeit"
    case "done": return "Noch nichts erledigt"
    default: return "Leer"
    }
}

struct BoardColumns: View {
    @EnvironmentObject var store: BoardStore
    @Binding var editingCard: KanbanCard?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(BoardStore.columns, id: \.self) { col in
                ColumnView(column: col, editingCard: $editingCard)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

// ============================================================
// MARK: - Archive view
// ============================================================

struct ArchivedCardRow: View {
    let card: KanbanCard
    let onUnarchive: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(T.cardColor(card.color)).frame(width: 6, height: 6)
            Text(card.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(T.text2)
                .lineLimit(1)
            Spacer()
            if hover {
                Button(action: onUnarchive) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9))
                        .foregroundStyle(T.text2)
                        .frame(width: 18, height: 18)
                }.buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.7))
                        .frame(width: 18, height: 18)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(hover ? T.cardHover : T.card)
        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
        .onHover { h in withAnimation(.easeOut(duration: 0.15)) { hover = h } }
    }
}

struct ArchiveColumn: View {
    let label: String
    let icon: String
    let originalBoard: String
    @EnvironmentObject var store: BoardStore

    var cards: [KanbanCard] { store.archived(originalBoard: originalBoard) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.accent)
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("\(cards.count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text3)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    if cards.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(T.text3)
                            Text("Keine archivierten Karten")
                                .font(.system(size: 11))
                                .foregroundStyle(T.text3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                    }
                    ForEach(cards) { card in
                        ArchivedCardRow(
                            card: card,
                            onUnarchive: { Task { await store.unarchive(card) } },
                            onDelete: { Task { await store.delete(card) } }
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    Color.clear.frame(height: 40)
                }
                .padding(.horizontal, 6)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.015))
            .overlay(Rectangle().stroke(T.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ArchiveView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ArchiveColumn(label: "Work", icon: "briefcase.fill", originalBoard: "work")
            ArchiveColumn(label: "Private", icon: "person.fill", originalBoard: "private")
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 14)
    }
}

// ============================================================
// MARK: - Edit sheet (custom overlay)
// ============================================================

struct EditCardSheet: View {
    @State var card: KanbanCard
    let onClose: () -> Void
    @EnvironmentObject var store: BoardStore
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var projectChanged: Bool = false
    @State private var projectPickerOpen: Bool = false

    init(card: KanbanCard, onClose: @escaping () -> Void) {
        _card = State(initialValue: card)
        self.onClose = onClose
        let hasDate = !(card.due_date ?? "").isEmpty
        _hasDueDate = State(initialValue: hasDate)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let parsed = (card.due_date.flatMap { f.date(from: $0) }) ?? Date()
        _dueDate = State(initialValue: parsed)
    }

    var accentColor: Color {
        T.hexColor(card.client_primary_color) ?? T.cardColor(card.color)
    }

    var body: some View {
        VStack(spacing: 0) {
            accentColor.frame(height: 3)

            HStack {
                Text("Karte bearbeiten")
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
                TextField("Titel", text: $card.title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                fieldLabel("Beschreibung")
                TextEditor(text: $card.description)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 12))
                    .foregroundStyle(T.text1)
                    .frame(height: 70)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(Color.white.opacity(0.04))
                    .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Projekt")
                    Button {
                        projectPickerOpen = true
                    } label: {
                        HStack(spacing: 8) {
                            if let logoURL = T.absoluteURL(card.client_logo_url) {
                                AsyncImage(url: logoURL) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFit()
                                    default: Image(systemName: "briefcase.fill").font(.system(size: 10)).foregroundStyle(accentColor)
                                    }
                                }
                                .frame(width: 22, height: 22)
                                .background(Color.white)
                            } else if card.project_id != nil {
                                Image(systemName: "briefcase.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(accentColor)
                                    .frame(width: 22, height: 22)
                                    .background(accentColor.opacity(0.15))
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(T.text3)
                                    .frame(width: 22, height: 22)
                                    .background(Color.white.opacity(0.04))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                if let proj = card.project_name {
                                    Text(proj)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(T.text1)
                                        .lineLimit(1)
                                    if let cid = card.project_id, let c = store.project(id: cid)?.client_name {
                                        Text(c)
                                            .font(.system(size: 10))
                                            .foregroundStyle(T.text3)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Text("Projekt auswählen")
                                        .font(.system(size: 12))
                                        .foregroundStyle(T.text3)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(T.text3)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(Color.white.opacity(0.04))
                        .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $projectPickerOpen, arrowEdge: .top) {
                        ProjectPicker(
                            selectedId: card.project_id,
                            onSelect: { project in
                                if let project = project {
                                    card.project_id = project.id
                                    card.project_name = project.name
                                    card.client_primary_color = project.client_primary_color
                                    if let c = store.client(id: project.client) {
                                        card.client_logo_url = c.logo_url
                                    } else {
                                        card.client_logo_url = nil
                                    }
                                } else {
                                    card.project_id = nil
                                    card.project_name = nil
                                    card.client_primary_color = nil
                                    card.client_logo_url = nil
                                }
                                projectChanged = true
                                projectPickerOpen = false
                            }
                        )
                        .environmentObject(store)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Priorität")
                    HStack(spacing: 5) {
                        ForEach(["low", "medium", "high"], id: \.self) { p in
                            Button {
                                card.priority = p
                            } label: {
                                HStack(spacing: 5) {
                                    Circle().fill(T.priorityColor(p)).frame(width: 6, height: 6)
                                    Text(p == "low" ? "Niedrig" : p == "medium" ? "Mittel" : "Hoch")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(card.priority == p ? T.text1 : T.text2)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(card.priority == p ? T.accentSoft : Color.white.opacity(0.03))
                                .overlay(
                                    Rectangle()
                                        .stroke(card.priority == p ? T.accent.opacity(0.55) : T.line,
                                                lineWidth: 1)
                                )
                            }.buttonStyle(.plain)
                        }
                        Spacer()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("Fälligkeit")
                    if hasDueDate {
                        HStack(spacing: 6) {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .datePickerStyle(.stepperField)
                                .labelsHidden()
                                .colorScheme(.dark)
                            Button {
                                hasDueDate = false
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(T.text3)
                                    .frame(width: 24, height: 24)
                                    .background(Color.white.opacity(0.04))
                            }.buttonStyle(.plain)
                            Spacer()
                        }
                    } else {
                        Button {
                            hasDueDate = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 11))
                                Text("Datum hinzufügen")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(T.text2)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.white.opacity(0.04))
                            .overlay(Rectangle().stroke(T.line, lineWidth: 0.5))
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)

            Divider().background(T.line)

            HStack(spacing: 8) {
                Button {
                    Task {
                        await store.archive(card)
                        onClose()
                    }
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 12))
                        .foregroundStyle(T.text2)
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)

                Button {
                    Task {
                        await store.delete(card)
                        onClose()
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.75))
                        .padding(8)
                        .background(Color.red.opacity(0.08))
                }.buttonStyle(.plain)

                Spacer()

                Button(action: onClose) {
                    Text("Abbrechen")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(T.text2)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                }.buttonStyle(.plain)

                Button {
                    Task {
                        var fields: [String: Any] = [
                            "title": card.title,
                            "description": card.description,
                            "priority": card.priority,
                        ]
                        if hasDueDate {
                            let f = DateFormatter()
                            f.dateFormat = "yyyy-MM-dd"
                            fields["due_date"] = f.string(from: dueDate)
                        }
                        if projectChanged {
                            fields["project_id"] = card.project_id ?? 0
                        }
                        await store.update(card, fields: fields)
                        onClose()
                    }
                } label: {
                    Text("Speichern")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(T.accent)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
        }
        .frame(width: 460)
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
}

// ============================================================
// MARK: - Project picker
// ============================================================

struct ProjectPicker: View {
    let selectedId: Int?
    let onSelect: (TTProject?) -> Void
    @EnvironmentObject var store: BoardStore
    @State private var search: String = ""

    var grouped: [(client: TTClient, projects: [TTProject])] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let all = store.projectsGroupedByClient
        if q.isEmpty { return all }
        return all.compactMap { group in
            let matchClient = group.client.name.lowercased().contains(q)
            let filtered = group.projects.filter { matchClient || $0.name.lowercased().contains(q) }
            return filtered.isEmpty ? nil : (client: group.client, projects: filtered)
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
                        Text(store.projects.isEmpty ? "Keine Projekte geladen" : "Keine Treffer")
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
                            ProjectRow(
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

struct ProjectRow: View {
    let project: TTProject
    let client: TTClient
    let isSelected: Bool
    let onTap: () -> Void
    @State private var hover = false

    var accent: Color { T.hexColor(project.client_primary_color) ?? T.accent }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                if let logoURL = T.absoluteURL(client.logo_url) {
                    AsyncImage(url: logoURL) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFit()
                        default: Image(systemName: "briefcase.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(accent)
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
// MARK: - Board view
// ============================================================

struct BoardView: View {
    @EnvironmentObject var store: BoardStore
    @EnvironmentObject var authStore: AuthStore
    @State private var editingCard: KanbanCard? = nil
    @State private var showLogout = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopBar(showLogout: $showLogout)
                if store.loading && store.cards.isEmpty {
                    SkeletonLoadingState()
                } else if store.activeBoard == "archive" {
                    ArchiveView()
                } else {
                    BoardColumns(editingCard: $editingCard)
                }
            }

            if let card = editingCard {
                ZStack {
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .onTapGesture { editingCard = nil }
                    EditCardSheet(card: card) { editingCard = nil }
                        .environmentObject(store)
                        .shadow(color: .black.opacity(0.6), radius: 30, y: 8)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: editingCard?.id)
        .confirmationDialog(
            "Wirklich abmelden?",
            isPresented: $showLogout,
            titleVisibility: .visible
        ) {
            Button("Abmelden", role: .destructive) { authStore.clear() }
            Button("Abbrechen", role: .cancel) { }
        }
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
            w.isMovableByWindowBackground = true
            w.hasShadow = false
            w.minSize = NSSize(width: 760, height: 480)
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

// ============================================================
// MARK: - Root
// ============================================================

struct RootView: View {
    @StateObject private var authStore: AuthStore
    @StateObject private var boardStore: BoardStore
    private let api: API

    init() {
        let auth = AuthStore()
        let api = API(auth)
        _authStore = StateObject(wrappedValue: auth)
        _boardStore = StateObject(wrappedValue: BoardStore(api: api))
        self.api = api
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
                .background(TransparentWindow())
            if authStore.isLoggedIn {
                BoardView()
                    .environmentObject(boardStore)
                    .environmentObject(authStore)
                    .task {
                        await api.refreshIfPossible()
                        await boardStore.reload()
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
struct KanbanMacApp: App {
    init() { URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000) }
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 720)
    }
}
