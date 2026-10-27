import SwiftUI
import SwiftData

/// Root of the app. One NavigationSplitView that adapts by size class, not orientation:
/// - compact (iPhone Duo folded, 5.4" outer): a single stack, list -> detail push.
/// - regular (Duo unfolded 7.6" inner, iPad, Split View): truck list beside a real detail pane
///   (door board or the selected truck), never a stretched phone layout.
/// Selection lives in @SceneStorage so folding / unfolding keeps the truck you were on.
struct BoardView: View {
    static let doorsTag = "__doors"

    @Environment(\.modelContext) private var context
    @Query(sort: \Visit.arrivedAt) private var visits: [Visit]

    @SceneStorage("docktalk.selection") private var selectionStore: String = ""
    @AppStorage("docktalk.site") private var site: String = "Main DC"
    @AppStorage("docktalk.doors") private var doorCount: Int = 8
    @AppStorage("docktalk.free") private var freeMinutes: Int = 120
    @AppStorage("docktalk.rate") private var rate: Int = 60

    @State private var now = Date()
    @State private var showAdd = false
    @State private var showSettings = false

    private var selection: Binding<String?> {
        Binding(
            get: { selectionStore.isEmpty ? nil : selectionStore },
            set: { selectionStore = $0 ?? "" }
        )
    }

