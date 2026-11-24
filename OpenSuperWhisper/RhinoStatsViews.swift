import AppKit
import SwiftUI

// MARK: - Loading + cache

/// Holds the computed Stats per range for Home's "This week" card and the Stats tab.
/// Shared so results survive tab switches. Rows are re-read only when a cheap SQL
/// fingerprint of the history changes (recordingsDidUpdate fires many times per
/// dictation) or the day rolls over, and each range is computed off the main thread,
/// once per fingerprint, only when something shows it.
@MainActor
final class RhinoStatsModel: ObservableObject {
    static let shared = RhinoStatsModel()

    @Published private(set) var stats: [StatsRange: RhinoStats] = [:]

    private var rows: [RhinoWrapped.Dictation] = []
    private var signature: String?
    private var computedFor: [StatsRange: String] = [:]
    /// Ranges something has shown; Home always wants the week.
    private var wanted: Set<StatsRange> = [.week]
    private var running = false
    private var rerun = false

    /// Completed, non-empty dictations all time; nil until the first load.
    var countedDictations: Int? { stats.values.first?.countedDictations }

    func refresh(_ range: StatsRange? = nil) {
        if let range { wanted.insert(range) }
        guard !running else { rerun = true; return }
        running = true
        Task { [weak self] in
            await self?.load()
            guard let self else { return }
            self.running = false
            if self.rerun { self.rerun = false; self.refresh() }
        }
    }

    private func load() async {
        let store = RecordingStore.shared
        guard let history = try? await store.completedHistorySignature() else { return }
        // Time zone and today's date are part of the key: days move with the zone, and
        // "the last 7 days" moves at midnight even when nothing new was dictated.
        let today = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        let key = "\(history)|\(TimeZone.current.identifier)|\(today)"
        if key != signature {
            guard let fresh = try? await store.fetchWrappedDictations() else { return }
            rows = fresh
            signature = key
        }
        let ranges = wanted.filter { computedFor[$0] != key }
        guard !ranges.isEmpty else { return }
        let rows = self.rows
        let results = await Task.detached(priority: .utility) {
            ranges.map { ($0, RhinoStats.compute(rows, range: $0)) }
        }.value
        for (range, result) in results {
            stats[range] = result
            computedFor[range] = key
        }
    }
}

// MARK: - Palette

/// The blue accents from the approved mockup, with dark-mode counterparts.
struct StatsPalette {
    let scheme: ColorScheme
    private var dark: Bool { scheme == .dark }

    var strong: Color { dark ? Color(red: 0.42, green: 0.58, blue: 1.0) : Color(red: 0.184, green: 0.357, blue: 0.847) }
    var light: Color { dark ? Color(red: 0.42, green: 0.58, blue: 1.0).opacity(0.45) : Color(red: 0.576, green: 0.675, blue: 0.953) }
    var link: Color { dark ? Color(red: 0.55, green: 0.68, blue: 1.0) : Color(red: 0.114, green: 0.306, blue: 0.847) }
    var down: Color { dark ? Color(red: 0.98, green: 0.66, blue: 0.30) : Color(red: 0.706, green: 0.325, blue: 0.035) }
    var track: Color { dark ? Color.white.opacity(0.08) : Color(red: 0.941, green: 0.941, blue: 0.949) }
    var tint: Color { dark ? Color(red: 0.12, green: 0.14, blue: 0.21) : Color(red: 0.961, green: 0.969, blue: 0.996) }
    var tintBorder: Color { dark ? Color(red: 0.22, green: 0.26, blue: 0.40) : Color(red: 0.875, green: 0.902, blue: 0.984) }

    /// Heatmap levels 0–4.
    func heat(_ level: Int) -> Color {
        if dark {
            return level <= 0 ? Color.white.opacity(0.08) : strong.opacity([0.3, 0.5, 0.75, 1][min(level, 4) - 1])
        }
        let shades = [
            Color(red: 0.941, green: 0.941, blue: 0.949), Color(red: 0.788, green: 0.839, blue: 0.980),
            Color(red: 0.576, green: 0.675, blue: 0.953), Color(red: 0.357, green: 0.510, blue: 0.902),
            Color(red: 0.184, green: 0.357, blue: 0.847),
        ]
        return shades[max(0, min(level, 4))]
    }
}

// MARK: - Home: "This week" card

/// Home's slot below the Dictate row: the locked Wrapped card under 10 dictations, then
/// a "This week" summary that opens the Stats tab.
struct HomeWeekSection: View {
    let shortcut: String
    let openStats: () -> Void
    @ObservedObject private var model = RhinoStatsModel.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // No modifiers here: HomeHeaderView drives refresh().
        if let week = model.stats[.week] {
            if week.countedDictations >= RhinoWrapped.minimumDictations {
                ThisWeekCard(week: week, openStats: openStats)
            } else {
                RhinoWrappedLockedView(count: week.countedDictations, shortcut: shortcut, scheme: colorScheme)
            }
        }
    }
}

