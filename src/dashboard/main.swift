// Claude Dashboard — Native SwiftUI
// Cards from ~/.config/dashboard/cards.json

import SwiftUI
import AVKit
import AVFoundation

// ============================================================
// MARK: - Data
// ============================================================

struct DashCard: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var content: String
    var icon: String
    var color: String
    var type: String?
    var items: [String]?
    var metric: String?
    var sub: String?
    var emoji: String?
    var details: [String]?
    var images: [String]?
    var chartData: [Double]? // kept for future, details[] used for chart points
    var column: Int?  // grid column (0-15)
    var timestamp: String?  // ISO timestamp for data freshness
    var size: String?  // "compact", "default" (nil), "expanded"
    var span: Int?  // column span 1-16, default 1
    var row: Int?  // grid row 0-8
    var rowSpan: Int?  // row span 1-9, default 1
    var videoId: String?  // YouTube video id for type:"youtube"
    var streamUrl: String?  // Resolved HLS/MP4 stream for AVPlayer
    var kanbanBoard: String?  // "work" or "private" for type:"kanban"

    static func == (lhs: DashCard, rhs: DashCard) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.content == rhs.content
            && lhs.metric == rhs.metric && lhs.emoji == rhs.emoji
            && lhs.images == rhs.images && lhs.size == rhs.size && lhs.span == rhs.span
            && lhs.row == rhs.row && lhs.rowSpan == rhs.rowSpan
            && lhs.videoId == rhs.videoId && lhs.streamUrl == rhs.streamUrl
            && lhs.kanbanBoard == rhs.kanbanBoard && lhs.items == rhs.items
    }
}

struct DashData: Codable {
    var cards: [DashCard]
    var schemaVersion: Int?   // nil/1 = legacy 16×9 grid; 2 = 32×18 grid
}
let kPath = NSHomeDirectory() + "/.config/dashboard/cards.json"

// ============================================================
// MARK: - Theme
// ============================================================

struct T {
    static let bg = Color(red: 0.06, green: 0.055, blue: 0.08)
    static let card = Color(white: 0.10)
    static let cardHover = Color(white: 0.12)
    static let header = Color(white: 0.08)
    static let text1 = Color.white.opacity(0.92)
    static let text2 = Color.white.opacity(0.50)
    static let text3 = Color.white.opacity(0.28)
    static let line = Color.white.opacity(0.06)

    static func c(_ name: String) -> Color {
        switch name {
        case "lavender": return Color(red: 0.50, green: 0.47, blue: 0.62)
        case "gold":     return Color(red: 0.65, green: 0.57, blue: 0.40)
        case "teal":     return Color(red: 0.40, green: 0.52, blue: 0.48)
        case "rose":     return Color(red: 0.60, green: 0.42, blue: 0.42)
        case "blue":     return Color(red: 0.42, green: 0.52, blue: 0.65)
        case "amber":    return Color(red: 0.65, green: 0.55, blue: 0.35)
        case "purple":   return Color(red: 0.52, green: 0.44, blue: 0.60)
        case "cyan":     return Color(red: 0.42, green: 0.55, blue: 0.53)
        case "red":      return Color(red: 0.62, green: 0.35, blue: 0.33)
        case "green":    return Color(red: 0.35, green: 0.55, blue: 0.40)
        case "orange":   return Color(red: 0.65, green: 0.48, blue: 0.30)
        default:         return Color(red: 0.50, green: 0.47, blue: 0.62)
        }
    }
}

// ============================================================
// MARK: - Sparkline Chart
// ============================================================

struct SparklineView: View {
    let data: [Double]
    let color: Color
    var showAxis: Bool = false

    var body: some View {
        GeometryReader { geo in
            let leftPad: CGFloat = showAxis ? 48 : 0
            let w = geo.size.width - leftPad
            let h = geo.size.height
            let mn = data.min() ?? 0
            let mx = data.max() ?? 1
            let range = mx - mn > 0 ? mx - mn : 1

            // Y-axis labels
            if showAxis {
                let steps = 4
                ForEach(0...steps, id: \.self) { i in
                    let val = mn + range * Double(i) / Double(steps)
                    let y = h - (h * CGFloat(Double(i)) / CGFloat(steps))
                    // Grid line
                    Path { p in p.move(to: CGPoint(x: leftPad, y: y)); p.addLine(to: CGPoint(x: leftPad + w, y: y)) }
                        .stroke(T.line, lineWidth: 0.5)
                    // Label
                    Text(val >= 1000 ? String(format: "%.0f", val) : String(format: "%.1f", val))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .position(x: 22, y: y)
                }
            }

            // Line
            Path { path in
                for (i, val) in data.enumerated() {
                    let x = leftPad + w * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                    let y = h - (h * CGFloat(val - mn) / CGFloat(range))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color.opacity(0.8), lineWidth: showAxis ? 1.5 : 1.2)

            // Gradient fill
            Path { path in
                for (i, val) in data.enumerated() {
                    let x = leftPad + w * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                    let y = h - (h * CGFloat(val - mn) / CGFloat(range))
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                path.addLine(to: CGPoint(x: leftPad + w, y: h))
                path.addLine(to: CGPoint(x: leftPad, y: h))
                path.closeSubpath()
            }
            .fill(LinearGradient(colors: [color.opacity(0.15), color.opacity(0.0)], startPoint: .top, endPoint: .bottom))
        }
    }
}

struct InteractiveChartView: View {
    let data: [Double]
    let color: Color
    @State private var hoverIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let leftPad: CGFloat = 48
            let w = geo.size.width - leftPad
            let h = geo.size.height
            let mn = data.min() ?? 0
            let mx = data.max() ?? 1
            let range = mx - mn > 0 ? mx - mn : 1
            let steps = 4

            ZStack(alignment: .topLeading) {
                // Grid + labels
                ForEach(0...steps, id: \.self) { i in
                    let val = mn + range * Double(i) / Double(steps)
                    let y = h - (h * CGFloat(Double(i)) / CGFloat(steps))
                    Path { p in p.move(to: CGPoint(x: leftPad, y: y)); p.addLine(to: CGPoint(x: leftPad + w, y: y)) }
                        .stroke(T.line, lineWidth: 0.5)
                    Text(val >= 1000 ? String(format: "%.0f", val) : String(format: "%.2f", val))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .position(x: 22, y: y)
                }

                // Line
                Path { path in
                    for (i, val) in data.enumerated() {
                        let x = leftPad + w * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                        let y = h - (h * CGFloat(val - mn) / CGFloat(range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color.opacity(0.8), lineWidth: 1.5)

                // Fill
                Path { path in
                    for (i, val) in data.enumerated() {
                        let x = leftPad + w * CGFloat(i) / CGFloat(max(data.count - 1, 1))
                        let y = h - (h * CGFloat(val - mn) / CGFloat(range))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: leftPad + w, y: h))
                    path.addLine(to: CGPoint(x: leftPad, y: h))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [color.opacity(0.15), color.opacity(0.0)], startPoint: .top, endPoint: .bottom))

                // Hover crosshair
                if let idx = hoverIndex, idx >= 0, idx < data.count {
                    let val = data[idx]
                    let x = leftPad + w * CGFloat(idx) / CGFloat(max(data.count - 1, 1))
                    let y = h - (h * CGFloat(val - mn) / CGFloat(range))

                    // Vertical line
                    Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)) }
                        .stroke(T.text3, style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))

                    // Dot
                    Circle().fill(color).frame(width: 6, height: 6)
                        .position(x: x, y: y)

                    // Value tooltip
                    Text(String(format: "%.2f", val))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(T.text1)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 0).fill(T.header))
                        .position(x: x, y: max(16, y - 20))
                }

                // Hover tracking area
                Color.clear.contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { v in
                                let x = v.location.x - leftPad
                                let idx = Int(round(x / w * CGFloat(data.count - 1)))
                                hoverIndex = max(0, min(data.count - 1, idx))
                            }
                            .onEnded { _ in hoverIndex = nil }
                    )
            }
        }
    }
}

// ============================================================
// MARK: - YouTube Player (AVPlayer + yt-dlp resolved stream)
// ============================================================

// Keeps AVPlayer instances alive across view rebuilds so playback survives
// drag-drop reorders, card resizes, and window focus changes.
final class PlayerRegistry {
    static let shared = PlayerRegistry()
    private struct Entry { let url: String; let player: AVPlayer }
    private var entries: [String: Entry] = [:]

    func player(for cardId: String, url: String) -> AVPlayer? {
        guard let u = URL(string: url) else { return nil }
        if let e = entries[cardId], e.url == url { return e.player }
        entries[cardId]?.player.pause()
        let p = AVPlayer(url: u)
        p.automaticallyWaitsToMinimizeStalling = true
        entries[cardId] = Entry(url: url, player: p)
        return p
    }

    func release(cardId: String) {
        entries[cardId]?.player.pause()
        entries.removeValue(forKey: cardId)
    }
}

struct YouTubePlayerView: NSViewRepresentable {
    let cardId: String
    let streamUrl: String?

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .inline
        v.showsFullScreenToggleButton = true
        v.videoGravity = .resizeAspect
        if #available(macOS 13.0, *) {
            v.allowsVideoFrameAnalysis = false
        }
        apply(v)
        return v
    }

    func updateNSView(_ v: AVPlayerView, context: Context) {
        apply(v)
    }

    private func apply(_ v: AVPlayerView) {
        guard let s = streamUrl, !s.isEmpty else {
            v.player = nil
            return
        }
        let p = PlayerRegistry.shared.player(for: cardId, url: s)
        if v.player !== p { v.player = p }
    }
}

