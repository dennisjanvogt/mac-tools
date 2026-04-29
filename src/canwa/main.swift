// Canwa — Native SwiftUI shell + WKWebView hosting extracted ConsultingOS image editor.
// Bundle: Canwa.app/Contents/Resources/web/  (built via Vite from ~/.local/src/canwa-web)
// Auth: shared keychain (com.dennis.consultingos) — Bearer token injected into window.canwaConfig.

import SwiftUI
import AppKit
import WebKit
import Security

// ============================================================
// MARK: - Config
// ============================================================

enum Config {
    static let apiBase = "https://1o618.com"
    static let deviceName = "macOS Canwa"
}

struct T {
    static let bg        = Color(red: 0.06, green: 0.055, blue: 0.08)
    static let text1     = Color.white.opacity(0.93)
    static let text2     = Color.white.opacity(0.55)
    static let text3     = Color.white.opacity(0.30)
    static let accent    = Color(red: 0.55, green: 0.42, blue: 0.75)
    static let accentSoft = Color(red: 0.55, green: 0.42, blue: 0.75).opacity(0.18)
}

// ============================================================
// MARK: - Auth (shared keychain)
// ============================================================

struct AuthData: Codable {
    var access_token: String
    var refresh_token: String
    var username: String?
}

final class AuthStore: ObservableObject {
    @Published var auth: AuthData?
    static let keychainService = "com.dennis.consultingos"
    static let keychainAccount = "default"

    init() { loadFromKeychain() }

    func loadFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        if SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
           let data = result as? Data,
           let a = try? JSONDecoder().decode(AuthData.self, from: data) {
            auth = a
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
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        if SecItemUpdate(query as CFDictionary, attrs as CFDictionary) == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
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
// MARK: - Login View (device-code)
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
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(T.accent)

            VStack(spacing: 4) {
                Text("Canwa")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(T.text1)
                Text("ConsultingOS · Bildeditor")
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
                    deviceCode = dc; userCode = uc; verificationURL = vu
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
                if (json["status"] as? String) == "approved",
                   let access = json["access_token"] as? String,
                   let refresh = json["refresh_token"] as? String {
                    let u = (json["user"] as? [String: Any])?["username"] as? String
                    authStore.save(AuthData(access_token: access, refresh_token: refresh, username: u))
                    return
                }
            } catch { /* continue */ }
        }
    }
}

// ============================================================
// MARK: - Web editor bridge
// ============================================================