struct ThisWeekCard: View {
    let week: RhinoStats
    let openStats: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        let palette = StatsPalette(scheme: colorScheme)
        let busiest = max(week.bars.map(\.words).max() ?? 0, 1)
        Button(action: openStats) {
            HStack(spacing: 20) {
                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(week.bars.enumerated()), id: \.element.id) { index, bar in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(index == week.bars.count - 1 ? palette.strong : palette.light)
                            .frame(width: 9, height: max(4, 44 * CGFloat(bar.words) / CGFloat(busiest)))
                    }
                }
                .frame(height: 44, alignment: .bottom)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(week.weekHeadline)
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.primary)
                    Text(week.weekSubline)
                        .scaledFont(size: 12.5)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 8)
                Text("See your stats →")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(palette.link)
                    .underline(hovered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.tint))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.tintBorder, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Open Stats")
    }
}

// MARK: - Home: Recent

/// The last three dictations on one line each, with a link to the full History tab.
struct HomeRecentSection: View {
    let openHistory: () -> Void
    @State private var rows: [Recording] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent")
                    .scaledFont(size: 15, weight: .semibold)
                Spacer()
                LinkButton(title: "All history →", action: openHistory)
            }
            if loaded && rows.isEmpty {
                Text("Your dictations will show up here.")
                    .scaledFont(size: 13)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 11)
            } else {
                VStack(spacing: 0) {
                    Divider()
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, recording in
                        Button(action: openHistory) {
                            HStack(spacing: 14) {
                                Text(Self.when(recording.timestamp))
                                    .foregroundColor(.secondary)
                                    .frame(width: 70, alignment: .leading)
                                Text(recording.sourceAppName ?? "—")
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(width: 76, alignment: .leading)
                                Text(recording.transcription.replacingOccurrences(of: "\n", with: " "))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer(minLength: 0)
                            }
                            .scaledFont(size: 13)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if index < rows.count - 1 { Divider() }
                    }
                }
            }
        }
        .onAppear(perform: reload)
        .onReceive(NotificationCenter.default.publisher(
            for: RecordingStore.recordingsDidUpdateNotification)) { _ in reload() }
    }

    private func reload() {
        Task {
            let fresh = (try? await RecordingStore.shared.fetchRecentDictations(limit: 3)) ?? []
            if fresh != rows { rows = fresh }
            loaded = true
        }
    }

    /// "9:41 AM" today; "Yesterday"; then "Nov 22".
    static func when(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

/// Blue text link ("All history →") with a hover underline.
struct LinkButton: View {
    let title: String
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 12.5, weight: .semibold)
                .foregroundColor(StatsPalette(scheme: colorScheme).link)
                .underline(hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

// MARK: - Stats tab

struct StatsTabView: View {
    @ObservedObject private var model = RhinoStatsModel.shared
    @State private var range: StatsRange = .week
    @State private var anchor = ViewAnchor()
    @Environment(\.colorScheme) private var colorScheme

    private var palette: StatsPalette { StatsPalette(scheme: colorScheme) }

    private var shortcut: String {
        RecordingTriggerSet.load(from: AppPreferences.shared.recordingTriggers).primaryDescription
    }

    var body: some View {
        let current = model.stats[range]
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header(current)
                if let current {
                    kpiRow(current)
                    HStack(alignment: .top, spacing: 12) {
                        wordsChart(current)
                        appsCard(current)
                    }
                    streakCard(current)
                    wrappedSection(current)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                }
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 28)
            .padding(.top, 26)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ThemePalette.windowBackground(colorScheme))
        .onAppear { model.refresh(range) }
        .onChange(of: range) { _, new in model.refresh(new) }
        .onReceive(NotificationCenter.default.publisher(
            for: RecordingStore.recordingsDidUpdateNotification)) { _ in model.refresh() }
    }

    // MARK: Header

    private func header(_ stats: RhinoStats?) -> some View {
        HStack(spacing: 16) {
            Text("Stats")
                .scaledFont(size: 26, weight: .bold)
            Picker("Range", selection: $range) {
                ForEach(StatsRange.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer()
            if let stats, let wrapped = stats.wrapped,
               stats.countedDictations >= RhinoWrapped.minimumDictations {
                let dark = colorScheme == .dark
                Button {
                    RhinoWrappedSharer.share(wrapped, title: stats.wrappedTitle(),
                                             subtitle: stats.shareSubtitle(),
                                             scheme: colorScheme, from: anchor.view)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share \(stats.shareLabel())")
                    }
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(dark ? .black : .white)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(dark ? Color(white: 0.94) : Color(red: 0.114, green: 0.114, blue: 0.122)))
                    .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                .buttonStyle(.plain)
                .background(AnchorView(anchor: anchor))
                .help("Share this range's Wrapped as an image (stats only, no transcripts)")
            }
        }
    }

    // MARK: KPIs

    private func kpiRow(_ stats: RhinoStats) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(stats.kpis()) { kpi in
                VStack(alignment: .leading, spacing: 4) {
                    Text(kpi.label)
                        .scaledFont(size: 11.5)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(kpi.value)
                            .scaledFont(size: 24, weight: .bold)
                        if !kpi.unit.isEmpty {
                            Text(kpi.unit)
                                .scaledFont(size: 12, weight: .medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    Text(kpi.note)
                        .scaledFont(size: 11.5, weight: .semibold)
                        .foregroundColor(color(kpi.trend))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .modifier(StatsCard())
            }
        }
    }

    private func color(_ trend: RhinoStats.KPI.Trend) -> Color {
        switch trend {
        case .up: return palette.link
        case .down: return palette.down
        case .flat, .context: return .secondary
        }
    }

    // MARK: Words chart

    private func wordsChart(_ stats: RhinoStats) -> some View {
        let bars = stats.bars
        let busiest = max(bars.map(\.words).max() ?? 0, 1)
        let spacing: CGFloat = bars.count > 16 ? 4 : bars.count > 8 ? 12 : 18
        let label = stats.barsByMonth
            ? Date.FormatStyle().month(.abbreviated).year()
            : Date.FormatStyle().month(.abbreviated).day()
        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Words dictated")
                    .scaledFont(size: 14, weight: .semibold)
                Spacer()
                Text(stats.chartNote())
                    .scaledFont(size: 12)
                    .foregroundColor(.secondary)
            }
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(bars.enumerated()), id: \.element.id) { index, bar in
                    UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4, style: .continuous)
                        .fill(index == bars.count - 1 ? palette.strong : palette.light)
                        .frame(maxWidth: 48)
                        .frame(height: max(2, 140 * CGFloat(bar.words) / CGFloat(busiest)))
                        .frame(maxWidth: .infinity)
                        .help("\(bar.start.formatted(label)): \(RhinoStats.wordsText(bar.words)) words")
                }
            }
            .frame(height: 150, alignment: .bottom)
            .padding(.top, 18)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.secondary.opacity(0.25)).frame(height: 1) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Words dictated per \(stats.barsByMonth ? "month" : "day")")

            HStack {
                let labels = stats.axisLabels()
                ForEach(Array(labels.enumerated()), id: \.offset) { index, text in
                    Text(text)
                    if index < labels.count - 1 { Spacer() }
                }
            }
            .scaledFont(size: 11)
            .foregroundColor(.secondary)
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(StatsCard())
        .layoutPriority(1)
    }

    // MARK: Where you talk

    private func appsCard(_ stats: RhinoStats) -> some View {
        let most = max(stats.apps.first?.words ?? 0, 1)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Where you talk")
                .scaledFont(size: 14, weight: .semibold)
                .padding(.bottom, 4)
            if stats.apps.isEmpty {
                Text(stats.totals.dictations == 0 ? "No dictations in this range yet." : "No app info yet.")
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
            }
            ForEach(stats.apps) { app in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(app.name)
                            .scaledFont(size: 12.5, weight: .semibold)
                            .lineLimit(1)
                        Spacer()
                        Text("\(RhinoWrapped.compact(app.words)) words")
                            .scaledFont(size: 12.5)
                            .foregroundColor(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(palette.track)
                            Capsule().fill(palette.strong)
                                .frame(width: max(6, geo.size.width * CGFloat(app.words) / CGFloat(most)))
                        }
                    }
                    .frame(height: 6)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(width: 250, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .modifier(StatsCard())
    }

    // MARK: Streak

    private func streakCard(_ stats: RhinoStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("Streak")
                    .scaledFont(size: 14, weight: .semibold)
                Text(stats.currentStreak == 1 ? "1 day now" : "\(stats.currentStreak) days now")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(stats.currentStreak > 0 ? palette.link : .secondary)
                    .padding(.leading, 12)
                Text("best \(stats.bestStreak) · last \(RhinoStats.heatmapWeeks) weeks")
                    .scaledFont(size: 12)
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
            }
            HStack(alignment: .top, spacing: 4) {
                ForEach(Array(stats.heatmap.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 4) {
                        ForEach(Array(week.enumerated()), id: \.offset) { _, level in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(level < 0 ? Color.clear : palette.heat(level))
                                .frame(width: 13, height: 13)
                        }
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Days with dictation over the last \(RhinoStats.heatmapWeeks) weeks")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(StatsCard())
    }

    // MARK: Wrapped

    @ViewBuilder
    private func wrappedSection(_ stats: RhinoStats) -> some View {
        if stats.countedDictations < RhinoWrapped.minimumDictations {
            RhinoWrappedLockedView(count: stats.countedDictations, shortcut: shortcut, scheme: colorScheme)
        } else if let wrapped = stats.wrapped {
            RhinoWrappedCardView(wrapped: wrapped, scheme: colorScheme,
                                 title: stats.wrappedTitle(),
                                 subtitle: "updates after every dictation")
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(stats.wrappedTitle())
                    .scaledFont(size: 15, weight: .bold)
                Text("No dictations in this range yet. Hold \(shortcut) and say something.")
                    .scaledFont(size: 12.5)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(palette.tint))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(palette.tintBorder, lineWidth: 1))
        }
    }
}

/// Bordered card, as in the mockup and Home's stats strip.
private struct StatsCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(ThemePalette.cardBackground(colorScheme)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ThemePalette.cardBorder(colorScheme), lineWidth: 1))
    }
}
