// LaGo 🌸 — Widget d'écran d'accueil iPhone (WidgetKit).
// À ajouter comme cible « Widget Extension » nommée LagoWidget dans Xcode (voir README.md).
import WidgetKit
import SwiftUI

private let appGroup = "group.app.lago.cycle"

struct LagoEntry: TimelineEntry {
    let date: Date
    let title: String
    let main: String
    let sub: String
}

struct LagoProvider: TimelineProvider {
    func read() -> LagoEntry {
        let d = UserDefaults(suiteName: appGroup)
        return LagoEntry(date: Date(),
                         title: d?.string(forKey: "title") ?? "LaGo 🌸",
                         main: d?.string(forKey: "main") ?? "LaGo",
                         sub: d?.string(forKey: "sub") ?? "")
    }
    func placeholder(in context: Context) -> LagoEntry { LagoEntry(date: Date(), title: "LaGo 🌸", main: "Jour 12", sub: "") }
    func getSnapshot(in context: Context, completion: @escaping (LagoEntry) -> Void) { completion(read()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LagoEntry>) -> Void) {
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [read()], policy: .after(next)))
    }
}

struct LagoWidgetView: View {
    var entry: LagoEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.title).font(.caption).bold().foregroundColor(Color(red: 0.76, green: 0.09, blue: 0.36))
            Text(entry.main).font(.title2).bold()
            Text(entry.sub).font(.caption).foregroundColor(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(Color(red: 1.0, green: 0.96, blue: 0.97))
    }
}

@main
struct LagoWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "LagoWidget", provider: LagoProvider()) { entry in
            LagoWidgetView(entry: entry)
        }
        .configurationDisplayName("LaGo")
        .description("Jour du cycle et prochaines règles")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