struct CanwaWebView: NSViewRepresentable {
    let token: String
    let apiBase: String
    let onRequestLogout: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onRequestLogout: onRequestLogout, apiBase: apiBase)
    }

    func makeNSView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "canwa")
        ucc.add(context.coordinator, name: "canwaLog")

        // Inject window.canwaConfig BEFORE any page script runs, plus a
        // console.log/warn/error bridge so web errors land in the app's stderr
        // (visible when launched from Terminal). Helps diagnose issues like
        // the library failing to load without having to attach an inspector.
        let js = """
        window.canwaConfig = { apiBase: \(jsString(apiBase)), token: \(jsString(token)) };
        (function () {
          const post = (level, args) => {
            try {
              const parts = Array.prototype.map.call(args, a => {
                if (a instanceof Error) return (a.message || String(a)) + (a.stack ? ' [' + a.stack.split('\\n')[0] + ']' : '');
                if (typeof a === 'object') { try { return JSON.stringify(a); } catch (_) { return String(a); } }
                return String(a);
              });
              window.webkit.messageHandlers.canwaLog.postMessage({ level: level, msg: parts.join(' ') });
            } catch (_) {}
          };
          ['log', 'info', 'warn', 'error'].forEach(level => {
            const orig = console[level].bind(console);
            console[level] = function () { post(level, arguments); orig.apply(console, arguments); };
          });
          window.addEventListener('error', e => post('uncaught', [e.message, e.filename + ':' + e.lineno]));
          window.addEventListener('unhandledrejection', e => post('rejection', [e.reason && (e.reason.stack || e.reason.message || e.reason)]));
        })();
        """
        ucc.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))

        cfg.userContentController = ucc
        cfg.preferences.setValue(true, forKey: "developerExtrasEnabled")

        // Use a custom URL scheme so module scripts + dynamic imports work identical
        // to an http origin (file:// has too many restrictions for ES modules & WASM).
        // The handler also proxies /api/ requests so everything is same-origin.
        if let bundleRoot = Self.bundleWebRoot() {
            cfg.setURLSchemeHandler(
                WebBundleSchemeHandler(root: bundleRoot, apiBase: apiBase),
                forURLScheme: "canwa"
            )
        }

        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.setValue(false, forKey: "drawsBackground")
        wv.navigationDelegate = context.coordinator
        // Allow attaching Safari Web Inspector (Develop menu) at runtime.
        if #available(macOS 13.3, *) { wv.isInspectable = true }
        context.coordinator.webView = wv

        if Self.bundleWebRoot() != nil,
           let url = URL(string: "canwa://app/index.html") {
            wv.load(URLRequest(url: url))
        } else {
            wv.loadHTMLString(Self.fallbackHTML, baseURL: nil)
        }
        return wv
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Push fresh token whenever it changes (after refresh).
        let js = """
        if (window.canwaConfig) {
          window.canwaConfig.token = \(jsString(token));
          window.canwaConfig.apiBase = \(jsString(apiBase));
        }
        """
        nsView.evaluateJavaScript(js, completionHandler: nil)
    }

    // Root folder containing the built web bundle (index.html + assets/).
    static func bundleWebRoot() -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let web = resourceURL.appendingPathComponent("web", isDirectory: true)
            if FileManager.default.fileExists(atPath: web.path) { return web }
        }
        let dev = URL(fileURLWithPath: NSHomeDirectory() + "/.local/src/canwa-web/dist", isDirectory: true)
        if FileManager.default.fileExists(atPath: dev.path) { return dev }
        return nil
    }

    static let fallbackHTML = """
    <!doctype html><html><body style='background:#101014;color:#aaa;
    font-family:-apple-system;padding:40px;line-height:1.5'>
    <h2 style='color:#b695e8'>Canwa Web-Bundle fehlt</h2>
    <p>Bitte zuerst bauen: <code>cd ~/.local/src/canwa-web &amp;&amp; npm run build</code>
    und dann <code>canwa rebuild</code>.</p>
    </body></html>
    """

    private func jsString(_ s: String) -> String {
        // JSON-safe string literal
        (try? String(data: JSONSerialization.data(withJSONObject: [s], options: [.fragmentsAllowed]),
                     encoding: .utf8))?
            .dropFirst().dropLast().description ?? "\"\""
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        weak var webView: WKWebView?
        let onRequestLogout: () -> Void
        let apiBase: String

        init(onRequestLogout: @escaping () -> Void, apiBase: String) {
            self.onRequestLogout = onRequestLogout
            self.apiBase = apiBase
        }

        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            // Console bridge: write web logs to stderr so they show up in
            // Terminal when the app is launched there.
            if message.name == "canwaLog" {
                if let dict = message.body as? [String: Any] {
                    let level = (dict["level"] as? String) ?? "log"
                    let msg = (dict["msg"] as? String) ?? ""
                    FileHandle.standardError.write(Data("[web/\(level)] \(msg)\n".utf8))
                }
                return
            }
            guard let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else { return }
            switch type {
            case "ready":
                // Web app booted
                break
            case "logout":
                onRequestLogout()
            default: break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow only file:// (our bundle). Any http(s) link opens in the system browser.
            if let url = navigationAction.request.url,
               navigationAction.navigationType == .linkActivated,
               (url.scheme == "http" || url.scheme == "https") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}

// Shared singleton so the SchemeHandler can access the current token.
enum AppShared {
    static let auth = AuthStore()
}

// Serves files from the app's web/ resource folder AND proxies any /api/ request
// through URLSession with the shared Bearer token — bypasses CORS entirely since
// the webview only ever sees same-origin canwa:// URLs.
final class WebBundleSchemeHandler: NSObject, WKURLSchemeHandler {
    let root: URL
    let apiBase: String
    // Tracks active tasks so we can honor `stop` from WebKit.
    private var activeTasks: [ObjectIdentifier: URLSessionDataTask] = [:]
    private let lock = NSLock()

    init(root: URL, apiBase: String) {
        self.root = root
        self.apiBase = apiBase
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL)); return
        }

        var rel = url.path
        if rel.hasPrefix("/") { rel.removeFirst() }

        // Route /api/, /media/, /static/ → ConsultingOS backend with Bearer auth.
        if rel.hasPrefix("api/") || rel == "api"
            || rel.hasPrefix("media/") || rel == "media"
            || rel.hasPrefix("static/") || rel == "static" {
            proxyAPI(urlSchemeTask: urlSchemeTask, url: url, retry401: true)
            return
        }

        if rel.isEmpty { rel = "index.html" }
        let file = root.appendingPathComponent(rel).standardizedFileURL
        guard file.path.hasPrefix(root.standardizedFileURL.path) else {
            urlSchemeTask.didFailWithError(URLError(.badURL)); return
        }
        guard let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist)); return
        }
        let mime = mimeType(for: file)
        let headers = [
            "Content-Type": mime,
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Origin": "*",
        ]
        guard let response = HTTPURLResponse(url: url, statusCode: 200,
                                             httpVersion: "HTTP/1.1", headerFields: headers) else {
            urlSchemeTask.didFailWithError(URLError(.unknown)); return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        lock.lock()
        defer { lock.unlock() }
        if let dataTask = activeTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask)) {
            dataTask.cancel()
        }
    }

    private func proxyAPI(urlSchemeTask: WKURLSchemeTask, url: URL, retry401: Bool) {
        // Build backend URL: apiBase + "/api/..." (path already starts with /api).
        // NB: URL.path strips trailing slashes, which breaks Django Ninja
        // routes that distinguish `/foo/` (collection) from `/foo` (matches
        // `/<int:id>`) — the latter caused 422 on the layer-assets endpoint.
        // Reconstruct path+query from URLComponents so the trailing slash is
        // preserved verbatim.
        let pathAndQuery: String = {
            let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let p = comps?.percentEncodedPath ?? url.path
            let q = comps?.percentEncodedQuery ?? url.query
            if let q, !q.isEmpty { return p + "?" + q }
            return p
        }()
        guard let backendURL = URL(string: apiBase + pathAndQuery) else {
            urlSchemeTask.didFailWithError(URLError(.badURL)); return
        }

        var req = URLRequest(url: backendURL)
        let incoming = urlSchemeTask.request
        req.httpMethod = incoming.httpMethod ?? "GET"
        req.httpBody = incoming.httpBody
        // Copy relevant headers from the fetch (Content-Type, Accept).
        if let headers = incoming.allHTTPHeaderFields {
            for (k, v) in headers {
                let lk = k.lowercased()
                // Never forward Authorization/Cookie from the page — we set our own Bearer.
                if lk == "authorization" || lk == "cookie" { continue }
                req.setValue(v, forHTTPHeaderField: k)
            }
        }
        if let token = AppShared.auth.auth?.access_token, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let session = URLSession.shared
        let task = session.dataTask(with: req) { [weak self] data, response, error in
            guard let self else { return }

            self.lock.lock()
            self.activeTasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))
            self.lock.unlock()

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return  // stop() already called
            }

            guard let http = response as? HTTPURLResponse else {
                urlSchemeTask.didFailWithError(error ?? URLError(.unknown))
                return
            }

            // On 401, try one refresh + retry.
            if http.statusCode == 401, retry401,
               let refresh = AppShared.auth.auth?.refresh_token, !refresh.isEmpty {
                Task {
                    let ok = (try? await self.refreshToken(refresh)) ?? false
                    if ok {
                        self.proxyAPI(urlSchemeTask: urlSchemeTask, url: url, retry401: false)
                    } else {
                        self.sendResponse(urlSchemeTask, http: http, data: data ?? Data(), url: url)
                    }
                }
                return
            }

            self.sendResponse(urlSchemeTask, http: http, data: data ?? Data(), url: url)
        }

        lock.lock()
        activeTasks[ObjectIdentifier(urlSchemeTask)] = task
        lock.unlock()
        task.resume()
    }

    private func sendResponse(_ urlSchemeTask: WKURLSchemeTask, http: HTTPURLResponse, data: Data, url: URL) {
        // Rebuild response against our canwa:// URL so WebKit treats it as same-origin.
        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields {
            guard let ks = k as? String, let vs = v as? String else { continue }
            // Strip CORS/Cookie headers that don't make sense here.
            let lk = ks.lowercased()
            if lk.hasPrefix("access-control-") || lk == "set-cookie" { continue }
            headers[ks] = vs
        }
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Content-Length"] = "\(data.count)"
        guard let response = HTTPURLResponse(url: url, statusCode: http.statusCode,
                                             httpVersion: "HTTP/1.1", headerFields: headers) else {
            urlSchemeTask.didFailWithError(URLError(.unknown)); return
        }
        urlSchemeTask.didReceive(response)
        if !data.isEmpty { urlSchemeTask.didReceive(data) }
        urlSchemeTask.didFinish()
    }

    private func refreshToken(_ refresh: String) async throws -> Bool {
        guard let url = URL(string: apiBase + "/api/auth/mobile/refresh") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refresh])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let access = json["access_token"] as? String
        else { return false }
        AppShared.auth.updateAccessToken(access)
        return true
    }

    private func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "text/html; charset=utf-8"
        case "js", "mjs":   return "application/javascript; charset=utf-8"
        case "css":         return "text/css; charset=utf-8"
        case "json":        return "application/json; charset=utf-8"
        case "svg":         return "image/svg+xml"
        case "png":         return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif":         return "image/gif"
        case "webp":        return "image/webp"
        case "wasm":        return "application/wasm"
        case "woff2":       return "font/woff2"
        case "woff":        return "font/woff"
        case "ttf":         return "font/ttf"
        default:            return "application/octet-stream"
        }
    }
}

