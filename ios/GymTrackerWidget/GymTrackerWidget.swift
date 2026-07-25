import WidgetKit
import SwiftUI

struct GymTrackerProvider: TimelineProvider {
    func placeholder(in context: Context) -> GymTrackerEntry {
        GymTrackerEntry(date: Date(), todayPlan: "Leg Day 🦵", lastWeight: "62.5 kg")
    }

    func getSnapshot(in context: Context, completion: @escaping (GymTrackerEntry) -> ()) {
        let entry = getEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GymTrackerEntry>) -> ()) {
        let entry = getEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func getEntry() -> GymTrackerEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.vivian.gymtracker")
        let todayPlan = userDefaults?.string(forKey: "today_plan") ?? "Rest Day 😴"
        let lastWeight = userDefaults?.string(forKey: "last_weight") ?? "62.5 kg"
        return GymTrackerEntry(date: Date(), todayPlan: todayPlan, lastWeight: lastWeight)
    }
}

struct GymTrackerEntry: TimelineEntry {
    let date: Date
    let todayPlan: String
    let lastWeight: String
}

struct GymTrackerWidgetEntryView : View {
    var entry: GymTrackerProvider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("VIVIAN'S GYM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.orange)
                Spacer()
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.orange)
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("TODAY'S PLAN")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.gray)
                Text(entry.todayPlan)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.white)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                Text("LAST WEIGHT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color.gray)
                Text(entry.lastWeight)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.green)
            }
        }
        .padding(12)
        .containerBackground(Color(red: 0.08, green: 0.08, blue: 0.12), for: .widget)
    }
}

struct GymTrackerWidget: Widget {
    let kind: String = "GymTrackerWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GymTrackerProvider()) { entry in
            GymTrackerWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Vivian's Gym Tracker")
        .description("Shows today's workout plan and your last logged weight.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
