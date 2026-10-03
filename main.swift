import Cocoa
import IOKit

// 메뉴바 전력 모니터: AppleSmartBattery(IOKit)에서 충전 전력·시스템 소비·어댑터 W를 읽어 실시간 표시.
// 전력 균형:  어댑터입력 = 시스템소비 + 배터리로들어가는전력
//   배터리순전력 = 전압 × 전류(부호 있음; + 충전, - 방전)
//   소비 = 입력 - 배터리순전력
//
// Menu-bar power monitor. Reads AppleSmartBattery via IOKit and shows charge power,
// system draw, and adapter wattage in real time. Localized via .lproj (ko / en).

// MARK: - Localization

func T(_ key: String) -> String { NSLocalizedString(key, comment: "") }

// MARK: - Battery read

func batteryProps() -> [String: Any]? {
    let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard svc != 0 else { return nil }
    defer { IOObjectRelease(svc) }
    var props: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(svc, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let d = props?.takeRetainedValue() as? [String: Any] else { return nil }
    return d
}

struct PowerInfo {
    var valid = false        // 배터리 정보를 읽었는가 (데스크톱/오류 대비)
    var ext = false          // 어댑터 연결됨
    var charging = false
    var pct = 0              // 배터리 %
    var adapterW = 0         // 어댑터 정격 W
    var adapterDesc = ""
    var hasInput = false     // 어댑터 실측 입력 W를 얻었는가 (Apple Silicon만 제공)
    var inputW = 0.0         // 어댑터→시스템 총 입력 W
    var batteryNetW = 0.0    // 배터리 순전력(+충전/-방전) W
    var consumeW = 0.0       // 시스템 소비 W
    var hasConsume = false   // 소비 W를 신뢰 가능하게 산출했는가
    var cycle = 0
    var healthPct = 0        // 최대용량 %
    var tempC = Double.nan   // 배터리 온도 ℃
    var minsToFull = -1      // 완충까지 분 (-1 = 없음/계산중)
    var minsToEmpty = -1     // 방전까지 분
    var fullyCharged = false
}

func readPower() -> PowerInfo {
    var p = PowerInfo()
    guard let d = batteryProps() else { return p }
    p.valid = true
    let volt = (d["Voltage"] as? NSNumber)?.doubleValue ?? 0           // mV
    let amp  = Double((d["Amperage"] as? NSNumber)?.int64Value ?? 0)   // mA, 부호 있음
    p.ext = (d["ExternalConnected"] as? Bool) ?? false
    p.charging = (d["IsCharging"] as? Bool) ?? false
    p.fullyCharged = (d["FullyCharged"] as? Bool) ?? false
    p.pct = (d["CurrentCapacity"] as? NSNumber)?.intValue ?? 0
    p.cycle = (d["CycleCount"] as? NSNumber)?.intValue ?? 0
    if let ad = d["AdapterDetails"] as? [String: Any] {
        p.adapterW = (ad["Watts"] as? NSNumber)?.intValue ?? 0
        p.adapterDesc = (ad["Description"] as? String) ?? ""
    }
    // 어댑터 실측 입력: Apple Silicon은 PowerTelemetryData.SystemPowerIn(mW) 제공. Intel엔 없음.
    if let t = d["PowerTelemetryData"] as? [String: Any],
       let spin = (t["SystemPowerIn"] as? NSNumber)?.doubleValue, spin > 0 {
        p.inputW = spin / 1000.0
        p.hasInput = true
    }
    // 배터리 건강도(최대용량 %)
    if let mc = (d["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue,
       let dc = (d["DesignCapacity"] as? NSNumber)?.doubleValue, dc > 0 {
        p.healthPct = Int((mc / dc * 100).rounded())
    } else if let m = (d["MaximumCapacityPercent"] as? NSNumber)?.intValue {
        p.healthPct = m
    }
    // 온도: AppleSmartBattery "Temperature" 는 보통 centi-℃(예: 3012 → 30.12℃).
    // 값이 100 이상이면 켈빈으로 보고 보정.
    if let traw = (d["Temperature"] as? NSNumber)?.doubleValue, traw > 0 {
        var c = traw / 100.0
        if c > 100 { c -= 273.15 }
        if c > -20 && c < 120 { p.tempC = c }
    }
    // 남은 시간: 65535/음수 = 계산 중.
    func mins(_ key: String) -> Int {
        let v = (d[key] as? NSNumber)?.intValue ?? -1
        return (v > 0 && v < 65535) ? v : -1
    }
    p.minsToFull  = mins("AvgTimeToFull")
    p.minsToEmpty = mins("AvgTimeToEmpty")

    p.batteryNetW = volt / 1000.0 * amp / 1000.0          // W (부호)
    if !p.ext {
        p.consumeW = max(0, -p.batteryNetW)               // 배터리 사용 중: 소비 = 방전량
        p.hasConsume = true
    } else if p.hasInput {
        p.consumeW = max(0, p.inputW - p.batteryNetW)     // AC + 실측 입력: 소비 = 입력 - 배터리순전력
        p.hasConsume = true
    } else {
        p.hasConsume = false                              // AC인데 실측 입력 없음(Intel 등) → 소비 불명
    }
    return p
}

// MARK: - Formatting

func w(_ v: Double) -> String { String(format: "%.1f", v) }
func hm(_ m: Int) -> String {
    if m < 0 { return T("time.estimating") }
    let h = m / 60, mm = m % 60
    return h > 0 ? String(format: T("time.hm"), h, mm) : String(format: T("time.m"), mm)
}

final class App: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var menu = NSMenu()
    var rows: [String: NSMenuItem] = [:]
    var timer: Timer?

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item.button?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        for key in ["bat", "time", "adapter", "input", "charge", "consume", "temp", "info"] {
            let mi = NSMenuItem(title: "", action: nil, keyEquivalent: ""); mi.isEnabled = false
            rows[key] = mi; menu.addItem(mi)
        }
        menu.insertItem(.separator(), at: 2)        // 배터리/시간 줄 아래 구분선
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: T("quit"), action: #selector(quit), keyEquivalent: "q"))
        item.menu = menu
        tick()
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common); timer = t
    }
    @objc func quit() { NSApp.terminate(nil) }

    func hide(_ key: String) { rows[key]?.isHidden = true }
    func show(_ key: String, _ title: String) { rows[key]?.isHidden = false; rows[key]?.title = title }

    func tick() {
        let p = readPower()
        guard p.valid else {
            item.button?.title = "🔌 " + T("menubar.nobattery")
            ["bat","time","adapter","input","charge","consume","temp"].forEach { hide($0) }
            show("info", "ⓘ " + T("info.nobattery"))
            return
        }

        // 메뉴바: 상황별 핵심 숫자
        let title: String
        if !p.ext {
            title = "🔋\(p.pct)% ↓\(w(p.consumeW))W"                 // 배터리 사용: 소비
        } else if p.charging || p.batteryNetW > 0.5 {
            let c = p.hasConsume ? " · \(w(p.consumeW))W" : ""
            title = "⚡\(w(p.batteryNetW))W\(c)"                     // 충전 · 소비
        } else if p.hasConsume {
            title = "🔌\(w(p.consumeW))W"                            // AC, 충전 안함: 소비
        } else {
            title = "🔌\(p.pct)%"                                   // AC지만 소비 불명(Intel 등)
        }
        item.button?.title = title

        // 드롭다운 상세
        let state = !p.ext ? T("state.onbattery")
                  : (p.charging ? T("state.charging")
                  : (p.fullyCharged ? T("state.full") : T("state.notcharging")))
        show("bat", "🔋 \(T("label.battery")): \(p.pct)%  ·  \(state)")

        // 남은 시간 (충전 중 → 완충까지 / 배터리 → 방전까지)
        if p.ext && p.charging && !p.fullyCharged {
            show("time", "⏱ \(T("label.tofull")): \(hm(p.minsToFull))")
        } else if !p.ext {
            show("time", "⏱ \(T("label.toempty")): \(hm(p.minsToEmpty))")
        } else { hide("time") }

        show("adapter", p.ext
            ? "🔌 \(T("label.adapter")): \(p.adapterW)W\(p.adapterDesc.isEmpty ? "" : " (\(p.adapterDesc))")"
            : "🔌 \(T("label.adapter")): \(T("adapter.none"))")

        if p.ext && p.hasInput {
            show("input", "⬇︎ \(T("label.input")): \(w(p.inputW)) W")
        } else { hide("input") }

        if p.batteryNetW > 0.1 {
            show("charge", "⚡ \(T("label.charge")): +\(w(p.batteryNetW)) W")
        } else if p.batteryNetW < -0.1 {
            show("charge", "⚡ \(T("label.discharge")): \(w(p.batteryNetW)) W")
        } else {
            show("charge", "⚡ \(T("label.charge")): — (\(T("state.idle")))")
        }

        if p.hasConsume {
            show("consume", "🔥 \(T("label.draw")): \(w(p.consumeW)) W")
        } else {
            show("consume", "🔥 \(T("label.draw")): — (\(T("draw.na")))")
        }

        if p.tempC.isFinite {
            show("temp", "🌡 \(T("label.temp")): \(String(format: "%.1f", p.tempC))℃")
        } else { hide("temp") }

        let health = p.healthPct > 0 ? " · \(T("label.maxcap")) \(p.healthPct)%" : ""
        show("info", "ⓘ \(T("label.cycles")) \(p.cycle)\(health)")
    }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.run()