// ============================================================
// MARK: - Root
// ============================================================

struct RootView: View {
    @EnvironmentObject var authStore: AuthStore

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea().background(TransparentWindow())
            if let auth = authStore.auth {
                ZStack(alignment: .bottomLeading) {
                    CanwaWebView(
                        token: auth.access_token,
                        apiBase: Config.apiBase,
                        onRequestLogout: { authStore.clear() }
                    )
                    .ignoresSafeArea()

                    // Thin invisible drag strip at the very top (14 px). Easy
                    // to grab at the window edge without covering the bulk of
                    // the React toolbar (44 px tall) below.
                    VStack(spacing: 0) {
                        WindowDragHandle()
                            .frame(height: 14)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()

                    LogoutBadge(username: auth.username, onLogout: { authStore.clear() })
                        .padding(10)
                }
            } else {
                LoginView()
            }
        }
        .frame(minWidth: 1100, minHeight: 720)
    }
}

struct LogoutBadge: View {
    let username: String?
    let onLogout: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 6) {
            if let name = username {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(T.text3)
            }
            Button(action: onLogout) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 10))
                    .foregroundStyle(T.text3)
            }
            .buttonStyle(.plain)
            .help("Abmelden (⇧⌘Q)")
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Color.black.opacity(hover ? 0.6 : 0.35))
        .clipShape(Capsule())
        .opacity(hover ? 0.95 : 0.5)
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
    }
}

// Invisible strip at top of window that lets the user drag the window —
// WKWebView otherwise swallows all mouse events.
final class DragHandleNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragHandleNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

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
            w.hasShadow = true
            w.isMovableByWindowBackground = true
            // Hide the traffic-light buttons to match Kanban/Zeit look.
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

@main
struct CanwaApp: App {
    // Use the shared singleton so SchemeHandler sees token updates.
    @StateObject private var auth = AppShared.auth

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("Account") {
                Button("Abmelden") { AppShared.auth.clear() }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
            }
        }
    }
}
