import AppKit

// App Store용 스크린샷 3종 생성 (2560x1600, 16:10). 앱의 실제 메뉴 드롭다운을
// 브랜드 그라디언트 배경 위에 얹은 마케팅 이미지. 한/영 각각 렌더.
// 사용: swift shots.swift <lang: ko|en> <iconPath> <outDir>

let lang = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "en"
let iconPath = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "assets/AppIcon.icns"
let outDir = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : "."
let ko = (lang == "ko")

let W: CGFloat = 2560, H: CGFloat = 1600

struct Scene {
    let headline: String, sub: String
    let menubar: String
    let rows: [String]
}

let scenes: [Scene] = ko ? [
    Scene(headline: "충전·소비 전력을 실시간으로", sub: "어댑터 입력, 배터리로 들어가는 W, 시스템 소비까지",
          menubar: "⚡38.2W · 14.1W",
          rows: ["🔋 배터리: 87%  ·  충전 중", "⏱ 완충까지: 42분",
                 "🔌 어댑터: 67W (USB-C Power Adapter)", "⬇︎ 입력(어댑터→): 66.5 W",
                 "⚡ 충전: +38.2 W", "🔥 시스템 소비: 14.1 W",
                 "🌡 배터리 온도: 30.7℃", "ⓘ 사이클 42 · 최대용량 98%"]),
    Scene(headline: "배터리 소비와 남은 시간을 한눈에", sub: "전원 없이 쓸 때 실제 소비 전력과 방전까지 시간",
          menubar: "🔋72% ↓9.8W",
          rows: ["🔋 배터리: 72%  ·  배터리 사용 중", "⏱ 방전까지: 5시간 12분",
                 "🔌 어댑터: 미연결", "⚡ 방전: -9.8 W",
                 "🔥 시스템 소비: 9.8 W", "🌡 배터리 온도: 29.4℃",
                 "ⓘ 사이클 42 · 최대용량 98%"]),
    Scene(headline: "사이클·건강도·온도까지", sub: "배터리 상태를 하나의 메뉴에서",
          menubar: "🔌7.3W",
          rows: ["🔋 배터리: 100%  ·  완충", "🔌 어댑터: 96W (USB-C Power Adapter)",
                 "⬇︎ 입력(어댑터→): 7.5 W", "⚡ 충전: — (대기)",
                 "🔥 시스템 소비: 7.3 W", "🌡 배터리 온도: 31.2℃",
                 "ⓘ 사이클 42 · 최대용량 98%"]),
] : [
    Scene(headline: "Live charge & draw power", sub: "Adapter input, watts into the battery, and system draw",
          menubar: "⚡38.2W · 14.1W",
          rows: ["🔋 Battery: 87%  ·  Charging", "⏱ Time to full: 42m",
                 "🔌 Adapter: 67W (USB-C Power Adapter)", "⬇︎ Input (adapter→): 66.5 W",
                 "⚡ Charge: +38.2 W", "🔥 System draw: 14.1 W",
                 "🌡 Battery temp: 30.7℃", "ⓘ Cycles 42 · Max capacity 98%"]),
    Scene(headline: "Battery draw & time left at a glance", sub: "Real power consumption and time to empty on battery",
          menubar: "🔋72% ↓9.8W",
          rows: ["🔋 Battery: 72%  ·  On battery", "⏱ Time to empty: 5h 12m",
                 "🔌 Adapter: Not connected", "⚡ Discharge: -9.8 W",
                 "🔥 System draw: 9.8 W", "🌡 Battery temp: 29.4℃",
                 "ⓘ Cycles 42 · Max capacity 98%"]),
    Scene(headline: "Cycles, health & temperature", sub: "Full battery status in a single menu",
          menubar: "🔌7.3W",
          rows: ["🔋 Battery: 100%  ·  Fully charged", "🔌 Adapter: 96W (USB-C Power Adapter)",
                 "⬇︎ Input (adapter→): 7.5 W", "⚡ Charge: — (idle)",
                 "🔥 System draw: 7.3 W", "🌡 Battery temp: 31.2℃",
                 "ⓘ Cycles 42 · Max capacity 98%"]),
]

let clock = ko ? "화 7월 7  오후 2:14" : "Tue Jul 7  2:14 PM"

func sf(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
    NSFont.systemFont(ofSize: size, weight: weight)
}
func mono(_ size: CGFloat, _ weight: NSFont.Weight = .medium) -> NSFont {
    NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
}