// ============================================================
// MARK: - TV App Button (uses TVIconCache)
// ============================================================

struct TVAppButton: View {
    let appId: String
    let label: String
    let fallback: String
    let tint: Color
    let action: () -> Void
    @StateObject private var icons = TVIconCache.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    if let img = icons.image(for: appId) {
                        Image(nsImage: img)
                            .resizable()
                            .interpolation(.high)
                            .aspectRatio(contentMode: .fit)
                            .padding(4)
                    } else {
                        Image(systemName: fallback)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                }
                .frame(width: 40, height: 40)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .id(icons.version)

                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(T.text2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: 60)
            .background(Color.white.opacity(0.03))
            .overlay(Rectangle().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear { icons.load(id: appId, title: label) }
    }
}

// ============================================================
// MARK: - Card Presets
// ============================================================

struct CardPreset {
    let label: String
    let span: Int
    let rowSpan: Int
    let size: String?
}

func cardPresets(_ type: String) -> [CardPreset] {
    switch type {
    case "weather":
        return [.init(label: "S", span: 6, rowSpan: 4, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 6, size: nil),
                .init(label: "L", span: 12, rowSpan: 8, size: "expanded")]
    case "forecast":
        return [.init(label: "S", span: 10, rowSpan: 4, size: "compact"),
                .init(label: "M", span: 16, rowSpan: 4, size: nil),
                .init(label: "L", span: 32, rowSpan: 6, size: "expanded")]
    case "stock":
        return [.init(label: "S", span: 6, rowSpan: 4, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 6, size: nil),
                .init(label: "L", span: 12, rowSpan: 8, size: "expanded")]
    case "metric":
        return [.init(label: "S", span: 6, rowSpan: 4, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 4, size: nil),
                .init(label: "L", span: 12, rowSpan: 6, size: "expanded")]
    case "list":
        return [.init(label: "S", span: 6, rowSpan: 6, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 8, size: nil),
                .init(label: "L", span: 12, rowSpan: 12, size: "expanded")]
    case "image":
        return [.init(label: "S", span: 6, rowSpan: 6, size: "compact"),
                .init(label: "M", span: 10, rowSpan: 8, size: nil),
                .init(label: "L", span: 16, rowSpan: 10, size: "expanded")]
    case "youtube":
        return [.init(label: "S", span: 8, rowSpan: 6, size: "compact"),
                .init(label: "M", span: 12, rowSpan: 8, size: nil),
                .init(label: "L", span: 16, rowSpan: 12, size: "expanded")]
    case "photo":
        return [.init(label: "S", span: 6, rowSpan: 6, size: "compact"),
                .init(label: "M", span: 10, rowSpan: 8, size: nil),
                .init(label: "L", span: 16, rowSpan: 12, size: "expanded")]
    case "kanban":
        return [.init(label: "S", span: 6, rowSpan: 8, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 12, size: nil),
                .init(label: "L", span: 12, rowSpan: 18, size: "expanded")]
    case "system":
        return [.init(label: "S", span: 6, rowSpan: 4, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 6, size: nil),
                .init(label: "L", span: 12, rowSpan: 8, size: "expanded")]
    case "tv":
        return [.init(label: "S", span: 6, rowSpan: 6, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 8, size: nil),
                .init(label: "L", span: 12, rowSpan: 10, size: "expanded")]
    default:
        return [.init(label: "S", span: 6, rowSpan: 4, size: "compact"),
                .init(label: "M", span: 8, rowSpan: 6, size: nil),
                .init(label: "L", span: 12, rowSpan: 10, size: "expanded")]
    }
}

func defaultPresetIndex(_ type: String) -> Int {
    return 1  // M is the new default — maps to old default card size on the 16×9 grid
}

// ============================================================
// MARK: - Card View
// ============================================================

struct CardView: View {
    let card: DashCard
    var onClose: (() -> Void)? = nil
    var onRefresh: (() -> Void)? = nil
    var onDoubleTap: (() -> Void)? = nil
    var onPreset: ((Int, Int, String?) -> Void)? = nil
    var onKanbanBoard: ((String) -> Void)? = nil
    var sysStats: SystemStats = SystemStats()
    @State private var hov = false
    @State private var dragOffset: CGFloat = 0
    @State private var refreshFlash: Bool = false

    var col: Color { T.c(card.color) }
    var ct: String { card.type ?? "info" }
    var cSize: String { card.size ?? "default" }
    var isCompact: Bool { cSize == "compact" }
    var isExpanded: Bool { cSize == "expanded" }
    var effectiveSpan: Int { max(1, min(32, card.span ?? ((card.size ?? "") == "wide" ? 2 : 1))) }
    var effectiveRowSpan: Int { max(1, min(18, card.rowSpan ?? 1)) }
    var isWide: Bool { effectiveSpan > 1 }

    // Opaque for video/photo where transparency would compete with content
    var isOpaqueType: Bool { ct == "youtube" || ct == "photo" }

    @ViewBuilder
    var cardBackground: some View {
        if isOpaqueType {
            Rectangle().fill(Color.black)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(hov ? 0.62 : 0.45)
        }
    }

    @ViewBuilder
    var headerBackground: some View {
        if isOpaqueType {
            Rectangle().fill(Color.black.opacity(0.55))
        } else {
            ZStack {
                Rectangle().fill(.ultraThinMaterial).opacity(0.55)
                Rectangle().fill(Color.black.opacity(0.12))
            }
        }
    }

