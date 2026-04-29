// Tafel — Native SwiftUI client für ConsultingOS Whiteboard
// Auth: device-code → JWT (shared keychain mit Kanban/Zeit/Termine)
// Backend: https://1o618.com  ·  Canvas: Excalidraw (WKWebView, CDN)

import SwiftUI
import AppKit
import WebKit
import Security
import Combine

// ============================================================
// MARK: - Config
// ============================================================

enum Config {
    static let apiBase = "https://1o618.com"
    static let deviceName = "macOS Tafel"
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
}

// ============================================================
// MARK: - Models
// ============================================================

struct AuthData: Codable {
    var access_token: String
    var refresh_token: String
    var username: String?
}

struct WhiteboardProject: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var name: String
    var diagram_count: Int
    let created_at: String
    var updated_at: String
}

struct DiagramListItem: Codable, Identifiable, Equatable, Hashable {
    let id: Int
    var title: String
    var thumbnail: String
    var project_id: Int?
    let created_at: String
    var updated_at: String
    var is_shared: Bool?
    var owner_name: String?
}

struct DiagramFull: Codable, Equatable {
    let id: Int
    var title: String
    var content: [String: AnyCodable]
    var thumbnail: String
    var project_id: Int?
    let created_at: String
    var updated_at: String
}

// JSON passthrough für beliebige Excalidraw-Content-Strukturen
struct AnyCodable: Codable, Equatable {
    let value: Any

