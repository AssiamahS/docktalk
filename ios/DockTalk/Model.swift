import Foundation
import SwiftData
import SwiftUI

enum VisitStatus: String, CaseIterable, Codable, Identifiable {
    case waiting, door, loading, done
    var id: String { rawValue }

    var title: String {
        switch self {
        case .waiting: "Waiting in yard"
        case .door: "At door"
        case .loading: "Loading / unloading"
        case .done: "Done today"
        }
    }

    var next: VisitStatus? {
        switch self {
        case .waiting: .door
        case .door: .loading
        case .loading: .done
        case .done: nil
        }
    }

    var nextAction: String {
        switch self {
        case .waiting: "Send to door"
        case .door: "Start loading"
        case .loading: "Mark done"
        case .done: ""
        }
    }
}

enum Risk { case ok, warn, stop
    var color: Color {
        switch self {
        case .ok: Palette.go
        case .warn: Palette.warn
        case .stop: Palette.stop
        }
    }
    var label: String {
        switch self {
        case .ok: "On time"
        case .warn: "Near free-time limit"
        case .stop: "Detention"
        }
    }
}

@Model
final class Visit {
    var uid: String = UUID().uuidString
    var name: String = ""
    var phone: String = ""
    var carrier: String = ""
    var ref: String = ""
    var trailer: String = ""
    var outbound: Bool = false
    var notes: String = ""
    var statusRaw: String = VisitStatus.waiting.rawValue
    var door: Int = 0
    var arrivedAt: Date = Date()
    var doorAt: Date?
    var loadingAt: Date?
    var doneAt: Date?

    init(name: String, phone: String = "", carrier: String = "", ref: String = "", trailer: String = "", outbound: Bool = false, notes: String = "") {
        self.name = name
        self.phone = phone
        self.carrier = carrier
        self.ref = ref
        self.trailer = trailer
        self.outbound = outbound
        self.notes = notes
    }

    var status: VisitStatus {
        get { VisitStatus(rawValue: statusRaw) ?? .waiting }
        set { statusRaw = newValue.rawValue }
    }

    func dwellMinutes(now: Date) -> Int {
        max(0, Int((doneAt ?? now).timeIntervalSince(arrivedAt) / 60))
    }

    func risk(now: Date, freeMinutes: Int) -> Risk {
        let d = dwellMinutes(now: now)
        if d >= freeMinutes { return .stop }
        if d >= freeMinutes - 30 { return .warn }
        return .ok
    }

    func detentionCost(now: Date, freeMinutes: Int, rate: Int) -> Int {
        let over = dwellMinutes(now: now) - freeMinutes
        guard over > 0 else { return 0 }
        return Int((Double(over) / 60).rounded(.up)) * rate
    }

    func advance(freeDoor: Int?) {
        guard let n = status.next else { return }
        if n == .door, door == 0, let d = freeDoor { door = d }
        status = n
        switch n {
        case .door: doorAt = .now
        case .loading: loadingAt = .now
        case .done: doneAt = .now
        case .waiting: break
        }
    }

    func assign(door d: Int) {
        door = d
        if status == .waiting {
            status = .door
            doorAt = .now
        }
    }
}

enum Fmt {
    static func dwell(_ m: Int) -> String {
        m < 60 ? "\(m)m" : "\(m / 60)h" + String(format: "%02d", m % 60)
    }
    static func clock(_ d: Date?) -> String {
        guard let d else { return "-" }
        return d.formatted(date: .omitted, time: .shortened)
    }
}

enum Palette {
    static let signal = Color(red: 1.0, green: 0.77, blue: 0.0)
    static let asphalt = Color(red: 0.086, green: 0.094, blue: 0.11)
    static let go = Color(red: 0.21, green: 0.76, blue: 0.48)
    static let warn = Color(red: 1.0, green: 0.62, blue: 0.10)
    static let stop = Color(red: 1.0, green: 0.35, blue: 0.32)
}
