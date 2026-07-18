import AppKit

// WattMeter 앱 아이콘 생성: 그라디언트 배경(초록→파랑) 위에 흰 번개.
// 정확한 픽셀 크기의 NSBitmapImageRep에 직접 렌더링(Retina 2x 스케일 오염 방지) → .iconset.
// 사용: swift makeicon.swift <출력_iconset_경로>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)   // 1x (스케일 1:1)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // 배경: 애플 스타일 라운드 스퀘어
    let inset = s * 0.06
    let rect = NSRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
    let radius = (s - 2*inset) * 0.2237
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    let grad = NSGradient(colors: [
        NSColor(calibratedRed: 0.16, green: 0.78, blue: 0.42, alpha: 1),  // green
        NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.90, alpha: 1),  // blue
    ])!
    grad.draw(in: rect, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // 번개 (별도 이미지에서 흰색 틴트 후 합성)
    if let bolt = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil) {
        let cfg = NSImage.SymbolConfiguration(pointSize: s * 0.5, weight: .bold)
        let sym = bolt.withSymbolConfiguration(cfg) ?? bolt
        sym.isTemplate = true
        let bs = sym.size
        let scale = (s * 0.52) / max(bs.width, bs.height)
        let dw = bs.width * scale, dh = bs.height * scale

        let tinted = NSImage(size: NSSize(width: dw, height: dh))
        tinted.lockFocus()
        let tr = NSRect(x: 0, y: 0, width: dw, height: dh)
        sym.draw(in: tr)
        NSColor.white.set()
        tr.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let dr = NSRect(x: (s - dw)/2, y: (s - dh)/2, width: dw, height: dh)
        tinted.draw(in: dr)
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// .iconset 규약: 파일명은 '포인트' 기준, 실제 픽셀은 @2x=2배.
let sizes: [(Int, String)] = [
    (16,"icon_16x16.png"),   (32,"icon_16x16@2x.png"),
    (32,"icon_32x32.png"),   (64,"icon_32x32@2x.png"),
    (128,"icon_128x128.png"), (256,"icon_128x128@2x.png"),
    (256,"icon_256x256.png"), (512,"icon_256x256@2x.png"),
    (512,"icon_512x512.png"), (1024,"icon_512x512@2x.png"),
]
for (px, name) in sizes {
    try! render(px).write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}
print("✅ iconset: \(outDir)")