    init(_ v: Any) { self.value = v }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull() }
        else if let b = try? c.decode(Bool.self)     { value = b }
        else if let i = try? c.decode(Int.self)      { value = i }
        else if let d = try? c.decode(Double.self)   { value = d }
        else if let s = try? c.decode(String.self)   { value = s }
        else if let a = try? c.decode([AnyCodable].self) { value = a.map(\.value) }
        else if let d = try? c.decode([String: AnyCodable].self) {
            var out: [String: Any] = [:]
            for (k, v) in d { out[k] = v.value }
            value = out
        } else { value = NSNull() }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool:    try c.encode(b)
        case let i as Int:     try c.encode(i)
        case let d as Double:  try c.encode(d)
        case let s as String:  try c.encode(s)
        case let a as [Any]:   try c.encode(a.map(AnyCodable.init))
        case let d as [String: Any]:
            var wrapped: [String: AnyCodable] = [:]
            for (k, v) in d { wrapped[k] = AnyCodable(v) }
            try c.encode(wrapped)
        default: try c.encodeNil()
        }
    }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        // Billig: JSON-String Vergleich
        let enc = JSONEncoder()
        return (try? enc.encode(lhs)) == (try? enc.encode(rhs))
    }
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
            NSHomeDirectory() + "/.config/tafel/auth.json",
            NSHomeDirectory() + "/.config/kanban/auth.json",
            NSHomeDirectory() + "/.config/zeit/auth.json",
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

    func request(_ method: String, _ path: String, body: Data? = nil, retryOn401: Bool = true) async throws -> Data {
        guard let url = URL(string: Config.apiBase + path) else { throw APIError.bad }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = auth.auth?.access_token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body
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

    func requestJSON(_ method: String, _ path: String, body: Any? = nil) async throws -> Data {
        let bodyData: Data? = body.flatMap { try? JSONSerialization.data(withJSONObject: $0) }
        return try await request(method, path, body: bodyData)
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

    // Projects
    func listProjects() async throws -> [WhiteboardProject] {
        let data = try await requestJSON("GET", "/api/whiteboard/projects")
        return (try? JSONDecoder().decode([WhiteboardProject].self, from: data)) ?? []
    }

    func createProject(name: String) async throws -> WhiteboardProject? {
        let data = try await requestJSON("POST", "/api/whiteboard/projects", body: ["name": name])
        return try? JSONDecoder().decode(WhiteboardProject.self, from: data)
    }

    func renameProject(id: Int, name: String) async throws -> WhiteboardProject? {
        let data = try await requestJSON("PUT", "/api/whiteboard/projects/\(id)", body: ["name": name])
        return try? JSONDecoder().decode(WhiteboardProject.self, from: data)
    }

    func deleteProject(id: Int) async throws {
        _ = try await requestJSON("DELETE", "/api/whiteboard/projects/\(id)")
    }

    // Diagrams
    func listDiagrams(projectId: Int? = nil, includeShared: Bool = true) async throws -> [DiagramListItem] {
        var path = "/api/whiteboard/?include_shared=\(includeShared)"
        if let pid = projectId { path += "&project_id=\(pid)" }
        let data = try await requestJSON("GET", path)
        return (try? JSONDecoder().decode([DiagramListItem].self, from: data)) ?? []
    }

    func getDiagram(id: Int) async throws -> DiagramFull? {
        let data = try await requestJSON("GET", "/api/whiteboard/\(id)")
        return try? JSONDecoder().decode(DiagramFull.self, from: data)
    }

    func createDiagram(title: String, projectId: Int?) async throws -> DiagramFull? {
        var body: [String: Any] = ["title": title, "content": [String: Any]()]
        if let p = projectId { body["project_id"] = p }
        let data = try await requestJSON("POST", "/api/whiteboard/", body: body)
        return try? JSONDecoder().decode(DiagramFull.self, from: data)
    }

    // Content als JSON-Data, Thumbnail als data-URL (optional). Hier nutzen wir rohe JSON-Bytes
    // für content, damit wir nicht serialize→deserialize Round-trippen.
    func updateDiagram(id: Int, title: String? = nil, contentJSON: Data? = nil, thumbnail: String? = nil, projectId: Int? = nil) async throws -> DiagramListItem? {
        var bodyObj: [String: Any] = [:]
        if let t = title { bodyObj["title"] = t }
        if let th = thumbnail { bodyObj["thumbnail"] = th }
        if let p = projectId { bodyObj["project_id"] = p }
        // Wenn contentJSON mitkommt, merge es vorher hinein.
        var bodyData: Data
        if let cj = contentJSON {
            // contentJSON ist ein JSON-Object. Wir bauen das finale Body-Object manuell zusammen.
            let cObj = (try? JSONSerialization.jsonObject(with: cj)) ?? [:]
            bodyObj["content"] = cObj
        }
        bodyData = try JSONSerialization.data(withJSONObject: bodyObj)
        let data = try await request("PUT", "/api/whiteboard/\(id)", body: bodyData)
        return try? JSONDecoder().decode(DiagramListItem.self, from: data)
    }

    func deleteDiagram(id: Int) async throws {
        _ = try await requestJSON("DELETE", "/api/whiteboard/\(id)")
    }
}

// ============================================================
// MARK: - BoardStore
// ============================================================

@MainActor
final class BoardStore: ObservableObject {
    @Published var projects: [WhiteboardProject] = []
    @Published var diagrams: [DiagramListItem] = []          // aktuelle Liste (für Sidebar-Auswahl)
    @Published var selection: Selection = .all
    @Published var loading: Bool = false
    @Published var error: String?
    @Published var openDiagramId: Int? = nil                 // nil = Browse-View
    @Published var currentDiagram: DiagramFull? = nil

    enum Selection: Equatable, Hashable {
        case all
        case ungrouped
        case shared
        case project(Int)
    }

    let api: API
    init(api: API) { self.api = api }

    func reloadAll() async {
        loading = true
        do {
            async let ps = api.listProjects()
            async let ds = api.listDiagrams(projectId: projectFilter, includeShared: true)
            projects = (try? await ps) ?? []
            diagrams = (try? await ds) ?? []
            error = nil
        }
        loading = false
    }

    func reloadDiagrams() async {
        do {
            let ds = try await api.listDiagrams(projectId: projectFilter, includeShared: selection == .all)
            diagrams = ds
        } catch API.APIError.unauthorized {
            // LoginView shows
        } catch {
            self.error = "Verbindung fehlgeschlagen"
        }
    }

    private var projectFilter: Int? {
        switch selection {
        case .project(let id): return id
        case .ungrouped:       return 0
        case .all, .shared:    return nil
        }
    }

    var visibleDiagrams: [DiagramListItem] {
        switch selection {
        case .shared: return diagrams.filter { $0.is_shared == true }
        default:      return diagrams
        }
    }

    func select(_ s: Selection) {
        selection = s
        Task { await reloadDiagrams() }
    }

    // Project CRUD
    func createProject(name: String) async {
        guard let p = try? await api.createProject(name: name) else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
            projects.append(p)
        }
    }

    func renameProject(_ p: WhiteboardProject, to name: String) async {
        guard let updated = try? await api.renameProject(id: p.id, name: name) else { return }
        if let i = projects.firstIndex(where: { $0.id == p.id }) {
            withAnimation(.easeInOut(duration: 0.2)) { projects[i] = updated }
        }
    }

    func deleteProject(_ p: WhiteboardProject) async {
        do {
            try await api.deleteProject(id: p.id)
            withAnimation(.easeOut(duration: 0.2)) {
                projects.removeAll { $0.id == p.id }
                if selection == .project(p.id) { selection = .all }
            }
            await reloadDiagrams()
        } catch { self.error = "Löschen fehlgeschlagen" }
    }

    // Diagram CRUD
    func createDiagram(title: String = "Unbenannt") async -> Int? {
        let pid: Int? = {
            if case .project(let id) = selection { return id }
            return nil
        }()
        guard let d = try? await api.createDiagram(title: title, projectId: pid) else { return nil }
        // Insert shallow item for grid refresh
        let item = DiagramListItem(
            id: d.id, title: d.title, thumbnail: d.thumbnail,
            project_id: d.project_id, created_at: d.created_at,
            updated_at: d.updated_at, is_shared: false, owner_name: nil
        )
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            diagrams.insert(item, at: 0)
        }
        return d.id
    }

    func renameDiagram(_ d: DiagramListItem, to title: String) async {
        _ = try? await api.updateDiagram(id: d.id, title: title)
        if let i = diagrams.firstIndex(where: { $0.id == d.id }) {
            var updated = diagrams[i]
            updated.title = title
            withAnimation(.easeInOut(duration: 0.2)) { diagrams[i] = updated }
        }
    }

    func deleteDiagram(_ d: DiagramListItem) async {
        do {
            try await api.deleteDiagram(id: d.id)
            withAnimation(.easeOut(duration: 0.2)) {
                diagrams.removeAll { $0.id == d.id }
            }
        } catch { self.error = "Löschen fehlgeschlagen" }
    }

    func moveDiagram(_ d: DiagramListItem, toProject pid: Int?) async {
        _ = try? await api.updateDiagram(id: d.id, projectId: pid ?? 0)
        await reloadDiagrams()
        await reloadAll()   // refresh counts
    }

    // Open/Close editor
    func open(_ d: DiagramListItem) async {
        guard let full = try? await api.getDiagram(id: d.id) else {
            self.error = "Diagramm konnte nicht geladen werden"
            return
        }
        currentDiagram = full
        openDiagramId = d.id
    }

    func closeEditor() {
        openDiagramId = nil
        currentDiagram = nil
    }

    // Autosave: contentJSON + thumbnail (beides optional)
    func saveCurrent(contentJSON: Data?, thumbnail: String?) async {
        guard let id = openDiagramId else { return }
        _ = try? await api.updateDiagram(id: id, contentJSON: contentJSON, thumbnail: thumbnail)
        // Update List-Eintrag
        if let idx = diagrams.firstIndex(where: { $0.id == id }) {
            var updated = diagrams[idx]
            if let th = thumbnail { updated.thumbnail = th }
            diagrams[idx] = updated
        }
    }
}

