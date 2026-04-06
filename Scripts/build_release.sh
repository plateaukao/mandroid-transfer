#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="MandroidTransfer"
BUNDLE_ID="com.mandroidtransfer.app"
BUILD_DIR="$PROJECT_DIR/.build/release"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "==> Building release binary..."
cd "$PROJECT_DIR"
swift build -c release

echo "==> Generating app icon..."
# Create a Swift script that reuses the same icon drawing code from the app
ICON_SCRIPT=$(mktemp /tmp/gen_icon.XXXXXX.swift)
cat > "$ICON_SCRIPT" << 'SWIFT'
import AppKit

let sizes: [(CGFloat, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let iconsetPath = CommandLine.arguments[1]

func generateIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let s = size
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let inset = s * 0.04

    // Colors
    let darkGreen = CGColor(red: 0.05, green: 0.30, blue: 0.18, alpha: 1.0)
    let midGreen = CGColor(red: 0.14, green: 0.55, blue: 0.35, alpha: 1.0)
    let brightGreen = CGColor(red: 0.24, green: 0.86, blue: 0.52, alpha: 1.0)
    let paleGreen = CGColor(red: 0.70, green: 0.96, blue: 0.80, alpha: 1.0)
    let cream = CGColor(red: 0.95, green: 1.0, blue: 0.92, alpha: 1.0)
    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1.0)
    let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1.0)

    let f = s / 512.0 // scale factor

    // Background
    let bgPath = CGPath(roundedRect: rect.insetBy(dx: inset, dy: inset),
                        cornerWidth: 90 * f, cornerHeight: 90 * f, transform: nil)
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let bgColors = [cream, paleGreen] as CFArray
    if let g = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    }
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Cubist face planes
    let p1 = CGMutablePath()
    p1.move(to: CGPoint(x: 40*f, y: 60*f)); p1.addLine(to: CGPoint(x: 40*f, y: 440*f))
    p1.addLine(to: CGPoint(x: 260*f, y: 480*f)); p1.addLine(to: CGPoint(x: 220*f, y: 200*f))
    p1.addLine(to: CGPoint(x: 160*f, y: 60*f)); p1.closeSubpath()
    ctx.setFillColor(midGreen); ctx.addPath(p1); ctx.fillPath()

    let p2 = CGMutablePath()
    p2.move(to: CGPoint(x: 220*f, y: 200*f)); p2.addLine(to: CGPoint(x: 260*f, y: 480*f))
    p2.addLine(to: CGPoint(x: 460*f, y: 450*f)); p2.addLine(to: CGPoint(x: 440*f, y: 280*f))
    p2.addLine(to: CGPoint(x: 380*f, y: 200*f)); p2.closeSubpath()
    ctx.setFillColor(brightGreen); ctx.addPath(p2); ctx.fillPath()

    let p3 = CGMutablePath()
    p3.move(to: CGPoint(x: 100*f, y: 440*f)); p3.addLine(to: CGPoint(x: 260*f, y: 480*f))
    p3.addLine(to: CGPoint(x: 430*f, y: 460*f)); p3.addLine(to: CGPoint(x: 440*f, y: 420*f))
    p3.addCurve(to: CGPoint(x: 100*f, y: 440*f),
                control1: CGPoint(x: 330*f, y: 500*f), control2: CGPoint(x: 180*f, y: 490*f))
    p3.closeSubpath()
    ctx.setFillColor(paleGreen); ctx.addPath(p3); ctx.fillPath()

    let p4 = CGMutablePath()
    p4.move(to: CGPoint(x: 160*f, y: 60*f)); p4.addLine(to: CGPoint(x: 220*f, y: 200*f))
    p4.addLine(to: CGPoint(x: 380*f, y: 200*f)); p4.addLine(to: CGPoint(x: 350*f, y: 80*f))
    p4.addLine(to: CGPoint(x: 260*f, y: 50*f)); p4.closeSubpath()
    ctx.setFillColor(darkGreen); ctx.addPath(p4); ctx.fillPath()

    let p5 = CGMutablePath()
    p5.move(to: CGPoint(x: 380*f, y: 200*f)); p5.addLine(to: CGPoint(x: 440*f, y: 280*f))
    p5.addLine(to: CGPoint(x: 470*f, y: 160*f)); p5.addLine(to: CGPoint(x: 400*f, y: 80*f))
    p5.addLine(to: CGPoint(x: 350*f, y: 80*f)); p5.closeSubpath()
    ctx.setFillColor(CGColor(red: 0.18, green: 0.65, blue: 0.40, alpha: 1.0))
    ctx.addPath(p5); ctx.fillPath()

    // Bold black outlines
    ctx.setStrokeColor(black); ctx.setLineWidth(5*f)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)

    ctx.move(to: CGPoint(x: 260*f, y: 480*f)); ctx.addLine(to: CGPoint(x: 240*f, y: 370*f))
    ctx.addLine(to: CGPoint(x: 280*f, y: 310*f)); ctx.addLine(to: CGPoint(x: 250*f, y: 280*f))
    ctx.addLine(to: CGPoint(x: 220*f, y: 200*f)); ctx.strokePath()

    ctx.move(to: CGPoint(x: 220*f, y: 200*f)); ctx.addLine(to: CGPoint(x: 380*f, y: 200*f))
    ctx.addLine(to: CGPoint(x: 350*f, y: 80*f)); ctx.strokePath()

    ctx.move(to: CGPoint(x: 160*f, y: 60*f)); ctx.addLine(to: CGPoint(x: 40*f, y: 120*f))
    ctx.addLine(to: CGPoint(x: 40*f, y: 440*f)); ctx.addLine(to: CGPoint(x: 100*f, y: 440*f)); ctx.strokePath()

    ctx.move(to: CGPoint(x: 380*f, y: 200*f)); ctx.addLine(to: CGPoint(x: 440*f, y: 280*f))
    ctx.addLine(to: CGPoint(x: 460*f, y: 450*f)); ctx.strokePath()

    ctx.move(to: CGPoint(x: 100*f, y: 440*f)); ctx.addLine(to: CGPoint(x: 260*f, y: 480*f))
    ctx.addLine(to: CGPoint(x: 460*f, y: 450*f)); ctx.strokePath()

    // Left eye
    let le = CGMutablePath()
    le.move(to: CGPoint(x: 90*f, y: 330*f))
    le.addCurve(to: CGPoint(x: 200*f, y: 330*f), control1: CGPoint(x: 120*f, y: 380*f), control2: CGPoint(x: 170*f, y: 380*f))
    le.addCurve(to: CGPoint(x: 90*f, y: 330*f), control1: CGPoint(x: 170*f, y: 280*f), control2: CGPoint(x: 120*f, y: 280*f))
    le.closeSubpath()
    ctx.setFillColor(white); ctx.addPath(le); ctx.fillPath()
    ctx.setStrokeColor(black); ctx.setLineWidth(4*f); ctx.addPath(le); ctx.strokePath()
    ctx.setFillColor(brightGreen); ctx.fillEllipse(in: CGRect(x: 125*f, y: 312*f, width: 36*f, height: 36*f))
    ctx.setFillColor(black); ctx.fillEllipse(in: CGRect(x: 134*f, y: 321*f, width: 18*f, height: 18*f))
    ctx.setFillColor(white); ctx.fillEllipse(in: CGRect(x: 140*f, y: 330*f, width: 7*f, height: 7*f))

    // Right eye
    let re = CGMutablePath()
    re.move(to: CGPoint(x: 310*f, y: 360*f))
    re.addCurve(to: CGPoint(x: 410*f, y: 360*f), control1: CGPoint(x: 330*f, y: 400*f), control2: CGPoint(x: 390*f, y: 400*f))
    re.addCurve(to: CGPoint(x: 310*f, y: 360*f), control1: CGPoint(x: 390*f, y: 320*f), control2: CGPoint(x: 330*f, y: 320*f))
    re.closeSubpath()
    ctx.setFillColor(white); ctx.addPath(re); ctx.fillPath()
    ctx.setStrokeColor(black); ctx.setLineWidth(4*f); ctx.addPath(re); ctx.strokePath()
    ctx.setFillColor(darkGreen); ctx.fillEllipse(in: CGRect(x: 342*f, y: 344*f, width: 32*f, height: 32*f))
    ctx.setFillColor(black); ctx.fillEllipse(in: CGRect(x: 350*f, y: 352*f, width: 16*f, height: 16*f))
    ctx.setFillColor(white); ctx.fillEllipse(in: CGRect(x: 354*f, y: 358*f, width: 6*f, height: 6*f))

    // Mouth
    let mouth = CGMutablePath()
    mouth.move(to: CGPoint(x: 180*f, y: 150*f)); mouth.addLine(to: CGPoint(x: 200*f, y: 120*f))
    mouth.addLine(to: CGPoint(x: 360*f, y: 130*f)); mouth.addLine(to: CGPoint(x: 370*f, y: 160*f))
    mouth.addLine(to: CGPoint(x: 340*f, y: 155*f)); mouth.addLine(to: CGPoint(x: 280*f, y: 165*f))
    mouth.addLine(to: CGPoint(x: 220*f, y: 155*f)); mouth.closeSubpath()
    ctx.setFillColor(black); ctx.addPath(mouth); ctx.fillPath()
    ctx.setStrokeColor(brightGreen); ctx.setLineWidth(2.5*f)
    for tx in [220, 248, 276, 304, 332] as [CGFloat] {
        ctx.move(to: CGPoint(x: tx*f, y: 128*f)); ctx.addLine(to: CGPoint(x: tx*f, y: 158*f)); ctx.strokePath()
    }
    ctx.setStrokeColor(black); ctx.setLineWidth(4*f); ctx.addPath(mouth); ctx.strokePath()

    // Antenna
    ctx.setStrokeColor(darkGreen); ctx.setLineWidth(7*f); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 200*f, y: 460*f)); ctx.addLine(to: CGPoint(x: 175*f, y: 488*f)); ctx.strokePath()
    ctx.setFillColor(brightGreen)
    ctx.fillEllipse(in: CGRect(x: 167*f, y: 484*f, width: 16*f, height: 16*f))

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