    private var selectedVisit: Visit? { visits.first { $0.uid == selectionStore } }
    private var active: [Visit] { visits.filter { $0.status != .done } }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle(site)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Settings", systemImage: "slider.horizontal.3") { showSettings = true }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Check in", systemImage: "plus") { showAdd = true }
                    }
                }
        } detail: {
            NavigationStack {
                detail
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showAdd) {
            VisitForm(visit: nil) { new in
                context.insert(new)
                selectionStore = new.uid
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(site: $site, doorCount: $doorCount, freeMinutes: $freeMinutes, rate: $rate, visits: visits, now: now)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = .now
            }
        }
    }

    // MARK: sidebar

    private var sidebar: some View {
        List(selection: selection) {
            Section {
                StatsStrip(active: active, all: visits, doorCount: doorCount, freeMinutes: freeMinutes, now: now)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                Label("Door board", systemImage: "square.grid.3x3.fill")
                    .tag(Self.doorsTag)
            }
            ForEach(VisitStatus.allCases) { status in
                let rows = visits.filter { $0.status == status }
                Section("\(status.title) (\(rows.count))") {
                    if rows.isEmpty {
                        Text(status == .waiting ? "No trucks waiting" : "None")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rows) { v in
                        VisitRow(visit: v, now: now, freeMinutes: freeMinutes)
                            .tag(v.uid)
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(rows[i]) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if visits.isEmpty {
                ContentUnavailableView {
                    Label("Yard is empty", systemImage: "truck.box")
                } description: {
                    Text("Check in the first truck, or paste a driver's DOCKTALK text in Settings.")
                } actions: {
                    Button("Check in truck") { showAdd = true }.buttonStyle(.borderedProminent)
                }
            }
        }
    }

    // MARK: detail

    @ViewBuilder
    private var detail: some View {
        if let v = selectedVisit {
            VisitDetail(visit: v, now: now, doorCount: doorCount, freeMinutes: freeMinutes, rate: rate, site: site, takenDoors: takenDoors(excluding: v), freeDoor: firstFreeDoor())
        } else {
            DoorBoard(doorCount: doorCount, visits: active, now: now, freeMinutes: freeMinutes) { door in
                guard let next = visits.first(where: { $0.status == .waiting }) else { return }
                next.assign(door: door)
                selectionStore = next.uid
            } onSelect: { v in
                selectionStore = v.uid
            }
        }
    }

    private func takenDoors(excluding v: Visit) -> Set<Int> {
        Set(active.filter { $0.door > 0 && $0.uid != v.uid }.map(\.door))
    }

    private func firstFreeDoor() -> Int? {
        let taken = Set(active.filter { $0.door > 0 }.map(\.door))
        return (1...max(1, doorCount)).first { !taken.contains($0) }
    }
}

// MARK: - pieces

struct StatsStrip: View {
    let active: [Visit]
    let all: [Visit]
    let doorCount: Int
    let freeMinutes: Int
    let now: Date

    var body: some View {
        let atRisk = active.filter { $0.risk(now: now, freeMinutes: freeMinutes) != .ok }.count
        let avg = all.isEmpty ? 0 : all.map { $0.dwellMinutes(now: now) }.reduce(0, +) / all.count
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { tiles(atRisk: atRisk, avg: avg) }
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { tile("On site", "\(active.count)"); tile("At doors", "\(active.filter { $0.door > 0 }.count)/\(doorCount)") }
                GridRow { tile("Avg dwell", Fmt.dwell(avg)); tile("At risk", "\(atRisk)", alert: atRisk > 0) }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func tiles(atRisk: Int, avg: Int) -> some View {
        tile("On site", "\(active.count)")
        tile("At doors", "\(active.filter { $0.door > 0 }.count)/\(doorCount)")
        tile("Avg dwell", Fmt.dwell(avg))
        tile("At risk", "\(atRisk)", alert: atRisk > 0)
    }

    private func tile(_ k: String, _ v: String, alert: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased()).font(.caption2.monospaced().weight(.semibold)).foregroundStyle(.secondary)
            Text(v).font(.title2.weight(.heavy).width(.condensed)).foregroundStyle(alert ? Palette.stop : .primary)
        }
        .frame(minWidth: 70, maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

struct DoorTag: View {
    let door: Int
    var size: CGFloat = 50

    var body: some View {
        VStack(spacing: 0) {
            Text("DOOR").font(.system(size: size * 0.18, weight: .semibold, design: .monospaced))
            Text(door > 0 ? "\(door)" : "--").font(.system(size: size * 0.5, weight: .heavy).width(.condensed))
        }
        .frame(width: size, height: size)
        .foregroundStyle(door > 0 ? Palette.asphalt : .primary)
        .background(door > 0 ? Palette.signal : Color.secondary.opacity(0.18), in: .rect(cornerRadius: size * 0.14))
    }
}

struct VisitRow: View {
    let visit: Visit
    let now: Date
    let freeMinutes: Int

    var body: some View {
        let r = visit.risk(now: now, freeMinutes: freeMinutes)
        HStack(spacing: 12) {
            DoorTag(door: visit.door)
            VStack(alignment: .leading, spacing: 2) {
                Text(visit.name).font(.headline).lineLimit(1)
                Text([visit.carrier, visit.ref, visit.outbound ? "PICKUP" : "DROP"].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Text(Fmt.dwell(visit.dwellMinutes(now: now)))
                .font(.title3.monospaced().weight(.bold))
                .foregroundStyle(visit.status == .done ? .secondary : r.color)
        }
        .opacity(visit.status == .done ? 0.6 : 1)
        .accessibilityElement(children: .combine)
    }
}

struct DoorBoard: View {
    let doorCount: Int
    let visits: [Visit]
    let now: Date
    let freeMinutes: Int
    let onFreeDoor: (Int) -> Void
    let onSelect: (Visit) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 10)], spacing: 10) {
                ForEach(1...max(1, doorCount), id: \.self) { d in
                    if let v = visits.first(where: { $0.door == d }) {
                        Button { onSelect(v) } label: { cell(d, v) }.buttonStyle(.plain)
                    } else {
                        Button { onFreeDoor(d) } label: { cell(d, nil) }.buttonStyle(.plain)
                    }
                }
            }
            .padding()
            Text("Tap an open door to assign the longest-waiting truck. Red = past \(freeMinutes) min free time.")
                .font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
        }
        .navigationTitle("Door board")
    }

    private func cell(_ d: Int, _ v: Visit?) -> some View {
        let color = v.map { $0.risk(now: now, freeMinutes: freeMinutes).color } ?? .clear
        return VStack(alignment: .leading, spacing: 6) {
            Text("DOOR").font(.caption2.monospaced().weight(.semibold)).foregroundStyle(.secondary)
            Text("\(d)").font(.system(size: 40, weight: .heavy).width(.condensed))
            Spacer(minLength: 0)
            if let v {
                Text(v.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(v.status == .loading ? "loading" : "at door") · \(Fmt.dwell(v.dwellMinutes(now: now)))")
                    .font(.caption.monospaced()).foregroundStyle(color)
            } else {
                Text("Open").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.go)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        .padding(10)
        .background(v == nil ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.background.secondary), in: .rect(cornerRadius: 12))
        .overlay(alignment: .top) {
            if v != nil { UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12).fill(color == .clear ? Palette.signal : color).frame(height: 6) }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: v == nil ? [5, 4] : []))
        }
        .contentShape(.rect)
    }
}