// ============================================================
// MARK: - Login View
// ============================================================

struct LoginView: View {
    @EnvironmentObject var authStore: AuthStore
    @State private var phase: Phase = .idle
    @State private var deviceCode = ""
    @State private var userCode = ""
    @State private var verificationURL = ""
    @State private var error: String?
    @State private var pollTask: Task<Void, Never>?

    enum Phase { case idle, waiting }

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(T.accent)

            VStack(spacing: 4) {
                Text("Tafel")
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
                    authStore.save(AuthData(access_token: access, refresh_token: refresh, username: username))
                    return
                }
            } catch { /* continue polling */ }
        }
    }
}

// ============================================================
// MARK: - Sidebar
// ============================================================

struct Sidebar: View {
    @EnvironmentObject var store: BoardStore
    @State private var renamingId: Int? = nil
    @State private var renameText: String = ""
    @State private var creatingProject: Bool = false
    @State private var newProjectName: String = ""
    @FocusState private var newFocus: Bool
    @FocusState private var renameFocus: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(T.accent)
                Text("Tafel")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(T.text1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Sections
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 2) {
                    sectionHeader("Ansicht")
                    navItem(label: "Alle Diagramme", icon: "rectangle.3.offgrid", selection: .all)
                    navItem(label: "Ohne Projekt",   icon: "tray",                selection: .ungrouped)
                    navItem(label: "Geteilt",        icon: "person.2",            selection: .shared)

                    HStack {
                        sectionHeader("Projekte")
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.15)) { creatingProject = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { newFocus = true }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(T.text2)
                                .frame(width: 18, height: 18)
                                .background(Color.white.opacity(0.05))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                    }