let fm = FileManager.default
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for (size, name) in sizes {
    let img = generateIcon(size: size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                isPlanar: false, colorSpaceName: .deviceRGB,
                                bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let filePath = "\(iconsetPath)/\(name).png"
    try! data.write(to: URL(fileURLWithPath: filePath))
}
print("Iconset created at \(iconsetPath)")
SWIFT

ICONSET_DIR=$(mktemp -d)/AppIcon.iconset
swift "$ICON_SCRIPT" "$ICONSET_DIR"
ICNS_PATH="$PROJECT_DIR/.build/AppIcon.icns"
iconutil -c icns "$ICONSET_DIR" -o "$ICNS_PATH"
rm -rf "$(dirname "$ICONSET_DIR")"
rm "$ICON_SCRIPT"
echo "==> Icon generated at $ICNS_PATH"

echo "==> Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy icon
cp "$ICNS_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Mandroid Transfer</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    echo "==> Signing app bundle..."
    codesign --deep --force --options runtime \
        --sign "$CODESIGN_IDENTITY" \
        "$APP_BUNDLE"
    echo "==> Verifying signature..."
    codesign --verify --deep --strict "$APP_BUNDLE"
    spctl --assess --type execute "$APP_BUNDLE" && echo "    Gatekeeper: OK" || echo "    Gatekeeper: not yet notarized (run notarytool to fix)"
else
    echo "==> Skipping code signing (set CODESIGN_IDENTITY to sign)"
fi

echo "==> Done! App bundle created at:"
echo "    $APP_BUNDLE"
echo ""
echo "    To run:  open $APP_BUNDLE"
echo "    To move: cp -r $APP_BUNDLE /Applications/"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    echo ""
    echo "    Signed with: $CODESIGN_IDENTITY"
fi
