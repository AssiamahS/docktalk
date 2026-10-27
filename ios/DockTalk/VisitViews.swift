import SwiftUI
import SwiftData

struct VisitDetail: View {
    @Bindable var visit: Visit
    let now: Date
    let doorCount: Int
    let freeMinutes: Int
    let rate: Int
    let site: String
    let takenDoors: Set<Int>
    let freeDoor: Int?

    @Environment(\.openURL) private var openURL
    @State private var editing = false

    var body: some View {
        let risk = visit.risk(now: now, freeMinutes: freeMinutes)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    DoorTag(door: visit.door, size: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(visit.name).font(.largeTitle.weight(.heavy).width(.condensed)).lineLimit(2)
                        HStack {
                            pill(visit.status.title, .secondary.opacity(0.2), .primary)
                            if visit.status != .done { pill(risk.label, risk.color, .white) }
                        }
                    }
                }

                Grid(alignment: .leading, horizontalSpacing: 1, verticalSpacing: 1) {
                    GridRow { fact("Dwell", Fmt.dwell(visit.dwellMinutes(now: now))); fact("Est. detention", "$\(visit.detentionCost(now: now, freeMinutes: freeMinutes, rate: rate))") }
                    GridRow { fact("Carrier", visit.carrier); fact("PO / Load", visit.ref) }
                    GridRow { fact("Trailer", visit.trailer); fact("Type", visit.outbound ? "Pickup" : "Drop") }
                }
                .background(.secondary.opacity(0.25))
                .clipShape(.rect(cornerRadius: 12))

                ViewThatFits(in: .horizontal) {
                    HStack { actionButtons }
                    VStack(alignment: .leading) { actionButtons }
                }

