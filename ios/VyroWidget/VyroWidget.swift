// VYRO home-screen widget for iOS (WidgetKit).
//
// Reads the snapshot that `VyroHomeWidgets.publish` (lib/core/platform/
// home_widgets.dart) writes into the shared App Group. See docs/WIDGETS.md
// for adding this extension target in Xcode.

import SwiftUI
import WidgetKit

private let appGroupId = "group.com.example.vyro"

struct VyroEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let kcalEaten: Int
    let kcalGoal: Int
    let kcalLeft: Int
    let kcalPercent: Int
    let proteinEaten: Int
    let proteinGoal: Int
    let nextWorkout: String
    let nextWhen: String
    let weekDone: Int
    let weekTotal: Int
    let lblTitle: String
    let lblLeft: String
    let lblOver: String
    let lblNext: String
    let lblWeek: String
    let lblProtein: String

    static func read() -> VyroEntry {
        let d = UserDefaults(suiteName: appGroupId)
        func int(_ key: String) -> Int { d?.integer(forKey: key) ?? 0 }
        func text(_ key: String, _ fallback: String) -> String {
            d?.string(forKey: key) ?? fallback
        }
        return VyroEntry(
            date: Date(),
            hasData: d?.object(forKey: "kcal_goal") != nil,
            kcalEaten: int("kcal_eaten"),
            kcalGoal: int("kcal_goal"),
            kcalLeft: int("kcal_left"),
            kcalPercent: int("kcal_percent"),
            proteinEaten: int("protein_eaten"),
            proteinGoal: int("protein_goal"),
            nextWorkout: text("next_workout", ""),
            nextWhen: text("next_when", ""),
            weekDone: int("week_done"),
            weekTotal: int("week_total"),
            lblTitle: text("lbl_title", "Hoje"),
            lblLeft: text("lbl_left", "restantes"),
            lblOver: text("lbl_over", "acima do objetivo"),
            lblNext: text("lbl_next", "Próximo treino"),
            lblWeek: text("lbl_week", "treinos feitos"),
            lblProtein: text("lbl_protein", "Proteína")
        )
    }

    var leftLine: String {
        kcalLeft >= 0 ? "\(kcalLeft) kcal \(lblLeft)" : "\(-kcalLeft) kcal \(lblOver)"
    }
}

struct VyroProvider: TimelineProvider {
    func placeholder(in context: Context) -> VyroEntry { VyroEntry.read() }

    func getSnapshot(in context: Context, completion: @escaping (VyroEntry) -> Void) {
        completion(VyroEntry.read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VyroEntry>) -> Void) {
        // The app reloads the timeline whenever data changes; refresh at
        // midnight so "today" resets even if the app is not opened.
        let midnight = Calendar.current.startOfDay(for: Date().addingTimeInterval(86_400))
        completion(Timeline(entries: [VyroEntry.read()], policy: .after(midnight)))
    }
}

private let ink = Color(red: 0.07, green: 0.08, blue: 0.10)
private let lime = Color(red: 0.72, green: 0.95, blue: 0.42)
private let muted = Color(red: 0.57, green: 0.60, blue: 0.64)
private let offWhite = Color(red: 0.96, green: 0.97, blue: 0.97)

/// The VYRO mark: off-white V with a lime cap (same geometry as the app).
struct VyroMark: View {
    var body: some View {
        Canvas { ctx, size in
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * size.width, y: y * size.height)
            }
            var v = Path()
            v.addLines([p(0.04, 0.14), p(0.33, 0.14), p(0.50, 0.60), p(0.67, 0.14),
                        p(0.96, 0.14), p(0.63, 0.88), p(0.37, 0.88)])
            v.closeSubpath()
            ctx.fill(v, with: .color(offWhite))
            var gap = Path()
            gap.addLines([p(0.67, 0.14), p(0.96, 0.14), p(0.8904, 0.296), p(0.6123, 0.296)])
            gap.closeSubpath()
            ctx.fill(gap, with: .color(ink))
            var cap = Path()
            cap.addLines([p(0.67, 0.14), p(0.96, 0.14), p(0.902, 0.27), p(0.622, 0.27)])
            cap.closeSubpath()
            ctx.fill(cap, with: .color(lime))
        }
    }
}

struct VyroWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: VyroEntry

    var body: some View {
        Group {
            if family == .systemSmall {
                small
            } else {
                medium
            }
        }
        .widgetURL(URL(string: "vyro://home"))
    }

    private var header: some View {
        HStack(spacing: 6) {
            VyroMark().frame(width: 14, height: 14)
            Text("VYRO").font(.system(size: 11, weight: .heavy)).kerning(2).foregroundColor(offWhite)
            Spacer()
            Text(entry.lblTitle.uppercased()).font(.system(size: 10, weight: .bold)).kerning(1.5)
                .foregroundColor(lime)
        }
    }

    private var bar: some View {
        ProgressView(value: Double(entry.kcalPercent), total: 100).tint(lime)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            VyroMark().frame(width: 16, height: 16)
            Spacer()
            Text(entry.hasData ? "\(abs(entry.kcalLeft))" : "—")
                .font(.system(size: 30, weight: .bold)).monospacedDigit().foregroundColor(offWhite)
            Text(entry.kcalLeft >= 0 ? "kcal \(entry.lblLeft)" : "kcal \(entry.lblOver)")
                .font(.system(size: 12, weight: .bold)).foregroundColor(lime).lineLimit(1)
            bar
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(entry.kcalEaten)").font(.system(size: 28, weight: .bold)).monospacedDigit()
                    .foregroundColor(offWhite)
                Text("/ \(entry.kcalGoal) kcal").font(.system(size: 13)).foregroundColor(muted)
            }
            bar
            HStack {
                Text(entry.leftLine).font(.system(size: 12, weight: .bold)).foregroundColor(lime)
                Spacer()
                Text("\(entry.lblProtein) \(entry.proteinEaten) / \(entry.proteinGoal) g")
                    .font(.system(size: 12)).foregroundColor(muted)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.nextWhen.isEmpty ? entry.lblNext : "\(entry.lblNext) · \(entry.nextWhen)")
                        .font(.system(size: 11)).foregroundColor(muted)
                    Text(entry.nextWorkout).font(.system(size: 14, weight: .bold)).foregroundColor(offWhite)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(entry.weekDone)/\(entry.weekTotal) \(entry.lblWeek)")
                    .font(.system(size: 11)).foregroundColor(muted)
            }
        }
    }
}

@main
struct VyroWidget: Widget {
    // Must match `_iosKind` in lib/core/platform/home_widgets.dart.
    let kind = "VyroWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VyroProvider()) { entry in
            if #available(iOS 17.0, *) {
                VyroWidgetView(entry: entry).containerBackground(ink, for: .widget)
            } else {
                VyroWidgetView(entry: entry).padding().background(ink)
            }
        }
        .configurationDisplayName("VYRO")
        .description("Calorias, proteína e próximo treino de hoje.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