    func formatTimestamp(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fmt.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let d = date else { return iso }
        let diff = Date().timeIntervalSince(d)
        if diff < 60 { return "gerade eben" }
        if diff < 3600 { return "vor \(Int(diff/60))m" }
        if diff < 86400 { return "vor \(Int(diff/3600))h" }
        return "vor \(Int(diff/86400))T"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Accent line
            col.opacity(0.4).frame(height: 1.5)

            // Header
            HStack(spacing: 7) {
                // Drag grip (visible on hover)
                if hov {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(T.text3)
                        .frame(width: 14)
                        .transition(.opacity)
                }
                Image(systemName: card.icon)
                    .font(.system(size: isCompact ? 9 : (isExpanded ? 11 : 10), weight: .medium))
                    .foregroundStyle(T.text3)
                Text(card.title)
                    .font(.system(size: isCompact ? 10.5 : (isExpanded ? 12 : 11), weight: .semibold))
                    .foregroundStyle(T.text1)
                    .lineLimit(1)
                Spacer()
                if let sub = card.sub {
                    Text(sub)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.04))
                }
                if hov, let close = onClose {
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(T.text3)
                            .frame(width: 16, height: 16)
                            .background(Color.white.opacity(0.06))
                    }.buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, isCompact ? 10 : (isExpanded ? 14 : 12))
            .padding(.vertical, isCompact ? 6 : (isExpanded ? 9 : 7))
            .background(headerBackground)

            // Body
            Group {
                switch ct {
                case "metric":   metricBody
                case "stock":    stockBody
                case "list":     listBody
                case "kanban":   kanbanBody
                case "system":   systemBody
                case "tv":       tvBody
                case "weather":  weatherBody
                case "forecast": forecastBody
                case "image":    imageBody
                case "youtube":  youtubeBody
                case "photo":    photoBody
                default:         infoBody
                }
            }
            .padding(.horizontal, (ct == "youtube" || ct == "photo") ? 0 : (isCompact ? 10 : (isExpanded ? 14 : 12)))
            .padding(.top, (ct == "youtube" || ct == "photo") ? 0 : (isCompact ? 8 : (isExpanded ? 14 : 10)))
            .padding(.bottom, (ct == "youtube" || ct == "photo") ? 0 : ((card.timestamp != nil || hov) ? 4 : (isCompact ? 8 : 12)))

            Spacer(minLength: 0)

            // Timestamp footer + Resize handle
            HStack(spacing: 0) {
                if let ts = card.timestamp {
                    Image(systemName: "clock")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(T.text3)
                    Text(formatTimestamp(ts))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(T.text3)
                        .padding(.leading, 3)
                }
                Spacer()
                // Resize indicator — visible on hover
                if hov {
                    HStack(spacing: 4) {
                        let presets = cardPresets(ct)
                        ForEach(Array(presets.enumerated()), id: \.offset) { _, p in
                            let active = effectiveSpan == p.span && effectiveRowSpan == p.rowSpan
                            Button(action: { onPreset?(p.span, p.rowSpan, p.size) }) {
                                Text(p.label)
                                    .font(.system(size: 9, weight: active ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(active ? col : T.text3)
                                    .frame(width: 18, height: 18)
                                    .background(active ? col.opacity(0.2) : Color.white.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, isCompact ? 10 : (isExpanded ? 14 : 12))
            .padding(.bottom, (card.timestamp != nil || hov) ? (isCompact ? 5 : 7) : 0)
        }
        .background(cardBackground)
        .overlay(
            Rectangle()
                .stroke(col.opacity(refreshFlash ? 0.9 : 0), lineWidth: 2)
        )
        .clipShape(Rectangle())
        .shadow(color: .black.opacity(hov ? 0.35 : 0.15), radius: hov ? 10 : 4, y: hov ? 4 : 2)
        .scaleEffect(hov ? 1.012 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: hov)
        .animation(.easeOut(duration: 0.35), value: refreshFlash)
        .onHover { h in hov = h }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded { onDoubleTap?() }
        )
        .simultaneousGesture(
            TapGesture(count: 3).onEnded {
                onRefresh?()
                refreshFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    refreshFlash = false
                }
            }
        )
    }

    // ── Info ────────────────────────────
    var infoBody: some View {
        Text(card.content)
            .font(.system(size: isCompact ? 11 : (isExpanded ? 14 : 12), weight: .regular))
            .foregroundStyle(T.text2)
            .lineSpacing(isExpanded ? 7 : 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // ── Metric ─────────────────────────
    var metricBody: some View {
        let content = card.content
        let pct = content.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "") ?? ""
        let secondary = content.components(separatedBy: "\n").last ?? ""
        let up = content.contains("↑")
        let down = content.contains("↓")
        return GeometryReader { geo in
            let valueSize = max(18, min(geo.size.height * 0.42, isCompact ? 26 : (isExpanded ? 54 : 38)))
            let logoSize = valueSize * 0.85
            VStack(alignment: .leading, spacing: 0) {
                // Top zone: icon + hero metric
                HStack(alignment: .center, spacing: isCompact ? 8 : 12) {
                    if let imgs = card.images, let first = imgs.first, !first.isEmpty {
                        AsyncImage(url: URL(string: first)) { phase in
                            if case .success(let img) = phase {
                                img.resizable().aspectRatio(contentMode: .fit)
                                    .frame(width: logoSize, height: logoSize)
                                    .clipShape(Rectangle())
                                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                            }
                        }
                    }
                    Text(card.metric ?? "—")
                        .font(.system(size: valueSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(T.text1)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 6)
                // Bottom zone: change + secondary
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    HStack(spacing: 4) {
                        if up {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: isExpanded ? 14 : (isCompact ? 9 : 11), weight: .bold))
                                .foregroundStyle(T.c("green"))
                        } else if down {
                            Image(systemName: "arrow.down.right")
                                .font(.system(size: isExpanded ? 14 : (isCompact ? 9 : 11), weight: .bold))
                                .foregroundStyle(T.c("red"))
                        }
                        if !pct.isEmpty {
                            Text(pct)
                                .font(.system(size: isExpanded ? 18 : (isCompact ? 11 : 14), weight: .semibold, design: .monospaced))
                                .foregroundStyle(up ? T.c("green") : (down ? T.c("red") : T.text2))
                        }
                    }
                    Spacer(minLength: 0)
                    if !secondary.isEmpty && secondary != content {
                        Text(secondary)
                            .font(.system(size: isExpanded ? 12 : (isCompact ? 9 : 10.5)))
                            .foregroundStyle(T.text3)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // ── Stock (metric + sparkline chart) ──
    var stockBody: some View {
        let content = card.content
        let pct = content.components(separatedBy: "(").last?.replacingOccurrences(of: ")", with: "") ?? ""
        let points = (card.details ?? []).compactMap { Double($0) }
        return VStack(alignment: .leading, spacing: isExpanded ? 12 : (isCompact ? 6 : 8)) {
            // Price row
            HStack(spacing: 0) {
                if let imgs = card.images, let first = imgs.first, !first.isEmpty {
                    AsyncImage(url: URL(string: first)) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fit)
                                .frame(width: isExpanded ? 36 : (isCompact ? 22 : 28), height: isExpanded ? 36 : (isCompact ? 22 : 28))
                                .clipShape(Rectangle())
                        }
                    }.padding(.trailing, isCompact ? 6 : 10)
                }
                Text(card.metric ?? "—")
                    .font(.system(size: isCompact ? 18 : (isExpanded ? 32 : 24), weight: .semibold, design: .rounded))
                    .foregroundStyle(T.text1)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer()
                if !pct.isEmpty {
                    Text(pct)
                        .font(.system(size: isExpanded ? 16 : (isCompact ? 11 : 13), weight: .semibold, design: .monospaced))
                        .foregroundStyle(content.contains("↑") ? T.c("green") : T.c("red"))
                }
            }

            // Sparkline chart — stretches to fill remaining space (also in compact)
            if points.count > 2 {
                SparklineView(data: points, color: col)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: isCompact ? 28 : 50)
            }

            // Hi/Lo range in expanded mode
            if isExpanded, points.count > 2 {
                if let mn = points.min(), let mx = points.max() {
                    HStack {
                        Text("LOW").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(T.text3)
                        Text(String(format: "%.2f", mn))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(T.text2)
                        Spacer()
                        Text("HIGH").font(.system(size: 9, weight: .semibold, design: .monospaced)).foregroundStyle(T.text3)
                        Text(String(format: "%.2f", mx))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(T.text2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // ── Forecast (5-day weather columns) ──
    var forecastBody: some View {
        let maxDays = 5  // always show all 5 days
        let emojiSize: CGFloat = isExpanded ? 36 : (isCompact ? 20 : 26)
        let tempSize: CGFloat = isExpanded ? 17 : (isCompact ? 12 : 14)
        return HStack(spacing: 0) {
            if let details = card.details {
                ForEach(Array(details.prefix(maxDays).enumerated()), id: \.offset) { idx, d in
                    let p = d.components(separatedBy: "|")
                    let emoji = p.count > 0 ? p[0] : "🌡"
                    let day = p.count > 1 ? p[1] : "?"
                    let lo = p.count > 2 ? p[2] : ""
                    let hi = p.count > 3 ? p[3] : ""
                    let rain = p.count > 4 ? p[4] : "0"

                    VStack(spacing: 0) {
                        Text(day)
                            .font(.system(size: isExpanded ? 12 : 10, weight: .semibold))
                            .foregroundStyle(idx == 0 ? T.text1 : T.text3)
                        Spacer(minLength: 4)
                        Text(emoji)
                            .font(.system(size: emojiSize))
                        Spacer(minLength: 2)
                        Text("\(hi)°")
                            .font(.system(size: tempSize, weight: .semibold, design: .monospaced))
                            .foregroundStyle(T.text1)
                        Text("\(lo)°")
                            .font(.system(size: tempSize - 2, weight: .regular, design: .monospaced))
                            .foregroundStyle(T.text3)
                        Spacer(minLength: 4)
                        if rain != "0" {
                            HStack(spacing: 2) {
                                Image(systemName: "drop.fill")
                                    .font(.system(size: 7))
                                    .foregroundStyle(T.c("blue").opacity(0.6))
                                Text("\(rain)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(T.text3)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    if idx < min(details.count, maxDays) - 1 {
                        T.line.frame(maxHeight: .infinity)
                            .frame(width: 0.5)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── List ───────────────────────────
    var listBody: some View {
        let items = card.items ?? card.content.components(separatedBy: "\n")
        let fontSize: CGFloat = isCompact ? 10 : (isExpanded ? 12.5 : 11)
        let vPad: CGFloat = isExpanded ? 8 : 6
        // Rough per-row height estimate: two lines of text + vertical padding + divider
        let rowH: CGFloat = (fontSize * (isExpanded ? 3 : 2) * 1.3) + vPad * 2 + 0.5
        return GeometryReader { geo in
            let possibleRows = max(1, Int(floor(geo.size.height / rowH)))
            let maxItems = min(items.count, possibleRows)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.prefix(maxItems).enumerated()), id: \.offset) { idx, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(idx + 1)")
                            .font(.system(size: isExpanded ? 10 : 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(col.opacity(0.45))
                            .frame(width: 14, alignment: .trailing)
                        Text(item)
                            .font(.system(size: fontSize, weight: .regular))
                            .foregroundStyle(T.text2)
                            .lineLimit(isExpanded ? 3 : 2)
                            .lineSpacing(2)
                        Spacer()
                    }
                    .padding(.vertical, vPad)
                    if idx < maxItems - 1 {
                        T.line.frame(height: 0.5).padding(.leading, 24)
                    }
                }
                if items.count > maxItems {
                    Text("+\(items.count - maxItems) weitere")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(T.text3)
                        .padding(.top, 6)
                        .padding(.leading, 24)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // ── System (live CPU/RAM/Disk) ──
    func metricBar(_ label: String, _ value: Double, _ detail: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(T.text3)
                Spacer()
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(T.text1)
                Text(detail)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(T.text3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color.white.opacity(0.06))
                    Rectangle()
                        .fill(LinearGradient(colors: [color.opacity(0.85), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(max(0, min(value / 100, 1))))
                }
            }
            .frame(height: 4)
        }
    }

    var systemBody: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : (isCompact ? 6 : 10)) {
            metricBar(
                "CPU", sysStats.cpu,
                "",
                sysStats.cpu > 80 ? T.c("red") : (sysStats.cpu > 50 ? T.c("amber") : T.c("green"))
            )
            metricBar(
                "RAM", sysStats.ram,
                "\(formatBytes(sysStats.ramUsed)) / \(formatBytes(sysStats.ramTotal))",
                sysStats.ram > 85 ? T.c("red") : T.c("blue")
            )
            metricBar(
                "DISK", sysStats.disk,
                "\(formatBytes(sysStats.diskTotal - sysStats.diskFree)) / \(formatBytes(sysStats.diskTotal))",
                sysStats.disk > 90 ? T.c("red") : T.c("purple")
            )
            if sysStats.cpuHistory.count > 2 {
                SparklineView(data: sysStats.cpuHistory, color: col)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(minHeight: isCompact ? 24 : 36)
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // ── TV Remote (shell out to ~/.local/bin/tv) ──
    private func runTV(_ args: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let bin = NSHomeDirectory() + "/.local/bin/tv"
            let cmd = ([bin] + args).map { "'\($0)'" }.joined(separator: " ")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", cmd]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = NSHomeDirectory() + "/.local/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
            proc.environment = env
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
        }
    }

    private func tvIconBtn(icon: String, tint: Color, size: CGFloat, args: [String]) -> some View {
        Button(action: { runTV(args) }) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: size + 14)
                .background(tint.opacity(0.12))
                .overlay(Rectangle().stroke(tint.opacity(0.35), lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func tvAppBtn(appId: String, label: String, fallback: String, tint: Color, args: [String]) -> some View {
        TVAppButton(appId: appId, label: label, fallback: fallback, tint: tint) {
            runTV(args)
        }
    }

    var tvBody: some View {
        let green = T.c("green")
        let red = T.c("red")
        let amber = T.c("amber")
        let blue = T.c("blue")
        let purple = T.c("purple")
        return GeometryReader { geo in
            let rowCount: CGFloat = 3  // always power+mute, volume, apps
            let iconSize: CGFloat = max(12, min(26, geo.size.height / rowCount * 0.34))
            VStack(spacing: 6) {
                // Power + mute row
                HStack(spacing: 6) {
                    tvIconBtn(icon: "power", tint: green, size: iconSize, args: ["on"])
                    tvIconBtn(icon: "power.circle", tint: red, size: iconSize, args: ["off"])
                    tvIconBtn(icon: "speaker.slash.fill", tint: amber, size: iconSize, args: ["mute"])
                }
                // Volume row
                HStack(spacing: 6) {
                    tvIconBtn(icon: "speaker.wave.1.fill", tint: T.text2, size: iconSize, args: ["vol", "down"])
                    tvIconBtn(icon: "speaker.wave.3.fill", tint: T.text2, size: iconSize, args: ["vol", "up"])
                }
                // Apps — single row with real LG TV icons
                HStack(spacing: 6) {
                    tvAppBtn(appId: "youtube.leanback.v4", label: "YouTube", fallback: "play.rectangle.fill", tint: red, args: ["open", "youtube"])
                    tvAppBtn(appId: "tv.twitch.tv.starshot.lg", label: "Twitch", fallback: "gamecontroller.fill", tint: purple, args: ["open", "twitch"])
                    tvAppBtn(appId: "netflix", label: "Netflix", fallback: "film.fill", tint: red, args: ["open", "netflix"])
                    tvAppBtn(appId: "com.netrtl.tvnow", label: "RTL+", fallback: "tv.fill", tint: blue, args: ["open", "rtl"])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // ── Kanban (segmented toggle + list) ──
    var kanbanBody: some View {
        let currentBoard = card.kanbanBoard ?? "work"
        return VStack(alignment: .leading, spacing: isExpanded ? 12 : 8) {
            HStack(spacing: 0) {
                ForEach([("work", "Arbeit"), ("private", "Privat")], id: \.0) { b, label in
                    let active = currentBoard == b
                    Button(action: { onKanbanBoard?(b) }) {
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(active ? T.text1 : T.text3)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(active ? col.opacity(0.35) : Color.white.opacity(0.04))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(Rectangle())
            listBody
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // ── Image Grid ─────────────────────
    var imageBody: some View {
        let urls = card.images ?? []
        return GeometryReader { geo in
            let colCount = isCompact ? 2 : (isExpanded ? 3 : 3)
            let spacing: CGFloat = 4
            let cellW = (geo.size.width - spacing * CGFloat(colCount - 1)) / CGFloat(max(1, colCount))
            let cellH = cellW  // square tiles
            let rowsPossible = max(1, Int(floor((geo.size.height + spacing) / (cellH + spacing))))
            let maxImgs = min(urls.count, colCount * rowsPossible)
            let cols = Array(repeating: GridItem(.fixed(cellW), spacing: spacing), count: colCount)
            LazyVGrid(columns: cols, alignment: .leading, spacing: spacing) {
                ForEach(Array(urls.prefix(maxImgs).enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: URL(string: url)) { phase in
                        if case .success(let img) = phase {
                            img.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: cellW, height: cellH)
                                .clipped()
                                .clipShape(Rectangle())
                        } else {
                            Rectangle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: cellW, height: cellH)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // ── YouTube ────────────────────────
    var youtubeBody: some View {
        let id = card.videoId ?? ""
        let stream = card.streamUrl ?? ""
        return Group {
            if stream.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundStyle(T.text3)
                    Text("Stream fehlt")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(T.text2)
                    Text("dash youtube \(id) neu")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(T.text3)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0/9.0, contentMode: .fit)
                .background(Color.black)
            } else {
                YouTubePlayerView(cardId: card.id, streamUrl: stream)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
            }
        }
    }

    // ── Photo ─────────────────────────
    var photoBody: some View {
        Group {
            if let urlStr = card.images?.first,
               let url = URL(string: urlStr),
               let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                T.card.overlay(Image(systemName: "photo").font(.system(size: 24)).foregroundStyle(T.text3))
            }
        }
    }

    // ── Weather ────────────────────────
    var weatherBody: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Hero centered
            VStack(spacing: isExpanded ? 6 : (isCompact ? 2 : 4)) {
                Text(card.emoji ?? "🌡")
                    .font(.system(size: isCompact ? 28 : (isExpanded ? 68 : 48)))
                Text(card.metric ?? "—")
                    .font(.system(size: isCompact ? 22 : (isExpanded ? 44 : 34), weight: .semibold, design: .rounded))
                    .foregroundStyle(T.text1)
                Text(card.content)
                    .font(.system(size: isExpanded ? 14 : (isCompact ? 10 : 12), weight: .medium))
                    .foregroundStyle(T.text2)
            }
            .frame(maxWidth: .infinity)
            Spacer(minLength: 0)

            // Detail strip — anchored to bottom (also in compact)
            if let details = card.details, !details.isEmpty {
                T.line.frame(height: 0.5).padding(.bottom, isExpanded ? 14 : (isCompact ? 6 : 10))
                HStack(spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.offset) { idx, d in
                        let p = d.components(separatedBy: "|")
                        VStack(spacing: isExpanded ? 7 : (isCompact ? 2 : 5)) {
                            Text(p.first ?? "")
                                .font(.system(size: isExpanded ? 10 : (isCompact ? 7.5 : 9), weight: .semibold))
                                .foregroundStyle(T.text3)
                                .textCase(.uppercase)
                                .tracking(0.8)
                            Text(p.count > 1 ? p[1] : "")
                                .font(.system(size: isExpanded ? 17 : (isCompact ? 11 : 14), weight: .semibold, design: .monospaced))
                                .foregroundStyle(T.text1)
                        }
                        .frame(maxWidth: .infinity)
                        if idx < details.count - 1 {
                            T.line.frame(width: 0.5, height: isExpanded ? 38 : (isCompact ? 22 : 30))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// ============================================================
// MARK: - TV Icon Cache (fetches SVG brand logos from LG TV server)
// ============================================================

@MainActor
final class TVIconCache: ObservableObject {
    static let shared = TVIconCache()
    private var cache: [String: NSImage] = [:]
    private var inflight: Set<String> = []
    @Published var version = 0

    func image(for id: String) -> NSImage? { cache[id] }

    func load(id: String, title: String) {
        if cache[id] != nil || inflight.contains(id) { return }
        inflight.insert(id)
        let esc = { (s: String) -> String in
            s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
        }
        guard let url = URL(string: "http://127.0.0.1:8094/icon?id=\(esc(id))&title=\(esc(title))") else {
            inflight.remove(id); return
        }
        Task { [weak self] in
            guard let self else { return }
            defer { Task { @MainActor in self.inflight.remove(id) } }
            do {
                let (data, resp) = try await URLSession.shared.data(from: url)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return }
                if let img = NSImage(data: data) {
                    await MainActor.run {
                        self.cache[id] = img
                        self.version &+= 1
                    }
                }
            } catch { }
        }
    }
}

// ============================================================
// MARK: - System Stats (native Mach / sysctl)
// ============================================================

struct SystemStats: Equatable {
    var cpu: Double = 0        // 0..100
    var ram: Double = 0        // 0..100
    var disk: Double = 0       // 0..100
    var cpuHistory: [Double] = []
    var ramUsed: UInt64 = 0
    var ramTotal: UInt64 = 0
    var diskFree: UInt64 = 0
    var diskTotal: UInt64 = 0
}

final class SystemMonitor {
    static let shared = SystemMonitor()
    private var prevTicks: host_cpu_load_info_data_t?
    private(set) var stats = SystemStats()

    func sample() -> SystemStats {
        let cpu = currentCPU()
        let (rUsed, rTotal) = currentRAM()
        let (dFree, dTotal) = currentDisk()
        var hist = stats.cpuHistory
        hist.append(cpu)
        if hist.count > 60 { hist.removeFirst(hist.count - 60) }
        stats = SystemStats(
            cpu: cpu,
            ram: rTotal > 0 ? Double(rUsed) / Double(rTotal) * 100 : 0,
            disk: dTotal > 0 ? Double(dTotal - dFree) / Double(dTotal) * 100 : 0,
            cpuHistory: hist,
            ramUsed: rUsed,
            ramTotal: rTotal,
            diskFree: dFree,
            diskTotal: dTotal
        )
        return stats
    }

    private func currentCPU() -> Double {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var load = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &load) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        defer { prevTicks = load }
        guard let prev = prevTicks else { return 0 }
        let user = Double(load.cpu_ticks.0 &- prev.cpu_ticks.0)
        let sys  = Double(load.cpu_ticks.1 &- prev.cpu_ticks.1)
        let idle = Double(load.cpu_ticks.2 &- prev.cpu_ticks.2)
        let nice = Double(load.cpu_ticks.3 &- prev.cpu_ticks.3)
        let total = user + sys + idle + nice
        guard total > 0 else { return 0 }
        return ((user + sys + nice) / total) * 100
    }

    private func currentRAM() -> (used: UInt64, total: UInt64) {
        var size = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        var stats = vm_statistics64()
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        var total: UInt64 = 0
        var sz = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &sz, nil, 0)
        return (used, total)
    }

    private func currentDisk() -> (free: UInt64, total: UInt64) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return (0, 0) }
        let total = (attrs[.systemSize] as? NSNumber)?.uint64Value ?? 0
        let free = (attrs[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
        return (free, total)
    }
}

func formatBytes(_ n: UInt64) -> String {
    let gb = Double(n) / 1_073_741_824
    if gb >= 1 { return String(format: "%.1f GB", gb) }
    let mb = Double(n) / 1_048_576
    return String(format: "%.0f MB", mb)
}

// ============================================================
// MARK: - Masonry Layout (manual columns + col spans for wide cards)
// ============================================================

struct ColumnSpanKey: LayoutValueKey {
    static let defaultValue: Int = 1
}
struct PreferredColumnKey: LayoutValueKey {
    static let defaultValue: Int? = nil
}

struct MasonryLayout: Layout {
    let columns: Int
    let spacing: CGFloat

    struct CacheData {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var totalHeight: CGFloat = 0
        var width: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> CacheData { CacheData() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let w = proposal.width ?? 900
        calculate(width: w, subviews: subviews, cache: &cache)
        return CGSize(width: w, height: cache.totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        if cache.width != bounds.width { calculate(width: bounds.width, subviews: subviews, cache: &cache) }
        for (i, sv) in subviews.enumerated() {
            guard i < cache.positions.count else { continue }
            let p = cache.positions[i]
            let s = cache.sizes[i]
            sv.place(
                at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: s.width, height: s.height)
            )
        }
    }

    private func calculate(width: CGFloat, subviews: Subviews, cache: inout CacheData) {
        cache.width = width
        cache.positions = []
        cache.sizes = []
        let colW = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let hStep: CGFloat = 40  // snap card heights to this grid

        // Dense packing: track placed rectangles, find gaps
        var placed: [(col: Int, y: CGFloat, span: Int, height: CGFloat)] = []

        func lowestY(col: Int, span: Int, itemH: CGFloat) -> CGFloat {
            let overlapping = placed.filter { $0.col < col + span && $0.col + $0.span > col }
                .sorted { $0.y < $1.y }
            var y: CGFloat = 0
            for p in overlapping {
                if y + itemH + spacing <= p.y { return y }
                y = max(y, p.y + p.height + spacing)
            }
            return y
        }

        for sv in subviews {
            let rawSpan = sv[ColumnSpanKey.self]
            let span = max(1, min(rawSpan, columns))
            let maxStart = columns - span

            let cardW = colW * CGFloat(span) + spacing * CGFloat(span - 1)
            let measured = sv.sizeThatFits(ProposedViewSize(width: cardW, height: nil))
            let snappedH = ceil(measured.height / hStep) * hStep

            let startCol: Int
            if let pc = sv[PreferredColumnKey.self] {
                startCol = min(max(pc, 0), maxStart)
            } else {
                var best = 0
                var bestH: CGFloat = .infinity
                for c in 0...maxStart {
                    let h = lowestY(col: c, span: span, itemH: snappedH)
                    if h < bestH - 0.5 { bestH = h; best = c }
                }
                startCol = best
            }

            let startY = lowestY(col: startCol, span: span, itemH: snappedH)
            let x = CGFloat(startCol) * (colW + spacing)

            cache.positions.append(CGPoint(x: x, y: startY))
            cache.sizes.append(CGSize(width: cardW, height: snappedH))
            placed.append((col: startCol, y: startY, span: span, height: snappedH))
        }

        cache.totalHeight = max(0, placed.map { $0.y + $0.height }.max() ?? 0)
    }
}

// ============================================================
// MARK: - Dashboard
// ============================================================

struct GridCell: Equatable {
    let col: Int
    let row: Int
}

struct CardDrop: DropDelegate {
    let target: String
    let targetCol: Int
    let targetRow: Int
    @Binding var dragId: String?
    @Binding var cards: [DashCard]
    @Binding var dropPreview: GridCell?
    let save: () -> Void

    func dropEntered(info: DropInfo) {
        guard dragId != nil, dragId != target else { return }
        dropPreview = GridCell(col: targetCol, row: targetRow)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let from = dragId, from != target,
              let fi = cards.firstIndex(where: { $0.id == from }),
              let ti = cards.firstIndex(where: { $0.id == target }) else {
            DispatchQueue.main.async { dragId = nil; dropPreview = nil }
            return true
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            let fromCol = cards[fi].column
            let fromRow = cards[fi].row
            cards[fi].column = cards[ti].column
            cards[fi].row = cards[ti].row
            cards[ti].column = fromCol
            cards[ti].row = fromRow
        }
        DispatchQueue.main.async { dragId = nil; dropPreview = nil; save() }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
}

struct AreaDrop: DropDelegate {
    let areaWidth: CGFloat
    let areaHeight: CGFloat
    let columns: Int
    let rows: Int
    @Binding var dragId: String?
    @Binding var cards: [DashCard]
    @Binding var dropPreview: GridCell?
    let save: () -> Void

    private func targetCell(_ info: DropInfo) -> (col: Int, row: Int)? {
        guard let from = dragId, let fi = cards.firstIndex(where: { $0.id == from }) else { return nil }
        let colW = areaWidth / CGFloat(columns)
        let rowH = areaHeight / CGFloat(rows)
        let cs = max(1, min(columns, cards[fi].span ?? 1))
        let rs = max(1, min(rows, cards[fi].rowSpan ?? 1))
        return (min(max(Int(info.location.x / max(colW, 1)), 0), columns - cs),
                min(max(Int(info.location.y / max(rowH, 1)), 0), rows - rs))
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        if let t = targetCell(info) {
            let cell = GridCell(col: t.col, row: t.row)
            if dropPreview != cell { dropPreview = cell }
        }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let from = dragId, let fi = cards.firstIndex(where: { $0.id == from }),
              let t = targetCell(info) else {
            DispatchQueue.main.async { dragId = nil; dropPreview = nil }
            return false
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            cards[fi].column = t.col
            cards[fi].row = t.row
        }
        DispatchQueue.main.async { dragId = nil; dropPreview = nil; save() }
        return true
    }
}

struct DashView: View {
    @State var cards: [DashCard] = []
    @State var lastMod: Date = .distantPast
    @State var query = ""
    @State var queryLoading = false
    @State var dragId: String? = nil
    @State var dropPreview: GridCell? = nil
    @State var showAddSheet: Bool = false
    @State var systemStats = SystemStats()
    @State var systemTick: Int = 0
    @State var refreshingStreams: Set<String> = []
    @State var streamRefreshCooldown: [String: Date] = [:]
    @State var syncDirection: String = ""
    @State var syncFile: String = ""
    @State var syncTime: Double = 0

    struct KanbanItem: Equatable {
        let board: String
        let column: String
        let title: String
        let position: Int
    }
    @State var kanbanRaw: [KanbanItem] = []
    @State var kanbanError: String = ""
    @State var kanbanLastFetch: Date = .distantPast
    @State var kanbanFetching: Bool = false
    let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    let colCount = 32
    let rowCount = 18
    let kanbanAuthPath = NSHomeDirectory() + "/.config/kanban/auth.json"
    let kanbanApiBase = "https://1o618.com"
    let kanbanFetchInterval: TimeInterval = 8

    func enrichKanban(_ c: DashCard) -> DashCard {
        guard (c.type ?? "") == "kanban" else { return c }
        var out = c
        if !kanbanError.isEmpty {
            out.items = [kanbanError]
            out.sub = nil
            return out
        }
        let board = c.kanbanBoard ?? "work"
        let doings = kanbanRaw.filter { $0.board == board && $0.column == "in_progress" }
            .sorted { $0.position < $1.position }
        let todos = kanbanRaw.filter { $0.board == board && $0.column == "todo" }
            .sorted { $0.position < $1.position }
        let merged = doings.map { "▶ " + $0.title } + todos.map { "○ " + $0.title }
        out.items = merged.isEmpty ? ["Keine offenen Aufgaben"] : merged
        out.sub = "\(doings.count) doing · \(todos.count) todo"
        return out
    }

    func reloadKanbanIfNeeded() {
        // Only fetch if a kanban card exists
        guard cards.contains(where: { ($0.type ?? "") == "kanban" }) else { return }
        guard !kanbanFetching else { return }
        guard Date().timeIntervalSince(kanbanLastFetch) >= kanbanFetchInterval else { return }
        kanbanFetching = true
        kanbanLastFetch = Date()
        Task { await fetchKanban() }
    }

    private func readKanbanAuth() -> (access: String, refresh: String)? {
        guard let d = FileManager.default.contents(atPath: kanbanAuthPath),
              let json = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let a = json["access_token"] as? String,
              let r = json["refresh_token"] as? String else { return nil }
        return (a, r)
    }

    private func writeKanbanAccessToken(_ access: String) {
        guard let d = FileManager.default.contents(atPath: kanbanAuthPath),
              var json = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return }
        json["access_token"] = access
        if let out = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) {
            try? out.write(to: URL(fileURLWithPath: kanbanAuthPath))
        }
    }

    private func kanbanGET(token: String) async -> (Int, Data)? {
        guard let url = URL(string: kanbanApiBase + "/api/kanban/") else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { return nil }
            return (http.statusCode, data)
        } catch { return nil }
    }

    private func kanbanRefresh(_ refresh: String) async -> String? {
        guard let url = URL(string: kanbanApiBase + "/api/auth/mobile/refresh") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["refresh_token": refresh])
        req.timeoutInterval = 10
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let access = json["access_token"] as? String else { return nil }
            writeKanbanAccessToken(access)
            return access
        } catch { return nil }
    }

    private func fetchKanban() async {
        defer { Task { @MainActor in kanbanFetching = false } }

        guard let auth = readKanbanAuth() else {
            await MainActor.run {
                kanbanRaw = []
                kanbanError = "Kanban nicht angemeldet"
            }
            return
        }

        var result = await kanbanGET(token: auth.access)
        if result?.0 == 401 {
            if let newToken = await kanbanRefresh(auth.refresh) {
                result = await kanbanGET(token: newToken)
            }
        }

        guard let (status, data) = result, status == 200,
              let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            await MainActor.run {
                kanbanError = "Kanban API Fehler"
            }
            return
        }

        var items: [KanbanItem] = []
        for c in arr {
            let board = ((c["board"] as? String) ?? "").lowercased()
            let col = ((c["column"] as? String) ?? "").lowercased()
            let title = ((c["title"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let pos = (c["position"] as? Int) ?? 0
            guard !title.isEmpty, !board.isEmpty else { continue }
            guard col == "in_progress" || col == "todo" else { continue }
            items.append(KanbanItem(board: board, column: col, title: title, position: pos))
        }
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.2)) {
                kanbanRaw = items
                kanbanError = ""
            }
        }
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
                .background(TransparentWindow())

            GeometryReader { geo in
                let pad: CGFloat = 12
                let sp: CGFloat = 6
                let gridW = geo.size.width - pad * 2
                let gridH = geo.size.height - pad * 2
                let cellW = (gridW - sp * CGFloat(colCount - 1)) / CGFloat(colCount)
                let cellH = (gridH - sp * CGFloat(rowCount - 1)) / CGFloat(rowCount)

                ZStack(alignment: .topLeading) {
                    Color.white.opacity(0.0001)
                        .frame(width: gridW, height: gridH)
                        .contentShape(Rectangle())
                        .onDrop(of: [.text], delegate: AreaDrop(
                            areaWidth: gridW, areaHeight: gridH,
                            columns: colCount, rows: rowCount,
                            dragId: $dragId, cards: $cards,
                            dropPreview: $dropPreview, save: saveCards
                        ))

                    // Drop preview ghost
                    if let preview = dropPreview, let did = dragId,
                       let dCard = cards.first(where: { $0.id == did }) {
                        let pcs = max(1, min(colCount, dCard.span ?? 1))
                        let prs = max(1, min(rowCount, dCard.rowSpan ?? 1))
                        let pw = CGFloat(pcs) * cellW + CGFloat(pcs - 1) * sp
                        let ph = CGFloat(prs) * cellH + CGFloat(prs - 1) * sp
                        let px = CGFloat(preview.col) * (cellW + sp)
                        let py = CGFloat(preview.row) * (cellH + sp)

                        RoundedRectangle(cornerRadius: 0)
                            .strokeBorder(T.c(dCard.color).opacity(0.5), lineWidth: 1.5)
                            .background(T.c(dCard.color).opacity(0.06))
                            .frame(width: pw, height: ph)
                            .offset(x: px, y: py)
                            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: preview.col)
                            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: preview.row)
                            .allowsHitTesting(false)
                    }

                    ForEach(cards) { card in
                        let c = card.column ?? 0
                        let r = card.row ?? 0
                        let cs = max(1, min(colCount - c, card.span ?? 1))
                        let rs = max(1, min(rowCount - r, card.rowSpan ?? 1))
                        let w = CGFloat(cs) * cellW + CGFloat(cs - 1) * sp
                        let h = CGFloat(rs) * cellH + CGFloat(rs - 1) * sp
                        let x = CGFloat(c) * (cellW + sp)
                        let y = CGFloat(r) * (cellH + sp)

                        CardView(
                            card: enrichKanban(card),
                            onClose: { removeCard(card.id) },
                            onRefresh: { refreshCard(card) },
                            onDoubleTap: { if (card.type ?? "") == "photo" { copyPhotoToClipboard(card) } },
                            onPreset: { s, rs, sz in applyPreset(card.id, span: s, rowSpan: rs, size: sz) },
                            onKanbanBoard: { b in setKanbanBoard(card.id, board: b) },
                            sysStats: systemStats
                        )
                        .frame(width: w, height: h, alignment: .topLeading)
                        .clipped()
                        .onDrag {
                            dragId = card.id
                            return NSItemProvider(object: card.id as NSString)
                        }
                        .onDrop(of: [.text], delegate: CardDrop(
                            target: card.id,
                            targetCol: card.column ?? 0,
                            targetRow: card.row ?? 0,
                            dragId: $dragId, cards: $cards,
                            dropPreview: $dropPreview, save: saveCards
                        ))
                        .opacity(dragId == card.id ? 0.35 : 1)
                        .animation(.easeInOut(duration: 0.15), value: dragId)
                        .offset(x: x, y: y)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        ))
                    }
                }
                .frame(width: gridW, height: gridH, alignment: .topLeading)
                .padding(pad)
            }

        }
        .overlay(alignment: .bottomTrailing) {
            syncOverlay.padding(12)
        }
        .frame(minWidth: 1280, minHeight: 720)
        .onChange(of: dragId) { _, new in
            if new == nil { dropPreview = nil }
        }
        .onAppear {
            loadCards()
            reloadKanbanIfNeeded()
            systemStats = SystemMonitor.shared.sample()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DashPasteImage"))) { _ in
            pasteImage()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("DashShowAddSheet"))) { _ in
            showAddSheet = true
        }
        .sheet(isPresented: $showAddSheet) {
            AddCardSheet()
        }
        .onReceive(timer) { _ in
            checkFile()
            reloadKanbanIfNeeded()
            refreshExpiredStreams()
            checkSyncStatus()
            if cards.contains(where: { ($0.type ?? "") == "system" }) {
                systemStats = SystemMonitor.shared.sample()
                systemTick &+= 1
            }
        }
    }

    func runQuery() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        query = ""
        queryLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let dashBin = NSHomeDirectory() + "/.local/bin/dash"
            var args: [String]

            let ql = q.lowercased()
            if ql.hasPrefix("wetter") || ql.hasPrefix("weather") {
                let city = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "weather", city.isEmpty ? "Dortmund" : city]
            } else if ql.hasPrefix("stock ") || ql.hasPrefix("aktie ") {
                let sym = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "stock", sym]
            } else if ql.hasPrefix("crypto ") || ql.hasPrefix("krypto ") {
                let coin = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "crypto", coin]
            } else if ql.hasPrefix("news ") {
                let topic = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "news", topic]
            } else if ql.hasPrefix("wiki ") {
                let topic = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "wiki", topic]
            } else if ql.hasPrefix("bilder ") || ql.hasPrefix("images ") {
                let topic = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "images", topic]
            } else if ql.hasPrefix("youtube ") || ql.hasPrefix("yt ") {
                let topic = q.components(separatedBy: " ").dropFirst().joined(separator: " ")
                args = [dashBin, "youtube", topic]
            } else if ql == "system" || ql == "status" {
                args = [dashBin, "status"]
            } else if ql == "clear" {
                args = [dashBin, "clear"]
            } else {
                // Default: web search
                args = [dashBin, "search", q]
            }

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", args.map { "'\($0)'" }.joined(separator: " ")]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = NSHomeDirectory() + "/.local/bin:" + NSHomeDirectory() + "/.nvm/versions/node/v22.19.0/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
            proc.environment = env
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()

            DispatchQueue.main.async { queryLoading = false }
        }
    }

    func checkSyncStatus() {
        let path = "/tmp/srv-sync.json"
        guard let data = FileManager.default.contents(atPath: path),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let d = json["d"] as? String,
              let t = json["t"] as? Double else { return }
        let f = json["f"] as? String ?? ""
        if t != syncTime {
            syncDirection = d
            syncFile = f
            syncTime = t
        }
    }

    var syncOverlay: some View {
        let age = Date().timeIntervalSince1970 - syncTime
        let visible = age < 4 && !syncFile.isEmpty && !syncDirection.isEmpty
        let icon = syncDirection == "up" ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        let col = syncDirection == "up" ? T.c("green") : T.c("blue")

        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(col)
            Text(syncFile)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(T.text1)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(T.card.opacity(0.92))
        .overlay(Capsule().stroke(col.opacity(0.25), lineWidth: 0.5))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.4), radius: 10, y: 3)
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: visible)
        .animation(.easeInOut(duration: 0.2), value: syncFile)
    }

    func refreshExpiredStreams() {
        for card in cards where (card.type ?? "") == "youtube" {
            guard let vid = card.videoId, !vid.isEmpty,
                  let stream = card.streamUrl, !stream.isEmpty,
                  card.content != "offline",
                  !refreshingStreams.contains(card.id) else { continue }
            if let last = streamRefreshCooldown[card.id],
               Date().timeIntervalSince(last) < 300 { continue }
            // Check expire param in stream URL
            if let comps = URLComponents(string: stream),
               let exp = comps.queryItems?.first(where: { $0.name == "expire" })?.value,
               let t = Double(exp), Date().timeIntervalSince1970 < t - 300 {
                continue // still valid (5 min buffer)
            }
            refreshingStreams.insert(card.id)
            streamRefreshCooldown[card.id] = Date()
            let cardId = card.id
            DispatchQueue.global(qos: .utility).async {
                let fmt = "bv*[height<=1080][ext=mp4]+ba[ext=m4a]/best[height<=1080][ext=mp4]/best[ext=mp4][acodec!=none][vcodec!=none]/best"
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/bash")
                proc.arguments = ["-c", "yt-dlp --skip-download --no-warnings -f '\(fmt)' --print '%(url)s' 'https://www.youtube.com/watch?v=\(vid)'"]
                var env = ProcessInfo.processInfo.environment
                env["PATH"] = NSHomeDirectory() + "/.local/bin:" + NSHomeDirectory() + "/.nvm/versions/node/v22.19.0/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
                proc.environment = env
                let pipe = Pipe()
                proc.standardOutput = pipe
                proc.standardError = FileHandle.nullDevice
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let newUrl = (String(data: data, encoding: .utf8) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .components(separatedBy: "\n").first ?? ""
                    DispatchQueue.main.async {
                        if !newUrl.isEmpty, newUrl.hasPrefix("http"),
                           let idx = self.cards.firstIndex(where: { $0.id == cardId }) {
                            self.cards[idx].streamUrl = newUrl
                            self.saveCards()
                        }
                        self.refreshingStreams.remove(cardId)
                    }
                } catch {
                    DispatchQueue.main.async { self.refreshingStreams.remove(cardId) }
                }
            }
        }
    }

    func saveCards() {
        let snapshot = cards
        DispatchQueue.global(qos: .utility).async {
            let data = DashData(cards: snapshot, schemaVersion: 2)
            if let encoded = try? JSONEncoder().encode(data) {
                try? encoded.write(to: URL(fileURLWithPath: kPath))
            }
            DispatchQueue.main.async {
                lastMod = (try? FileManager.default.attributesOfItem(atPath: kPath)[.modificationDate] as? Date) ?? Date()
            }
        }
    }

    func refreshCard(_ card: DashCard) {
        let ct = card.type ?? "info"

        // Kanban: live refetch, ignoring interval
        if ct == "kanban" {
            kanbanLastFetch = .distantPast
            reloadKanbanIfNeeded()
            return
        }

        // Build dash command + which ids to remove
        var args: [String] = []
        var idsToRemove: [String] = [card.id]

        switch ct {
        case "stock":
            guard let sym = card.sub, !sym.isEmpty else { return }
            args = ["stock", sym]
        case "metric":
            // Crypto: id pattern "crypto_<coin>_<ts>"
            if card.id.hasPrefix("crypto_") {
                let parts = card.id.split(separator: "_")
                if parts.count >= 3 { args = ["crypto", String(parts[1])] }
            }
        case "weather":
            // title: "Wetter <city>" — also refresh matching forecast card
            let city = card.title.replacingOccurrences(of: "Wetter ", with: "").trimmingCharacters(in: .whitespaces)
            if city.isEmpty { return }
            args = ["weather", city]
            let forecastTitle = "5-Tage " + city
            for c in cards where c.title == forecastTitle { idsToRemove.append(c.id) }
        case "forecast":
            let city = card.title.replacingOccurrences(of: "5-Tage ", with: "").trimmingCharacters(in: .whitespaces)
            if city.isEmpty { return }
            args = ["weather", city]
            let weatherTitle = "Wetter " + city
            for c in cards where c.title == weatherTitle { idsToRemove.append(c.id) }
        case "youtube":
            guard let vid = card.videoId, !vid.isEmpty else { return }
            let wasDownload = (card.content == "offline")
            args = wasDownload
                ? ["youtube", "-d", "https://www.youtube.com/watch?v=" + vid]
                : ["youtube", "https://www.youtube.com/watch?v=" + vid]
        case "list":
            if card.id.hasPrefix("news_") {
                let q = card.title.replacingOccurrences(of: "News: ", with: "").trimmingCharacters(in: .whitespaces)
                if !q.isEmpty { args = ["news", q] }
            } else if card.id.hasPrefix("search_") {
                let q = card.title.replacingOccurrences(of: "Suche: ", with: "").trimmingCharacters(in: .whitespaces)
                if !q.isEmpty { args = ["search", q] }
            }
        case "image":
            if card.id.hasPrefix("img_") {
                let q = card.title.replacingOccurrences(of: "Bilder: ", with: "").trimmingCharacters(in: .whitespaces)
                if !q.isEmpty { args = ["images", q] }
            }
        default:
            return
        }

        if args.isEmpty { return }

        // Remove the old card(s) so the dash command inserts a fresh one
        for rid in idsToRemove { removeCard(rid) }

        DispatchQueue.global(qos: .userInitiated).async {
            let dashBin = NSHomeDirectory() + "/.local/bin/dash"
            let full = ([dashBin] + args).map { "'\($0)'" }.joined(separator: " ")
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = ["-c", full]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = NSHomeDirectory() + "/.local/bin:" + NSHomeDirectory() + "/.nvm/versions/node/v22.19.0/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
            proc.environment = env
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
            proc.waitUntilExit()
        }
    }

    func setKanbanBoard(_ id: String, board: String) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            cards[idx].kanbanBoard = board
        }
        saveCards()
    }

    func findEmptyCell(span: Int = 1, rowSpan: Int = 1) -> (col: Int, row: Int) {
        var grid = Array(repeating: Array(repeating: false, count: colCount), count: rowCount)
        for card in cards {
            let c = card.column ?? 0, r = card.row ?? 0
            let cs = max(1, min(colCount, card.span ?? 1))
            let rs = max(1, min(rowCount, card.rowSpan ?? 1))
            for dr in 0..<rs { for dc in 0..<cs {
                if r+dr < rowCount && c+dc < colCount { grid[r+dr][c+dc] = true }
            }}
        }
        for r in 0...max(0, rowCount-rowSpan) {
            for c in 0...max(0, colCount-span) {
                var fits = true
                check: for dr in 0..<rowSpan { for dc in 0..<span {
                    if grid[r+dr][c+dc] { fits = false; break check }
                }}
                if fits { return (c, r) }
            }
        }
        return (0, 0)
    }

    func pasteImage() {
        let pb = NSPasteboard.general
        guard let img = NSImage(pasteboard: pb) else { return }
        guard let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let dir = NSHomeDirectory() + "/.cache/dashboard/images"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let id = "photo_\(Int(Date().timeIntervalSince1970 * 1000))"
        let path = dir + "/\(id).png"
        try? png.write(to: URL(fileURLWithPath: path))
        let pos = findEmptyCell()
        var card = DashCard(id: id, title: "Bild", content: "", icon: "photo", color: "teal")
        card.type = "photo"
        card.images = ["file://\(path)"]
        card.span = 3; card.rowSpan = 3; card.size = "compact"
        card.column = pos.col; card.row = pos.row
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
            cards.append(card)
        }
        saveCards()
    }

    func copyPhotoToClipboard(_ card: DashCard) {
        guard let urlStr = card.images?.first,
              let url = URL(string: urlStr),
              let img = NSImage(contentsOf: url) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([img])
    }

    func applyPreset(_ id: String, span: Int, rowSpan: Int, size: String?) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
            cards[idx].span = max(1, min(colCount, span))
            cards[idx].rowSpan = max(1, min(rowCount, rowSpan))
            cards[idx].size = size
        }
        saveCards()
    }

    func removeCard(_ id: String) {
        PlayerRegistry.shared.release(cardId: id)
        withAnimation(.easeOut(duration: 0.25)) {
            cards.removeAll { $0.id == id }
        }
        // Also remove from JSON file
        DispatchQueue.global(qos: .background).async {
            guard let data = FileManager.default.contents(atPath: kPath),
                  var decoded = try? JSONDecoder().decode(DashData.self, from: data) else { return }
            decoded.cards.removeAll { $0.id == id }
            decoded.schemaVersion = 2
            if let encoded = try? JSONEncoder().encode(decoded) {
                try? encoded.write(to: URL(fileURLWithPath: kPath))
            }
        }
    }

    // Pack cards into rows with 3 slots each. Wide cards take 2 slots.
    func buildRows(_ cards: [DashCard]) -> [[DashCard]] {
        var rows: [[DashCard]] = []
        var row: [DashCard] = []
        var slots = 0
        for c in cards {
            let need = max(1, min(colCount, c.span ?? ((c.size ?? "") == "wide" ? 2 : 1)))
            if slots + need > colCount {
                if !row.isEmpty { rows.append(row) }
                row = []
                slots = 0
            }
            row.append(c)
            slots += need
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    func checkFile() {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: kPath),
              let mod = attrs[.modificationDate] as? Date, mod > lastMod else { return }
        lastMod = mod; loadCards()
    }

    func loadCards() {
        guard let data = FileManager.default.contents(atPath: kPath),
              let decoded = try? JSONDecoder().decode(DashData.self, from: data) else { return }
        var newCards = decoded.cards
        // One-shot migration 16×9 → 32×18: double column/row/span/rowSpan, persist schemaVersion:2
        let schema = decoded.schemaVersion ?? 1
        if schema < 2 {
            for i in 0..<newCards.count {
                if let c = newCards[i].column { newCards[i].column = c * 2 }
                if let r = newCards[i].row { newCards[i].row = r * 2 }
                if let s = newCards[i].span { newCards[i].span = s * 2 }
                if let rs = newCards[i].rowSpan { newCards[i].rowSpan = rs * 2 }
            }
            let migrated = DashData(cards: newCards, schemaVersion: 2)
            if let out = try? JSONEncoder().encode(migrated) {
                try? out.write(to: URL(fileURLWithPath: kPath))
            }
        }
        // Apply default presets for cards without explicit sizes
        for i in 0..<newCards.count where newCards[i].span == nil && newCards[i].rowSpan == nil {
            let ct = newCards[i].type ?? "info"
            let p = cardPresets(ct)[defaultPresetIndex(ct)]
            newCards[i].span = p.span
            newCards[i].rowSpan = p.rowSpan
            newCards[i].size = p.size
        }
        // Auto-place cards without grid position
        var grid = Array(repeating: Array(repeating: false, count: colCount), count: rowCount)
        for card in newCards where card.column != nil && card.row != nil {
            let c = card.column!, r = card.row!
            let cs = max(1, min(colCount, card.span ?? 1))
            let rs = max(1, min(rowCount, card.rowSpan ?? 1))
            for dr in 0..<rs { for dc in 0..<cs {
                if r+dr < rowCount && c+dc < colCount { grid[r+dr][c+dc] = true }
            }}
        }
        for i in 0..<newCards.count where newCards[i].column == nil || newCards[i].row == nil {
            let cs = max(1, min(colCount, newCards[i].span ?? 1))
            let rs = max(1, min(rowCount, newCards[i].rowSpan ?? 1))
            var placed = false
            for r in 0...max(0, rowCount-rs) {
                for c in 0...max(0, colCount-cs) {
                    var fits = true
                    check: for dr in 0..<rs { for dc in 0..<cs {
                        if grid[r+dr][c+dc] { fits = false; break check }
                    }}
                    if fits {
                        newCards[i].column = c; newCards[i].row = r
                        for dr in 0..<rs { for dc in 0..<cs { grid[r+dr][c+dc] = true } }
                        placed = true; break
                    }
                }
                if placed { break }
            }
            if !placed { newCards[i].column = 0; newCards[i].row = 0 }
        }
        let newIds = Set(newCards.map(\.id))
        let currentIds = Set(cards.map(\.id))

        if !cards.filter({ !newIds.contains($0.id) }).isEmpty {
            withAnimation(.easeOut(duration: 0.25)) { cards.removeAll { !newIds.contains($0.id) } }
        }
        for (i, card) in newCards.enumerated() {
            if !currentIds.contains(card.id) {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        if !cards.contains(where: { $0.id == card.id }) { cards.append(card) }
                    }
                }
            }
        }
        for nc in newCards {
            if let idx = cards.firstIndex(where: { $0.id == nc.id }), cards[idx] != nc {
                withAnimation(.easeInOut(duration: 0.25)) { cards[idx] = nc }
            }
        }
    }
}

// ============================================================
// MARK: - Add Card Sheet (invoked via menu / ⌘N)
// ============================================================

struct AddCardSheet: View {
    @Environment(\.dismiss) private var dismiss

    struct CardType: Identifiable {
        let id: String
        let label: String
        let icon: String
        let placeholder: String    // empty = no input required
        let placeholder2: String   // second field (only for info)
    }

    // Card types exposed in the modal. Order = display order.
    static let types: [CardType] = [
        .init(id: "weather",  label: "Wetter",     icon: "cloud.sun",               placeholder: "Ort (Standard: Dortmund)", placeholder2: ""),
        .init(id: "forecast", label: "5-Tage",     icon: "calendar",                placeholder: "Ort (Standard: Dortmund)", placeholder2: ""),
        .init(id: "stock",    label: "Aktie",      icon: "chart.line.uptrend.xyaxis", placeholder: "Symbol (z.B. AAPL)",     placeholder2: ""),
        .init(id: "crypto",   label: "Crypto",     icon: "bitcoinsign.circle",      placeholder: "Coin (z.B. bitcoin)",       placeholder2: ""),
        .init(id: "wiki",     label: "Wikipedia",  icon: "book",                    placeholder: "Begriff",                   placeholder2: ""),
        .init(id: "search",   label: "Suche",      icon: "magnifyingglass",         placeholder: "Query",                     placeholder2: ""),
        .init(id: "news",     label: "News",       icon: "newspaper",               placeholder: "Query (optional)",          placeholder2: ""),
        .init(id: "images",   label: "Bilder",     icon: "photo.on.rectangle",      placeholder: "Query",                     placeholder2: ""),
        .init(id: "youtube",  label: "YouTube",    icon: "play.rectangle",          placeholder: "URL oder Suche",            placeholder2: ""),
        .init(id: "system",   label: "System",     icon: "cpu",                     placeholder: "",                          placeholder2: ""),
        .init(id: "tv",       label: "TV",         icon: "tv",                      placeholder: "",                          placeholder2: ""),
        .init(id: "kanban",   label: "Kanban",     icon: "checklist",               placeholder: "",                          placeholder2: ""),
        .init(id: "info",     label: "Notiz",      icon: "doc.text",                placeholder: "Titel",                     placeholder2: "Inhalt"),
        .init(id: "ask",      label: "Claude",     icon: "sparkles",                placeholder: "Frage",                     placeholder2: ""),
    ]

    @State private var selected: String = "weather"
    @State private var input1: String = ""
    @State private var input2: String = ""
    @State private var ytDownload: Bool = false
    @FocusState private var inputFocused: Bool

    private var meta: CardType { Self.types.first(where: { $0.id == selected }) ?? Self.types[0] }
    private var requiresInput: Bool { !meta.placeholder.isEmpty && !meta.placeholder.contains("optional") && !meta.placeholder.contains("Standard") }
    private var canSubmit: Bool {
        if !requiresInput { return true }
        if selected == "info" {
            return !input1.trimmingCharacters(in: .whitespaces).isEmpty
                && !input2.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !input1.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Karte hinzufügen")
                .font(.system(size: 16, weight: .semibold))

            // Type picker — compact grid
            let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(Self.types) { t in
                    Button {
                        selected = t.id
                        input1 = ""
                        input2 = ""
                        inputFocused = !t.placeholder.isEmpty
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.icon)
                                .font(.system(size: 17, weight: .medium))
                            Text(t.label)
                                .font(.system(size: 10, weight: .medium))
                        }
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(selected == t.id ? Color.accentColor.opacity(0.22) : Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(selected == t.id ? Color.accentColor : Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(selected == t.id ? Color.accentColor : Color.primary.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !meta.placeholder.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(meta.placeholder, text: $input1)
                        .textFieldStyle(.roundedBorder)
                        .focused($inputFocused)
                        .onSubmit { if canSubmit { submit() } }
                    if !meta.placeholder2.isEmpty {
                        TextField(meta.placeholder2, text: $input2, axis: .vertical)
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                    }
                    if selected == "youtube" {
                        Toggle("Offline herunterladen (≤720p)", isOn: $ytDownload)
                            .font(.system(size: 11))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                }
            } else {
                Text("Diese Karte benötigt keine Eingabe.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Hinzufügen") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSubmit)
            }
        }
        .padding(20)
        .frame(width: 440)
        .onAppear { inputFocused = !meta.placeholder.isEmpty }
    }

    private func submit() {
        guard canSubmit else { return }
        let dashBin = NSHomeDirectory() + "/.local/bin/dash"
        let v1 = input1.trimmingCharacters(in: .whitespaces)
        let v2 = input2.trimmingCharacters(in: .whitespaces)

        var args: [String]
        switch selected {
        case "info":
            args = ["add", v1, v2]
        case "youtube":
            args = ytDownload ? ["youtube", "-d", v1] : ["youtube", v1]
        case "weather", "forecast":
            // Both weather and forecast are produced by the same dash command
            args = ["weather", v1.isEmpty ? "Dortmund" : v1]
        case "news":
            args = v1.isEmpty ? ["news", "Deutschland"] : ["news", v1]
        case "system", "tv", "kanban":
            args = [selected]
        default:
            args = [selected, v1]
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            let joined = ([dashBin] + args)
                .map { "'" + $0.replacingOccurrences(of: "'", with: "'\\''") + "'" }
                .joined(separator: " ")
            proc.arguments = ["-c", joined]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = NSHomeDirectory() + "/.local/bin:/opt/homebrew/bin:" + (env["PATH"] ?? "")
            proc.environment = env
            proc.standardOutput = FileHandle.nullDevice
            proc.standardError = FileHandle.nullDevice
            try? proc.run()
        }
        dismiss()
    }
}

// ============================================================
// MARK: - Transparent Window Helper
// ============================================================

class WindowRef {
    static var window: NSWindow?
    static func setMovable(_ movable: Bool) {
        window?.isMovableByWindowBackground = movable
    }
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
            w.standardWindowButton(.closeButton)?.isHidden = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden = true
            w.isMovableByWindowBackground = false
            w.hasShadow = false
            WindowRef.window = w
        }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {}
}

// ============================================================
// MARK: - App
// ============================================================

@main
struct DashboardApp: App {
    static var pasteMonitor: Any?

    init() {
        if Self.pasteMonitor == nil {
            Self.pasteMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command),
                   event.charactersIgnoringModifiers == "v",
                   let types = NSPasteboard.general.types,
                   types.contains(where: { [.tiff, .png].contains($0) }) {
                    NotificationCenter.default.post(name: .init("DashPasteImage"), object: nil)
                    return nil
                }
                return event
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            DashView().preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1920, height: 1080)
        .commands {
            CommandMenu("Karte") {
                Button("Neue Karte…") {
                    NotificationCenter.default.post(name: .init("DashShowAddSheet"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
