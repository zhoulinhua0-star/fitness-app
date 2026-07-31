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
    fatalError("Usage: swift scripts/generate_appstore_en.swift --source-dir <path> [--background-dir <path>] [--output-dir <path>] [--app-icon <path>]")
}

let assetDir = projectRoot.appendingPathComponent("AppStoreAssets/Screenshots-6.9-EN-1.1.0", isDirectory: true)
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
    Slide(background: "01.png", screenshot: "3b37153a10394b69ed4ef644b0684f43.jpg", output: "01-clear-training-en.png", headline: "A clearer way\nto train", subtitle: "Plan with clarity. Train with focus.", panelX: 0, panelY: 0, panelWidth: 0, centerText: true),
    Slide(background: "02.png", screenshot: "b14a41a7b23ec58e4d8f8f3dff1b0dae.jpg", output: "02-workout-rhythm-en.png", headline: "Every set.\nRight on pace.", subtitle: "Progress, reps, and rest—at a glance.", panelX: 140, panelY: 720, panelWidth: 1040, centerText: false),
    Slide(background: "03.png", screenshot: "f3d36a6bae27e513b4ff43c2512aaee1.jpg", output: "03-progress-en.png", headline: "See every win\nadd up", subtitle: "Clear trends. Consistent momentum.", panelX: 130, panelY: 710, panelWidth: 1060, centerText: false),
    Slide(background: "04.png", screenshot: "00c0108e0495eb1a4c989ad91a496ddf.jpg", output: "04-weekly-plan-en.png", headline: "Build a week\nthat works", subtitle: "Strength, cardio, and rest—in one plan.", panelX: 135, panelY: 720, panelWidth: 1050, centerText: false),
    Slide(background: "05.png", screenshot: "9f2d8ecd6385e1eadd9837a3a7ebbc09.jpg", output: "05-freestyle-en.png", headline: "Plans change.\nKeep moving.", subtitle: "Switch to Freestyle and train your way.", panelX: 140, panelY: 730, panelWidth: 1040, centerText: false),
    Slide(background: "06.png", screenshot: "5d0a96826f421420e30ea3aaf8c9fa19.jpg", output: "06-growth-en.png", headline: "Stay consistent.\nLevel up.", subtitle: "Track your level and every step forward.", panelX: 140, panelY: 720, panelWidth: 1040, centerText: false)
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

@discardableResult
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

    let coverRect = rectFromTop(panel.minX + 350 * scale, panelTop + (425 - 130) * scale, 500 * scale, 395 * scale)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: coverRect, xRadius: 42 * scale, yRadius: 42 * scale).fill()

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(ovalIn: avatarRect).addClip()
    image(at: appIconURL).draw(in: avatarRect, from: .zero, operation: .copy, fraction: 1, respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.91, green: 0.10, blue: 0.16, alpha: 0.18).setStroke()
    let avatarBorder = NSBezierPath(ovalIn: avatarRect.insetBy(dx: 1, dy: 1))
    avatarBorder.lineWidth = 3
    avatarBorder.stroke()

    let nameY = panelTop + (775 - 130) * scale
    let nameRect = rectFromTop(panel.minX + 335 * scale, nameY, 500 * scale, 110 * scale)
    NSColor.white.setFill()
    NSBezierPath(rect: nameRect).fill()
    drawText("Athlete", rect: nameRect, font: font("HelveticaNeue-Bold", size: 58 * scale, fallbackWeight: .bold), color: .black, alignment: .center)
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
    drawText("RepDay", rect: rectFromTop(textX, 70, textWidth, 92), font: font("Georgia-Bold", size: 64, fallbackWeight: .bold), color: NSColor(calibratedRed: 0.91, green: 0.08, blue: 0.10, alpha: 1), alignment: alignment)
    drawText(slide.headline, rect: rectFromTop(textX, 168, textWidth, 280), font: font("Georgia-Bold", size: slide.centerText ? 108 : 102, fallbackWeight: .bold), color: NSColor(calibratedWhite: 0.045, alpha: 1), alignment: alignment, lineHeight: 112)
    drawText(slide.subtitle, rect: rectFromTop(textX, 455, textWidth, 80), font: font("HelveticaNeue-Medium", size: 42, fallbackWeight: .medium), color: NSColor(calibratedWhite: 0.40, alpha: 1), alignment: alignment)

    let screenshot = image(at: sourceDir.appendingPathComponent(slide.screenshot))
    if index == 0 {
        let secondary = image(at: sourceDir.appendingPathComponent("b14a41a7b23ec58e4d8f8f3dff1b0dae.jpg"))
        drawRoundedScreenshot(screenshot, x: 54, y: 720, width: 650, cropTop: 130, radius: 58, shadowOpacity: 0.12)
        drawRoundedScreenshot(secondary, x: 500, y: 840, width: 770, cropTop: 130, radius: 64, shadowOpacity: 0.20)
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