                    if creatingProject {
                        TextField("Projektname…", text: $newProjectName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(T.text1)
                            .padding(.horizontal, 10).padding(.vertical, 7)
                            .background(Color.white.opacity(0.04))
                            .overlay(Rectangle().stroke(T.accent, lineWidth: 1))
                            .focused($newFocus)
                            .onSubmit { submitNewProject() }
                            .onExitCommand {
                                creatingProject = false; newProjectName = ""
                            }
                            .padding(.horizontal, 8).padding(.vertical, 2)
                    }

                    ForEach(store.projects) { p in
                        if renamingId == p.id {
                            TextField("", text: $renameText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundStyle(T.text1)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(Color.white.opacity(0.04))
                                .overlay(Rectangle().stroke(T.accent, lineWidth: 1))
                                .focused($renameFocus)
                                .onSubmit { commitRename(p) }
                                .onExitCommand { renamingId = nil }
                                .padding(.horizontal, 8).padding(.vertical, 2)
                        } else {
                            ProjectRow(
                                project: p,
                                active: store.selection == .project(p.id),
                                onSelect: { store.select(.project(p.id)) },
                                onRename: {
                                    renameText = p.name
                                    renamingId = p.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocus = true }
                                },
                                onDelete: {
                                    Task { await store.deleteProject(p) }
                                }
                            )
                        }
                    }

                    Color.clear.frame(height: 40)
                }
                .padding(.top, 4)
            }

            // Footer
            if let name = AppShared.auth.auth?.username {
                HStack(spacing: 6) {
                    Circle().fill(T.accent).frame(width: 6, height: 6)
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(T.text3)
                    Spacer()
                    Button {
                        AppShared.auth.clear()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(T.text3)
                    }.buttonStyle(.plain)
                    .help("Abmelden")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Rectangle().stroke(T.line, lineWidth: 0.5).padding(.top, 0))
            }
        }
        .frame(width: 220)
        .background(
            Rectangle().fill(.ultraThinMaterial).opacity(0.55)
        )
        .overlay(alignment: .trailing) {
            Rectangle().fill(T.line).frame(width: 0.5)
        }
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .tracking(1.2)
            .foregroundStyle(T.text3)
            .textCase(.uppercase)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func navItem(label: String, icon: String, selection: BoardStore.Selection) -> some View {
        let active = store.selection == selection
        return Button {
            store.select(selection)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 14)
                Text(label)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(active ? T.text1 : T.text2)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(active ? T.accentSoft : Color.clear)
            .overlay(alignment: .leading) {
                if active { Rectangle().fill(T.accent).frame(width: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func submitNewProject() {
        let name = newProjectName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { creatingProject = false; return }
        Task { await store.createProject(name: name) }
        newProjectName = ""
        creatingProject = false
    }

    private func commitRename(_ p: WhiteboardProject) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty && name != p.name {
            Task { await store.renameProject(p, to: name) }
        }
        renamingId = nil
    }
}

struct ProjectRow: View {
    let project: WhiteboardProject
    let active: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 9) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 11))
                    .frame(width: 14)
                    .foregroundStyle(active ? T.accent : T.text3)
                Text(project.name)
                    .font(.system(size: 12, weight: active ? .semibold : .medium))
                    .foregroundStyle(active ? T.text1 : T.text2)
                    .lineLimit(1)
                Spacer()
                if hover {
                    Menu {
                        Button("Umbenennen", action: onRename)
                        Button("Löschen", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(T.text3)
                            .frame(width: 16, height: 16)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 16)
                } else {
                    Text("\(project.diagram_count)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color.white.opacity(0.05))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(active ? T.accentSoft : (hover ? Color.white.opacity(0.03) : Color.clear))
            .overlay(alignment: .leading) {
                if active { Rectangle().fill(T.accent).frame(width: 2) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    }
}

// ============================================================
// MARK: - Browse View (Diagram Grid)
// ============================================================

struct BrowseView: View {
    @EnvironmentObject var store: BoardStore
    @State private var search: String = ""
    @State private var renamingId: Int? = nil
    @State private var renameText: String = ""
    @FocusState private var renameFocus: Bool

    var title: String {
        switch store.selection {
        case .all:          return "Alle Diagramme"
        case .ungrouped:    return "Ohne Projekt"
        case .shared:       return "Geteilt"
        case .project(let id): return store.projects.first { $0.id == id }?.name ?? "Projekt"
        }
    }

    var filtered: [DiagramListItem] {
        let s = search.trimmingCharacters(in: .whitespaces).lowercased()
        let all = store.visibleDiagrams
        if s.isEmpty { return all }
        return all.filter { $0.title.lowercased().contains(s) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("\(filtered.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(T.text3)

                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundStyle(T.text3)
                    TextField("Suchen…", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundStyle(T.text1)
                        .frame(width: 160)
                }
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.white.opacity(0.04))

                Button {
                    Task {
                        if let id = await store.createDiagram() {
                            if let d = store.diagrams.first(where: { $0.id == id }) {
                                await store.open(d)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                        Text("Neues Diagramm")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(T.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 14)

            // Grid
            if store.loading && filtered.isEmpty {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Lade…").font(.system(size: 11)).foregroundStyle(T.text3)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filtered.isEmpty {
                EmptyStateView(
                    icon: search.isEmpty ? "square.dashed" : "magnifyingglass",
                    title: search.isEmpty ? "Noch keine Diagramme" : "Keine Treffer",
                    subtitle: search.isEmpty ? "Klick auf „Neues Diagramm“ zum Starten" : "Versuche einen anderen Suchbegriff"
                )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(filtered) { d in
                            if renamingId == d.id {
                                DiagramTile(
                                    diagram: d,
                                    onOpen: {},
                                    onRename: {},
                                    onDelete: {},
                                    renaming: true,
                                    renameText: $renameText,
                                    renameFocus: $renameFocus,
                                    onCommitRename: { commitRename(d) },
                                    onCancelRename: { renamingId = nil }
                                )
                            } else {
                                DiagramTile(
                                    diagram: d,
                                    onOpen: { Task { await store.open(d) } },
                                    onRename: {
                                        renameText = d.title
                                        renamingId = d.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocus = true }
                                    },
                                    onDelete: { Task { await store.deleteDiagram(d) } },
                                    renaming: false,
                                    renameText: $renameText,
                                    renameFocus: $renameFocus,
                                    onCommitRename: {},
                                    onCancelRename: {}
                                )
                                .contextMenu {
                                    Button("Öffnen") { Task { await store.open(d) } }
                                    Button("Umbenennen") {
                                        renameText = d.title
                                        renamingId = d.id
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocus = true }
                                    }
                                    Divider()
                                    moveMenu(for: d)
                                    Divider()
                                    Button("Löschen", role: .destructive) {
                                        Task { await store.deleteDiagram(d) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func moveMenu(for d: DiagramListItem) -> some View {
        Menu("In Projekt verschieben") {
            Button("Ohne Projekt") { Task { await store.moveDiagram(d, toProject: nil) } }
            Divider()
            ForEach(store.projects) { p in
                Button(p.name) { Task { await store.moveDiagram(d, toProject: p.id) } }
            }
        }
    }

    private func commitRename(_ d: DiagramListItem) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty && name != d.title {
            Task { await store.renameDiagram(d, to: name) }
        }
        renamingId = nil
    }
}

struct DiagramTile: View {
    let diagram: DiagramListItem
    let onOpen: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let renaming: Bool
    @Binding var renameText: String
    var renameFocus: FocusState<Bool>.Binding
    let onCommitRename: () -> Void
    let onCancelRename: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack {
                Rectangle().fill(Color.white.opacity(0.03))
                if let url = thumbnailURL(diagram.thumbnail) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().aspectRatio(contentMode: .fill)
                        default:
                            placeholderThumb
                        }
                    }
                } else if !diagram.thumbnail.isEmpty, let data = decodeDataURL(diagram.thumbnail),
                          let ns = NSImage(data: data) {
                    Image(nsImage: ns).resizable().aspectRatio(contentMode: .fill)
                } else {
                    placeholderThumb
                }
            }
            .frame(height: 150)
            .clipped()
            .overlay(alignment: .topLeading) {
                if diagram.is_shared == true {
                    HStack(spacing: 4) {
                        Image(systemName: "person.2.fill").font(.system(size: 9))
                        Text("geteilt").font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(T.accent)
                    .padding(8)
                }
            }

            // Bottom
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    if renaming {
                        TextField("", text: $renameText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(T.text1)
                            .focused(renameFocus)
                            .onSubmit { onCommitRename() }
                            .onExitCommand { onCancelRename() }
                    } else {
                        Text(diagram.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(T.text1)
                            .lineLimit(1)
                    }
                    Text(relDate(diagram.updated_at))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(T.text3)
                }
                Spacer()
                if hover && !renaming {
                    Menu {
                        Button("Öffnen", action: onOpen)
                        Button("Umbenennen", action: onRename)
                        Divider()
                        Button("Löschen", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(T.text2)
                            .frame(width: 18, height: 18)
                            .background(Color.white.opacity(0.05))
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 18)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
        }
        .background(
            Rectangle().fill(.ultraThinMaterial).opacity(hover ? 0.6 : 0.45)
        )
        .overlay(Rectangle().stroke(hover ? T.accent.opacity(0.5) : T.line, lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { if !renaming { onOpen() } }
        .onTapGesture { if !renaming { onOpen() } }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    }

    var placeholderThumb: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.dashed")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(T.text3)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func thumbnailURL(_ s: String) -> URL? {
        guard !s.isEmpty else { return nil }
        if s.hasPrefix("http") { return URL(string: s) }
        if s.hasPrefix("/") { return URL(string: Config.apiBase + s) }
        return nil
    }

    func decodeDataURL(_ s: String) -> Data? {
        guard s.hasPrefix("data:") else { return nil }
        if let idx = s.range(of: ";base64,")?.upperBound {
            return Data(base64Encoded: String(s[idx...]))
        }
        return nil
    }

    func relDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) ?? Date()
        let diff = Date().timeIntervalSince(d)
        if diff < 60 { return "gerade eben" }
        if diff < 3600 { return "vor \(Int(diff/60))m" }
        if diff < 86400 { return "vor \(Int(diff/3600))h" }
        if diff < 30 * 86400 { return "vor \(Int(diff/86400))T" }
        let out = DateFormatter()
        out.locale = Locale(identifier: "de_DE")
        out.dateFormat = "d. MMM yyyy"
        return out.string(from: d)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(T.text3)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(T.text2)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(T.text3)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ============================================================
// MARK: - Editor View (WKWebView mit Excalidraw)
// ============================================================

struct EditorView: View {
    @EnvironmentObject var store: BoardStore
    let diagram: DiagramFull

    @State private var saveState: SaveState = .saved
    @State private var renaming: Bool = false
    @State private var renameText: String = ""
    @FocusState private var renameFocus: Bool
    @State private var bridge = ExcalidrawBridge()

    enum SaveState { case saved, saving, dirty, error }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 10) {
                Button(action: { store.closeEditor() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Zurück")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(T.text2)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.white.opacity(0.04))
                }.buttonStyle(.plain)

                Divider().frame(height: 16)

                if renaming {
                    TextField("", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(T.text1)
                        .frame(maxWidth: 300)
                        .focused($renameFocus)
                        .onSubmit { commitRename() }
                        .onExitCommand { renaming = false }
                } else {
                    Button {
                        renameText = diagram.title
                        renaming = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { renameFocus = true }
                    } label: {
                        HStack(spacing: 6) {
                            Text(diagram.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(T.text1)
                            Image(systemName: "pencil")
                                .font(.system(size: 10))
                                .foregroundStyle(T.text3)
                        }
                    }.buttonStyle(.plain)
                }

                saveIndicator

                Spacer()

                Button {
                    bridge.exportPNG()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.down")
                        Text("PNG")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(T.text1)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.white.opacity(0.06))
                }.buttonStyle(.plain)
                .help("Als PNG auf den Schreibtisch exportieren")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Rectangle().fill(.ultraThinMaterial).opacity(0.6)
            )
            .overlay(alignment: .bottom) {
                Rectangle().fill(T.line).frame(height: 0.5)
            }

            // Canvas
            ExcalidrawWebView(
                diagramId: diagram.id,
                initialContent: diagram.content,
                bridge: bridge,
                onChange: { json in
                    saveState = .dirty
                    scheduleSave(contentJSON: json, thumbnail: nil)
                },
                onThumbnail: { dataURL in
                    scheduleSave(contentJSON: nil, thumbnail: dataURL)
                },
                onSavedByHost: {
                    // no-op
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    var saveIndicator: some View {
        HStack(spacing: 4) {
            switch saveState {
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
                Text("gespeichert").font(.system(size: 10)).foregroundStyle(T.text3)
            case .saving:
                ProgressView().controlSize(.mini).scaleEffect(0.6)
                Text("speichert…").font(.system(size: 10)).foregroundStyle(T.text3)
            case .dirty:
                Circle().fill(T.accent).frame(width: 5, height: 5)
                Text("ungespeichert").font(.system(size: 10)).foregroundStyle(T.text2)
            case .error:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.85))
                Text("Fehler").font(.system(size: 10)).foregroundStyle(.red.opacity(0.85))
            }
        }
        .padding(.leading, 4)
    }

    // Autosave-Debounce
    @State private var saveTask: DispatchWorkItem?
    private func scheduleSave(contentJSON: Data?, thumbnail: String?) {
        saveTask?.cancel()
        let work = DispatchWorkItem {
            Task { @MainActor in
                saveState = .saving
                await store.saveCurrent(contentJSON: contentJSON, thumbnail: thumbnail)
                saveState = .saved
                // Falls nur Content gespeichert, Thumbnail explizit nachziehen
                if thumbnail == nil {
                    bridge.requestThumbnail()
                }
            }
        }
        saveTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func commitRename() {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty && name != diagram.title else {
            renaming = false
            return
        }
        Task {
            _ = try? await store.api.updateDiagram(id: diagram.id, title: name)
            store.currentDiagram?.title = name
            if let i = store.diagrams.firstIndex(where: { $0.id == diagram.id }) {
                store.diagrams[i].title = name
            }
        }
        renaming = false
    }
}

// ============================================================
// MARK: - Excalidraw Bridge (JS ↔ Swift)
// ============================================================

final class ExcalidrawBridge {
    weak var webView: WKWebView?

    func loadContent(_ content: [String: AnyCodable]) {
        guard let webView else { return }
        let data = (try? JSONEncoder().encode(content)) ?? "{}".data(using: .utf8)!
        let json = String(data: data, encoding: .utf8) ?? "{}"
        // Safely pass as JSON literal
        let js = "window.tafelLoad(\(json));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    func requestThumbnail() {
        webView?.evaluateJavaScript("window.tafelThumbnail && window.tafelThumbnail();", completionHandler: nil)
    }

    func exportPNG() {
        webView?.evaluateJavaScript("window.tafelExportPNG && window.tafelExportPNG();", completionHandler: nil)
    }
}

struct ExcalidrawWebView: NSViewRepresentable {
    let diagramId: Int
    let initialContent: [String: AnyCodable]
    let bridge: ExcalidrawBridge
    let onChange: (Data) -> Void
    let onThumbnail: (String) -> Void
    let onSavedByHost: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange, onThumbnail: onThumbnail, bridge: bridge, initialContent: initialContent)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "tafel")
        config.userContentController = ucc
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        wv.navigationDelegate = context.coordinator

        bridge.webView = wv
        context.coordinator.webView = wv

        wv.loadHTMLString(Self.htmlString, baseURL: URL(string: "https://tafel.local/"))
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        let onChange: (Data) -> Void
        let onThumbnail: (String) -> Void
        let bridge: ExcalidrawBridge
        let initialContent: [String: AnyCodable]
        var didInjectInitial = false

        init(onChange: @escaping (Data) -> Void,
             onThumbnail: @escaping (String) -> Void,
             bridge: ExcalidrawBridge,
             initialContent: [String: AnyCodable]) {
            self.onChange = onChange
            self.onThumbnail = onThumbnail
            self.bridge = bridge
            self.initialContent = initialContent
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else { return }

            switch type {
            case "ready":
                if !didInjectInitial {
                    didInjectInitial = true
                    bridge.loadContent(initialContent)
                }
            case "change":
                if let content = dict["content"] {
                    if let data = try? JSONSerialization.data(withJSONObject: content) {
                        onChange(data)
                    }
                }
            case "thumbnail":
                if let s = dict["dataUrl"] as? String {
                    onThumbnail(s)
                }
            case "exportPng":
                if let s = dict["dataUrl"] as? String {
                    saveDataURLToDesktop(s)
                }
            default: break
            }
        }

        private func saveDataURLToDesktop(_ dataURL: String) {
            guard let range = dataURL.range(of: ";base64,") else { return }
            let b64 = String(dataURL[range.upperBound...])
            guard let data = Data(base64Encoded: b64) else { return }
            let fm = FileManager.default
            let desktop = fm.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSHomeDirectory() + "/Desktop")
            let ts = Int(Date().timeIntervalSince1970)
            let url = desktop.appendingPathComponent("tafel-\(ts).png")
            try? data.write(to: url)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // ============================================================
    // Inlined Excalidraw-Host-HTML. Lädt React + Excalidraw von jsdelivr
    // und bridged per window.webkit.messageHandlers.tafel.
    // ============================================================

    static let htmlString: String = """
    <!DOCTYPE html>
    <html lang="de" class="dark">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Tafel</title>
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@excalidraw/excalidraw@0.18.0/dist/dev/index.css">
      <style>
        html, body, #root { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; color: #eee; }
        .excalidraw .welcome-screen-center, .excalidraw .welcome-screen-decor,
        .excalidraw [href*="twitter.com"], .excalidraw [href*="x.com"],
        .excalidraw [href*="github.com/excalidraw"], .excalidraw [href*="discord"],
        .excalidraw .MainMenu__socials, .excalidraw [class*="socials"] { display: none !important; }
        .loading { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
                   color: #888; font-size: 13px; }
        .loading .spinner { width: 18px; height: 18px; border: 2px solid #555; border-top-color: #8b6bcf;
                            border-radius: 50%; animation: spin 0.8s linear infinite; margin-right: 8px; }
        @keyframes spin { to { transform: rotate(360deg); } }
      </style>
    </head>
    <body>
      <div id="root"><div class="loading"><div class="spinner"></div>Excalidraw lädt…</div></div>

      <script src="https://cdn.jsdelivr.net/npm/react@18.2.0/umd/react.production.min.js"></script>
      <script src="https://cdn.jsdelivr.net/npm/react-dom@18.2.0/umd/react-dom.production.min.js"></script>
      <script>
        window.EXCALIDRAW_ASSET_PATH = "https://cdn.jsdelivr.net/npm/@excalidraw/excalidraw@0.18.0/dist/prod/";
      </script>
      <script src="https://cdn.jsdelivr.net/npm/@excalidraw/excalidraw@0.18.0/dist/prod/index.js"></script>
      <script>
        (function () {
          'use strict';
          const send = (msg) => {
            try { window.webkit.messageHandlers.tafel.postMessage(msg); } catch (e) {}
          };

          if (!window.ExcalidrawLib) {
            document.getElementById('root').innerHTML =
              '<div class="loading">Konnte Excalidraw nicht laden. Internet prüfen.</div>';
            send({ type: 'error', error: 'excalidraw-load-failed' });
            return;
          }

          const e = React.createElement;
          const { Excalidraw, serializeAsJSON, exportToBlob } = window.ExcalidrawLib;

          let excalidrawAPI = null;
          let changeTimer = null;
          let thumbTimer = null;
          let lastSerialized = "";

          function serializeCurrent() {
            if (!excalidrawAPI) return null;
            const elements = excalidrawAPI.getSceneElements();
            const state = excalidrawAPI.getAppState();
            const files = excalidrawAPI.getFiles();
            const s = serializeAsJSON(elements, state, files, "local");
            return JSON.parse(s);
          }

          function onChange() {
            if (!excalidrawAPI) return;
            if (changeTimer) clearTimeout(changeTimer);
            changeTimer = setTimeout(() => {
              try {
                const data = serializeCurrent();
                const json = JSON.stringify(data);
                if (json === lastSerialized) return;
                lastSerialized = json;
                send({ type: 'change', content: data });
                // Thumbnail re-request
                if (thumbTimer) clearTimeout(thumbTimer);
                thumbTimer = setTimeout(generateThumbnail, 1200);
              } catch (err) {
                send({ type: 'error', error: String(err) });
              }
            }, 500);
          }

          async function generateThumbnail() {
            if (!excalidrawAPI) return;
            try {
              const elements = excalidrawAPI.getSceneElements();
              if (!elements || elements.length === 0) {
                send({ type: 'thumbnail', dataUrl: '' });
                return;
              }
              const files = excalidrawAPI.getFiles();
              const blob = await exportToBlob({
                elements: elements,
                files: files,
                appState: {
                  exportBackground: true,
                  viewBackgroundColor: '#1a1a1f',
                  exportWithDarkMode: true,
                },
                mimeType: 'image/png',
                maxWidthOrHeight: 480,
              });
              const reader = new FileReader();
              reader.onloadend = () => {
                send({ type: 'thumbnail', dataUrl: reader.result });
              };
              reader.readAsDataURL(blob);
            } catch (err) {
              send({ type: 'error', error: String(err) });
            }
          }

          async function exportFullPNG() {
            if (!excalidrawAPI) return;
            try {
              const elements = excalidrawAPI.getSceneElements();
              const files = excalidrawAPI.getFiles();
              const blob = await exportToBlob({
                elements: elements,
                files: files,
                appState: {
                  exportBackground: true,
                  viewBackgroundColor: '#ffffff',
                  exportWithDarkMode: false,
                  exportPadding: 20,
                },
                mimeType: 'image/png',
                maxWidthOrHeight: 4096,
              });
              const reader = new FileReader();
              reader.onloadend = () => {
                send({ type: 'exportPng', dataUrl: reader.result });
              };
              reader.readAsDataURL(blob);
            } catch (err) {
              send({ type: 'error', error: String(err) });
            }
          }

          window.tafelLoad = function (contentObj) {
            if (!excalidrawAPI) {
              window.__tafelPendingLoad = contentObj;
              return;
            }
            try {
              const scene = {
                elements: contentObj && contentObj.elements ? contentObj.elements : [],
                appState: Object.assign(
                  { viewBackgroundColor: '#1a1a1f' },
                  contentObj && contentObj.appState ? contentObj.appState : {}
                ),
                files: contentObj && contentObj.files ? contentObj.files : null,
              };
              // Stabilisiere: zoom + scrollToContent
              excalidrawAPI.updateScene(scene);
              if (scene.files) {
                excalidrawAPI.addFiles(Object.values(scene.files));
              }
              excalidrawAPI.scrollToContent(undefined, { fitToContent: true, animate: false });
              lastSerialized = JSON.stringify(serializeCurrent());
            } catch (err) {
              send({ type: 'error', error: 'load-failed: ' + String(err) });
            }
          };

          window.tafelThumbnail = generateThumbnail;
          window.tafelExportPNG = exportFullPNG;

          function App() {
            return e('div', { style: { width: '100%', height: '100%' } },
              e(Excalidraw, {
                excalidrawAPI: (api) => {
                  excalidrawAPI = api;
                  send({ type: 'ready' });
                  // Apply pending initial load
                  if (window.__tafelPendingLoad) {
                    const p = window.__tafelPendingLoad;
                    window.__tafelPendingLoad = null;
                    setTimeout(() => window.tafelLoad(p), 60);
                  }
                },
                theme: 'dark',
                onChange: onChange,
                langCode: 'de-DE',
                UIOptions: {
                  canvasActions: {
                    changeViewBackgroundColor: true,
                    clearCanvas: true,
                    export: { saveFileToDisk: false },
                    loadScene: false,
                    saveToActiveFile: false,
                    toggleTheme: true,
                  },
                },
              })
            );
          }

          const root = ReactDOM.createRoot(document.getElementById('root'));
          root.render(e(App));
        })();
      </script>
    </body>
    </html>
    """
}

// ============================================================
// MARK: - Main View
// ============================================================

struct MainView: View {
    @EnvironmentObject var authStore: AuthStore
    @EnvironmentObject var store: BoardStore

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea().background(TransparentWindow())

            if !authStore.isLoggedIn {
                LoginView()
            } else if let full = store.currentDiagram, store.openDiagramId != nil {
                EditorView(diagram: full)
            } else {
                HStack(spacing: 0) {
                    Sidebar()
                    BrowseView()
                }
            }
        }
        .frame(minWidth: 1100, minHeight: 700)
        .onAppear {
            if authStore.isLoggedIn {
                Task { await store.reloadAll() }
            }
        }
        .onChange(of: authStore.isLoggedIn) { _, logged in
            if logged { Task { await store.reloadAll() } }
        }
    }
}

// ============================================================
// MARK: - Transparent Window
// ============================================================

class WindowRef { static var window: NSWindow? }

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
            w.isMovableByWindowBackground = true
            w.hasShadow = true
            WindowRef.window = w
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

// ============================================================
// MARK: - Shared App State (für Sidebar-Logout-Button)
// ============================================================

enum AppShared {
    static let auth = AuthStore()
}

// ============================================================
// MARK: - App
// ============================================================

@main
struct TafelApp: App {
    @StateObject private var auth = AppShared.auth
    @StateObject private var store: BoardStore

    init() {
        let s = BoardStore(api: API(AppShared.auth))
        _store = StateObject(wrappedValue: s)
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(auth)
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neues Diagramm") {
                    Task { @MainActor in
                        if let id = await store.createDiagram() {
                            if let d = store.diagrams.first(where: { $0.id == id }) {
                                await store.open(d)
                            }
                        }
                    }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandMenu("Ansicht") {
                Button("Zurück zur Übersicht") { store.closeEditor() }
                    .keyboardShortcut("[", modifiers: .command)
            }
        }
    }
}