func render(_ sc: Scene) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // yTop 기준 좌표 도우미
    func text(_ s: String, _ font: NSFont, _ color: NSColor, x: CGFloat, yTop: CGFloat) {
        let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        NSAttributedString(string: s, attributes: a).draw(at: NSPoint(x: x, y: H - yTop - font.ascender - abs(font.descender)))
    }
    func textCenter(_ s: String, _ font: NSFont, _ color: NSColor, yTop: CGFloat) {
        let a: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let w = NSAttributedString(string: s, attributes: a).size().width
        text(s, font, color, x: (W - w)/2, yTop: yTop)
    }

    // 배경 그라디언트 (브랜드 초록→파랑)
    let bg = NSGradient(colors: [
        NSColor(calibratedRed: 0.13, green: 0.72, blue: 0.44, alpha: 1),
        NSColor(calibratedRed: 0.09, green: 0.46, blue: 0.86, alpha: 1)])!
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -60)

    // 아이콘
    if let icon = NSImage(contentsOfFile: iconPath) {
        let s: CGFloat = 150
        icon.draw(in: NSRect(x: (W - s)/2, y: H - 70 - s, width: s, height: s))
    }
    // 헤드라인 / 서브
    textCenter(sc.headline, sf(84, .bold), .white, yTop: 250)
    textCenter(sc.sub, sf(40, .regular), NSColor(white: 1, alpha: 0.9), yTop: 372)

    // 데스크톱 카드 (둥근 사각형)
    let card = NSRect(x: 480, y: H - 1500, width: 1600, height: 1010)  // yTop 490..1500
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor(white: 0, alpha: 0.28)
    sh.shadowBlurRadius = 40; sh.shadowOffset = NSSize(width: 0, height: -14); sh.set()
    let cardPath = NSBezierPath(roundedRect: card, xRadius: 26, yRadius: 26)
    NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.93, alpha: 1).setFill()
    cardPath.fill()
    NSGraphicsContext.restoreGraphicsState()
    cardPath.addClip()
    // 카드 내부 옅은 데스크톱 그라디언트
    NSGradient(colors: [NSColor(white: 0.95, alpha: 1), NSColor(white: 0.82, alpha: 1)])!
        .draw(in: card, angle: -90)

    // 메뉴바 스트립 (카드 상단)
    let barH: CGFloat = 52
    let bar = NSRect(x: card.minX, y: card.maxY - barH, width: card.width, height: barH)
    NSColor(white: 1, alpha: 0.55).setFill(); NSBezierPath(rect: bar).fill()
    NSColor(white: 0, alpha: 0.08).setFill()
    NSBezierPath(rect: NSRect(x: bar.minX, y: bar.minY, width: bar.width, height: 1)).fill()
    // 시계 (우측 끝)
    let clockFont = sf(26, .regular)
    let clockW = NSAttributedString(string: clock, attributes: [.font: clockFont]).size().width
    text(clock, clockFont, NSColor(white: 0.15, alpha: 1), x: card.maxX - clockW - 34, yTop: 490 + (barH - 26)/2 - 4)

    // 상태 항목 (선택된 파란 배경) — 시계 왼쪽
    let miFont = mono(28, .semibold)
    let miW = NSAttributedString(string: sc.menubar, attributes: [.font: miFont]).size().width
    let miPad: CGFloat = 16
    let miRectW = miW + miPad*2
    let miX = card.maxX - clockW - 34 - 28 - miRectW
    let miRect = NSRect(x: miX, y: bar.minY + 5, width: miRectW, height: barH - 10)
    NSColor(calibratedRed: 0.0, green: 0.48, blue: 1.0, alpha: 1).setFill()
    NSBezierPath(roundedRect: miRect, xRadius: 7, yRadius: 7).fill()
    text(sc.menubar, miFont, .white, x: miX + miPad, yTop: 490 + (barH - 28)/2 - 3)

    // 드롭다운 패널 (상태 항목 아래에 매달림)
    let rowFont = sf(33, .regular)
    let padX: CGFloat = 34, padY: CGFloat = 24, rowH: CGFloat = 58
    var maxRowW: CGFloat = 0
    for r in sc.rows { maxRowW = max(maxRowW, NSAttributedString(string: r, attributes: [.font: rowFont]).size().width) }
    let panelW = maxRowW + padX*2
    let sepCount = 1  // 배터리/시간 줄 아래 구분선 1개
    let panelH = CGFloat(sc.rows.count) * rowH + padY*2 + CGFloat(sepCount)*18
    let panelRight = miRect.maxX
    var panelX = panelRight - panelW
    if panelX < card.minX + 40 { panelX = card.minX + 40 }
    let panelTopY = bar.minY - 12
    let panel = NSRect(x: panelX, y: panelTopY - panelH, width: panelW, height: panelH)

    NSGraphicsContext.saveGraphicsState()
    let psh = NSShadow(); psh.shadowColor = NSColor(white: 0, alpha: 0.30)
    psh.shadowBlurRadius = 34; psh.shadowOffset = NSSize(width: 0, height: -10); psh.set()
    let panelPath = NSBezierPath(roundedRect: panel, xRadius: 16, yRadius: 16)
    NSColor(white: 0.99, alpha: 1).setFill(); panelPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // 행 그리기
    var yTop = (H - panel.maxY) + padY
    let rowStartTopBase = yTop
    _ = rowStartTopBase
    for (i, r) in sc.rows.enumerated() {
        text(r, rowFont, NSColor(white: 0.13, alpha: 1), x: panel.minX + padX, yTop: yTop + (rowH - 33)/2 - 2)
        yTop += rowH
        if i == 1 {  // 배터리/시간 줄 아래 구분선
            NSColor(white: 0.82, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: panel.minX + padX, y: H - yTop - 9, width: panelW - padX*2, height: 1.5)).fill()
            yTop += 18
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (i, sc) in scenes.enumerated() {
    let data = render(sc)
    let path = "\(outDir)/appstore_\(lang)_\(i+1).png"
    try! data.write(to: URL(fileURLWithPath: path))
    print("✅ \(path)")
}
