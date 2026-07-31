import AppKit
import Foundation

let canvasWidth: CGFloat = 1320
let canvasHeight: CGFloat = 2868

struct Slide {
    let background: String
    let screenshot: String
    let output: String
    let headline: String
    let subtitle: String
    let panelX: CGFloat
    let panelY: CGFloat
    let panelWidth: CGFloat
    let centerText: Bool
}

func argumentValue(_ name: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: name),
          CommandLine.arguments.indices.contains(index + 1) else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
guard let sourcePath = argumentValue("--source-dir") else {
    fatalError("Usage: swift scripts/generate_appstore_zh.swift --source-dir <path> [--background-dir <path>] [--output-dir <path>] [--app-icon <path>]")
}

let assetDir = projectRoot.appendingPathComponent("AppStoreAssets/Screenshots-6.9-ZH-1.1.0", isDirectory: true)
let sourceDir = URL(fileURLWithPath: sourcePath, isDirectory: true)
let backgroundDir = URL(
    fileURLWithPath: argumentValue("--background-dir") ?? assetDir.appendingPathComponent("backgrounds").path,
    isDirectory: true
)
let outputDir = URL(
    fileURLWithPath: argumentValue("--output-dir") ?? assetDir.path,
    isDirectory: true
)
let appIconURL = URL(
    fileURLWithPath: argumentValue("--app-icon")
        ?? projectRoot.appendingPathComponent("Assets.xcassets/AppIcon.appiconset/Gemini_Generated_Image_jwbm3gjwbm3gjwbm.png").path
)

let slides: [Slide] = [
    Slide(background: "01.png", screenshot: "3b37153a10394b69ed4ef644b0684f43.jpg", output: "01-clear-training-zh.png", headline: "更清晰的训练方式", subtitle: "计划清晰，执行专注。", panelX: 0, panelY: 0, panelWidth: 0, centerText: true),
    Slide(background: "02.png", screenshot: "4e36a7d29690cc33fc4ac3c5b74e0e61.jpg", output: "02-workout-rhythm-zh.png", headline: "每一组，都不掉节奏", subtitle: "进度、组数与休息计时，一目了然", panelX: 140, panelY: 700, panelWidth: 1040, centerText: false),
    Slide(background: "03.png", screenshot: "1f75a4a85fdb9b7e9991fe771161a633.jpg", output: "03-progress-zh.png", headline: "看见每一次积累", subtitle: "训练数据与周趋势，清晰呈现", panelX: 130, panelY: 690, panelWidth: 1060, centerText: false),
    Slide(background: "04.png", screenshot: "bdfd989583bf37154bf7d187e3d277b8.jpg", output: "04-weekly-plan-zh.png", headline: "一周训练，心里有数", subtitle: "力量、有氧与休息，统一安排", panelX: 135, panelY: 700, panelWidth: 1050, centerText: false),
    Slide(background: "05.png", screenshot: "fc3884e53ca197c41e4df15ac53c0090.jpg", output: "05-improvise-zh.png", headline: "计划有变，马上开练", subtitle: "切换即兴模式，按部位快速开练", panelX: 140, panelY: 710, panelWidth: 1040, centerText: false),
    Slide(background: "06.png", screenshot: "3dd3744f0bb498e157ed0f948f8ff551.jpg", output: "06-growth-zh.png", headline: "让坚持，持续升级", subtitle: "训练等级与成长记录，都在这里", panelX: 140, panelY: 700, panelWidth: 1040, centerText: false)
]

func rectFromTop(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: canvasHeight - y - height, width: width, height: height)
}

func image(at url: URL) -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        fatalError("Unable to load image: \(url.path)")
    }
    return image
}

func font(_ name: String, size: CGFloat, fallbackWeight: NSFont.Weight = .regular) -> NSFont {
    NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: fallbackWeight)
}

func drawText(_ text: String, rect: NSRect, font: NSFont, color: NSColor, alignment: NSTextAlignment, lineHeight: CGFloat? = nil) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    NSAttributedString(string: text, attributes: attributes).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

func drawRoundedScreenshot(_ screenshot: NSImage, x: CGFloat, y: CGFloat, width: CGFloat, cropTop: CGFloat = 130, radius: CGFloat = 64, shadowOpacity: Float = 0.18) -> NSRect {
    let sourceSize = screenshot.size
    let visibleHeight = sourceSize.height - cropTop
    let height = width * visibleHeight / sourceSize.width
    let destination = rectFromTop(x, y, width, height)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(CGFloat(shadowOpacity))
    shadow.shadowBlurRadius = 38
    shadow.shadowOffset = NSSize(width: 0, height: -18)
    shadow.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: destination, xRadius: radius, yRadius: radius).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: destination, xRadius: radius, yRadius: radius).addClip()
    let source = NSRect(x: 0, y: 0, width: sourceSize.width, height: visibleHeight)
    screenshot.draw(in: destination, from: source, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.72).setStroke()
    let border = NSBezierPath(roundedRect: destination.insetBy(dx: 1, dy: 1), xRadius: radius, yRadius: radius)
    border.lineWidth = 2
    border.stroke()
    return destination
}