                if visit.status != .done {
                    Text("ASSIGN DOOR").font(.caption.monospaced().weight(.bold)).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 6)], spacing: 6) {
                        ForEach(1...max(1, doorCount), id: \.self) { d in
                            let taken = takenDoors.contains(d)
                            Button { visit.assign(door: d) } label: {
                                Text("\(d)").font(.title3.weight(.heavy).width(.condensed))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .strikethrough(taken)
                            }
                            .buttonStyle(.bordered)
                            .tint(visit.door == d ? Palette.signal : .secondary)
                            .disabled(taken)
                        }
                    }
                }

                Text("TIMELINE").font(.caption.monospaced().weight(.bold)).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 10) {
                    step("Checked in", visit.arrivedAt)
                    step("At door", visit.doorAt)
                    step("Loading started", visit.loadingAt)
                    step("Released", visit.doneAt)
                }
                if !visit.notes.isEmpty {
                    Text("NOTES").font(.caption.monospaced().weight(.bold)).foregroundStyle(.secondary)
                    Text(visit.notes)
                }
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(visit.door > 0 ? "Door \(visit.door)" : "Yard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button("Edit") { editing = true } }
        .sheet(isPresented: $editing) { VisitForm(visit: visit) { _ in } }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if visit.status.next != nil {
            Button(visit.status.nextAction) {
                withAnimation { visit.advance(freeDoor: freeDoor) }
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(Palette.asphalt)
        }
        if !visit.phone.isEmpty {
            Button(visit.door > 0 ? "Text door \(visit.door)" : "Text driver", systemImage: "message.fill") {
                if let url = Self.smsURL(visit.phone, body: doorMessage) { openURL(url) }
            }
            .buttonStyle(.bordered)
            Button("Call", systemImage: "phone.fill") {
                if let url = URL(string: "tel:\(Self.digits(visit.phone))") { openURL(url) }
            }
            .buttonStyle(.bordered)
        } else {
            Text("No cell on file - edit to add one.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var doorMessage: String {
        let first = visit.name.split(separator: " ").first.map(String.init) ?? visit.name
        if visit.door > 0 {
            return "\(site): \(first), back into DOOR \(visit.door) now. Ref \(visit.ref). Reply here if you can't."
        }
        return "\(site): \(first), you're checked in (\(Fmt.clock(visit.arrivedAt))). We'll text your door. Stay with your truck."
    }

    static func digits(_ s: String) -> String { s.filter { $0.isNumber || $0 == "+" } }

    static func smsURL(_ phone: String, body: String) -> URL? {
        var c = URLComponents()
        c.scheme = "sms"
        c.path = digits(phone)
        c.queryItems = [URLQueryItem(name: "body", value: body)]
        // iOS Messages expects sms:<num>&body=...
        guard let s = c.string?.replacingOccurrences(of: "?body=", with: "&body=") else { return nil }
        return URL(string: s)
    }

    private func pill(_ t: String, _ bg: Color, _ fg: Color) -> some View {
        Text(t.uppercased()).font(.caption2.monospaced().weight(.bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .foregroundStyle(fg).background(bg, in: .capsule)
    }

    private func fact(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k.uppercased()).font(.caption2.monospaced().weight(.semibold)).foregroundStyle(.secondary)
            Text(v.isEmpty ? "-" : v).font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background)
    }

    private func step(_ label: String, _ date: Date?) -> some View {
        HStack(spacing: 10) {
            Circle().fill(date == nil ? Color.secondary.opacity(0.3) : Palette.signal).frame(width: 12, height: 12)
            Text(label)
            Spacer()
            Text(Fmt.clock(date)).font(.callout.monospaced()).foregroundStyle(.secondary)
        }
    }
}

struct VisitForm: View {
    let visit: Visit?
    let onSave: (Visit) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var phone = ""
    @State private var carrier = ""
    @State private var ref = ""
    @State private var trailer = ""
    @State private var outbound = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Driver") {
                    TextField("Name", text: $name).textContentType(.name)
                    TextField("Cell (for door text)", text: $phone).keyboardType(.phonePad).textContentType(.telephoneNumber)
                }
                Section("Load") {
                    TextField("Carrier", text: $carrier)
                    TextField("PO / Load / BOL #", text: $ref)
                    TextField("Trailer #", text: $trailer)
                    Picker("Type", selection: $outbound) {
                        Text("Inbound / drop").tag(false)
                        Text("Outbound / pickup").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Notes") { TextField("Reefer, hazmat, lumper...", text: $notes, axis: .vertical) }
            }
            .navigationTitle(visit == nil ? "Check in truck" : "Edit truck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let v = visit else { return }
        name = v.name; phone = v.phone; carrier = v.carrier; ref = v.ref
        trailer = v.trailer; outbound = v.outbound; notes = v.notes
    }

    private func save() {
        let target = visit ?? Visit(name: name)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.phone = phone
        target.carrier = carrier
        target.ref = ref
        target.trailer = trailer
        target.outbound = outbound
        target.notes = notes
        onSave(target)
        dismiss()
    }
}

struct SettingsSheet: View {
    @Binding var site: String
    @Binding var doorCount: Int
    @Binding var freeMinutes: Int
    @Binding var rate: Int
    let visits: [Visit]
    let now: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var pasted = ""
    @State private var importResult = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Site") {
                    TextField("Site name", text: $site)
                    Stepper("Dock doors: \(doorCount)", value: $doorCount, in: 1...60)
                    Stepper("Free time: \(freeMinutes) min", value: $freeMinutes, in: 15...600, step: 15)
                    Stepper("Detention: $\(rate)/hr", value: $rate, in: 0...500, step: 5)
                }
                Section {
                    TextField("Paste DOCKTALK CHECKIN texts", text: $pasted, axis: .vertical).lineLimit(3...8)
                    Button("Add to board") {
                        let rows = CheckinText.parse(pasted)
                        rows.forEach { context.insert($0) }
                        importResult = rows.isEmpty ? "No DOCKTALK CHECKIN text found" : "Added \(rows.count)"
                        if !rows.isEmpty { pasted = "" }
                    }
                    if !importResult.isEmpty { Text(importResult).foregroundStyle(.secondary) }
                } header: {
                    Text("Driver texts")
                } footer: {
                    Text("Drivers who scan the gate QR (web check-in) text the dock phone. Copy those messages and paste here.")
                }
                Section("Records") {
                    ShareLink(item: csv, preview: SharePreview("DockTalk visits.csv")) { Label("Export CSV (detention proof)", systemImage: "square.and.arrow.up") }
                    Button("Clear finished visits", role: .destructive) {
                        visits.filter { $0.status == .done }.forEach { context.delete($0) }
                    }
                }
                Section { Text("All data stays on this iPhone. No account, no server.").foregroundStyle(.secondary) }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var csv: String {
        let iso = ISO8601DateFormatter()
        let f: (Date?) -> String = { $0.map(iso.string(from:)) ?? "" }
        let header = "name,phone,carrier,ref,trailer,type,door,status,arrivedAt,doorAt,loadingAt,doneAt,dwellMinutes,estDetentionUSD"
        let rows = visits.map { v in
            [v.name, v.phone, v.carrier, v.ref, v.trailer, v.outbound ? "outbound" : "inbound", "\(v.door)", v.status.rawValue,
             f(v.arrivedAt), f(v.doorAt), f(v.loadingAt), f(v.doneAt), "\(v.dwellMinutes(now: now))",
             "\(v.detentionCost(now: now, freeMinutes: freeMinutes, rate: rate))"]
                .map { "\"" + $0.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
                .joined(separator: ",")
        }
        return ([header] + rows).joined(separator: "\n")
    }
}

/// Same wire format as web/shared.js
enum CheckinText {
    static func parse(_ text: String) -> [Visit] {
        let blocks = text.components(separatedBy: "DOCKTALK CHECKIN").dropFirst()
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return blocks.compactMap { block in
            var f: [String: String] = [:]
            for line in block.split(whereSeparator: \.isNewline) {
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                f[parts[0].trimmingCharacters(in: .whitespaces).lowercased()] = parts[1].trimmingCharacters(in: .whitespaces)
            }
            guard let name = f["driver"], !name.isEmpty else { return nil }
            let v = Visit(name: name, phone: f["cell"] ?? "", carrier: f["carrier"] ?? "", ref: f["ref"] ?? "",
                          trailer: f["trailer"] ?? "", outbound: (f["type"] ?? "").lowercased().contains("out"), notes: f["notes"] ?? "")
            if let a = f["arrived"], let d = iso.date(from: a) { v.arrivedAt = d }
            return v
        }
    }
}