func replaceProfileIdentity(panel: NSRect, panelWidth: CGFloat) {
    let scale = panelWidth / 1170
    let panelTop = canvasHeight - panel.maxY
    let avatarCenterX = panel.minX + 585 * scale
    let avatarCenterYFromTop = panelTop + (585 - 130) * scale
    let avatarRadius = 142 * scale
    let avatarRect = rectFromTop(avatarCenterX - avatarRadius, avatarCenterYFromTop - avatarRadius, avatarRadius * 2, avatarRadius * 2)

    let coverRect = rectFromTop(panel.minX + 390 * scale, panelTop + (400 - 130) * scale, 430 * scale, 410 * scale)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: coverRect, xRadius: 36 * scale, yRadius: 36 * scale).fill()

    NSGraphicsContext.saveGraphicsState()
    let circle = NSBezierPath(ovalIn: avatarRect)
    circle.addClip()
    image(at: appIconURL).draw(in: avatarRect, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.91, green: 0.10, blue: 0.16, alpha: 0.18).setStroke()
    let avatarBorder = NSBezierPath(ovalIn: avatarRect.insetBy(dx: 1, dy: 1))
    avatarBorder.lineWidth = 3
    avatarBorder.stroke()

    let nameY = panelTop + (775 - 130) * scale
    let nameRect = rectFromTop(panel.minX + 360 * scale, nameY, 450 * scale, 105 * scale)
    NSColor.white.setFill()
    NSBezierPath(rect: nameRect).fill()
    drawText("训练者", rect: nameRect, font: font("PingFangSC-Semibold", size: 60 * scale, fallbackWeight: .semibold), color: .black, alignment: .center)
}

func writePNG(_ representation: NSBitmapImageRep, to url: URL) {
    guard let data = representation.representation(using: .png, properties: [.compressionFactor: 1.0]) else {
        fatalError("Unable to encode PNG")
    }
    try! data.write(to: url)
}

try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

for (index, slide) in slides.enumerated() {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasWidth),
        pixelsHigh: Int(canvasHeight),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("Unable to create bitmap") }
    bitmap.size = NSSize(width: canvasWidth, height: canvasHeight)

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { fatalError("Unable to create graphics context") }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let background = image(at: backgroundDir.appendingPathComponent(slide.background))
    background.draw(in: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight), from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])

    let alignment: NSTextAlignment = slide.centerText ? .center : .left
    let textX: CGFloat = slide.centerText ? 70 : 82
    let textWidth: CGFloat = slide.centerText ? 1180 : 1156
    drawText("RepDay", rect: rectFromTop(textX, 76, textWidth, 90), font: font("Georgia-Bold", size: 64, fallbackWeight: .bold), color: NSColor(calibratedRed: 0.91, green: 0.08, blue: 0.10, alpha: 1), alignment: alignment)
    drawText(slide.headline, rect: rectFromTop(textX, 188, textWidth, 180), font: font("PingFangSC-Semibold", size: slide.centerText ? 108 : 104, fallbackWeight: .bold), color: NSColor(calibratedWhite: 0.05, alpha: 1), alignment: alignment, lineHeight: 128)
    drawText(slide.subtitle, rect: rectFromTop(textX, 405, textWidth, 90), font: font("PingFangSC-Regular", size: 43, fallbackWeight: .regular), color: NSColor(calibratedWhite: 0.40, alpha: 1), alignment: alignment)

    let screenshot = image(at: sourceDir.appendingPathComponent(slide.screenshot))
    if index == 0 {
        let secondary = image(at: sourceDir.appendingPathComponent("4e36a7d29690cc33fc4ac3c5b74e0e61.jpg"))
        _ = drawRoundedScreenshot(screenshot, x: 54, y: 710, width: 650, cropTop: 130, radius: 58, shadowOpacity: 0.12)
        _ = drawRoundedScreenshot(secondary, x: 500, y: 830, width: 770, cropTop: 130, radius: 64, shadowOpacity: 0.20)
    } else {
        let panel = drawRoundedScreenshot(screenshot, x: slide.panelX, y: slide.panelY, width: slide.panelWidth)
        if index == 5 {
            replaceProfileIdentity(panel: panel, panelWidth: slide.panelWidth)
        }
    }

    NSGraphicsContext.restoreGraphicsState()
    writePNG(bitmap, to: outputDir.appendingPathComponent(slide.output))
    print("Wrote \(slide.output)")
}
