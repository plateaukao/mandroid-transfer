import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = AppIconGenerator.generate()
    }
}

enum AppIconGenerator {
    static func generate() -> NSImage {
        let size: CGFloat = 512
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }

        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let inset: CGFloat = 20

        // Colors
        let darkGreen = CGColor(red: 0.05, green: 0.30, blue: 0.18, alpha: 1.0)
        let midGreen = CGColor(red: 0.14, green: 0.55, blue: 0.35, alpha: 1.0)
        let brightGreen = CGColor(red: 0.24, green: 0.86, blue: 0.52, alpha: 1.0)   // #3DDC84
        let paleGreen = CGColor(red: 0.70, green: 0.96, blue: 0.80, alpha: 1.0)
        let cream = CGColor(red: 0.95, green: 1.0, blue: 0.92, alpha: 1.0)
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1.0)

        // === Background ===
        let bgPath = CGPath(roundedRect: rect.insetBy(dx: inset, dy: inset), cornerWidth: 90, cornerHeight: 90, transform: nil)
        context.saveGState()
        context.addPath(bgPath)
        context.clip()
        let bgColors = [cream, paleGreen] as CFArray
        if let g = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0, 1]) {
            context.drawLinearGradient(g, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
        }
        context.restoreGState()

        // Clip all drawing to icon shape
        context.saveGState()
        context.addPath(bgPath)
        context.clip()

        // === Cubist face planes (Picasso fragmented geometry) ===

        // Large left face plane (dark green triangle)
        let p1 = CGMutablePath()
        p1.move(to: CGPoint(x: 40, y: 60))
        p1.addLine(to: CGPoint(x: 40, y: 440))
        p1.addLine(to: CGPoint(x: 260, y: 480))
        p1.addLine(to: CGPoint(x: 220, y: 200))
        p1.addLine(to: CGPoint(x: 160, y: 60))
        p1.closeSubpath()
        context.setFillColor(midGreen)
        context.addPath(p1)
        context.fillPath()

        // Right face plane (bright green)
        let p2 = CGMutablePath()
        p2.move(to: CGPoint(x: 220, y: 200))
        p2.addLine(to: CGPoint(x: 260, y: 480))
        p2.addLine(to: CGPoint(x: 460, y: 450))
        p2.addLine(to: CGPoint(x: 440, y: 280))
        p2.addLine(to: CGPoint(x: 380, y: 200))
        p2.closeSubpath()
        context.setFillColor(brightGreen)
        context.addPath(p2)
        context.fillPath()

        // Forehead plane (pale green)
        let p3 = CGMutablePath()
        p3.move(to: CGPoint(x: 100, y: 440))
        p3.addLine(to: CGPoint(x: 260, y: 480))
        p3.addLine(to: CGPoint(x: 430, y: 460))
        p3.addLine(to: CGPoint(x: 440, y: 420))
        p3.addCurve(to: CGPoint(x: 100, y: 440),
                    control1: CGPoint(x: 330, y: 500),
                    control2: CGPoint(x: 180, y: 490))
        p3.closeSubpath()
        context.setFillColor(paleGreen)
        context.addPath(p3)
        context.fillPath()

        // Chin/jaw plane (dark)
        let p4 = CGMutablePath()
        p4.move(to: CGPoint(x: 160, y: 60))
        p4.addLine(to: CGPoint(x: 220, y: 200))
        p4.addLine(to: CGPoint(x: 380, y: 200))
        p4.addLine(to: CGPoint(x: 350, y: 80))
        p4.addLine(to: CGPoint(x: 260, y: 50))
        p4.closeSubpath()
        context.setFillColor(darkGreen)
        context.addPath(p4)
        context.fillPath()

        // Lower-right cheek plane
        let p5 = CGMutablePath()
        p5.move(to: CGPoint(x: 380, y: 200))
        p5.addLine(to: CGPoint(x: 440, y: 280))
        p5.addLine(to: CGPoint(x: 470, y: 160))
        p5.addLine(to: CGPoint(x: 400, y: 80))
        p5.addLine(to: CGPoint(x: 350, y: 80))
        p5.closeSubpath()
        context.setFillColor(CGColor(red: 0.18, green: 0.65, blue: 0.40, alpha: 1.0))
        context.addPath(p5)
        context.fillPath()

        // === Bold black outlines (Picasso-style thick contour lines) ===
        context.setStrokeColor(black)
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Nose line (bold angular line down the center)
        context.move(to: CGPoint(x: 260, y: 480))
        context.addLine(to: CGPoint(x: 240, y: 370))
        context.addLine(to: CGPoint(x: 280, y: 310))
        context.addLine(to: CGPoint(x: 250, y: 280))
        context.addLine(to: CGPoint(x: 220, y: 200))
        context.strokePath()

        // Jaw/chin contour
        context.move(to: CGPoint(x: 220, y: 200))
        context.addLine(to: CGPoint(x: 380, y: 200))
        context.addLine(to: CGPoint(x: 350, y: 80))
        context.strokePath()

        // Face outline left
        context.move(to: CGPoint(x: 160, y: 60))
        context.addLine(to: CGPoint(x: 40, y: 120))
        context.addLine(to: CGPoint(x: 40, y: 440))
        context.addLine(to: CGPoint(x: 100, y: 440))
        context.strokePath()

        // Face outline right
        context.move(to: CGPoint(x: 380, y: 200))
        context.addLine(to: CGPoint(x: 440, y: 280))
        context.addLine(to: CGPoint(x: 460, y: 450))
        context.strokePath()

        // Forehead line
        context.move(to: CGPoint(x: 100, y: 440))
        context.addLine(to: CGPoint(x: 260, y: 480))
        context.addLine(to: CGPoint(x: 460, y: 450))
        context.strokePath()

        // === Left eye (large, displaced — Picasso asymmetry) ===
        // Almond/diamond shape
        let le = CGMutablePath()
        le.move(to: CGPoint(x: 90, y: 330))
        le.addCurve(to: CGPoint(x: 200, y: 330),
                    control1: CGPoint(x: 120, y: 380),
                    control2: CGPoint(x: 170, y: 380))
        le.addCurve(to: CGPoint(x: 90, y: 330),
                    control1: CGPoint(x: 170, y: 280),
                    control2: CGPoint(x: 120, y: 280))
        le.closeSubpath()
        context.setFillColor(white)
        context.addPath(le)
        context.fillPath()
        context.setStrokeColor(black)
        context.setLineWidth(4)
        context.addPath(le)
        context.strokePath()

        // Iris
        context.setFillColor(brightGreen)
        context.fillEllipse(in: CGRect(x: 125, y: 312, width: 36, height: 36))
        // Pupil
        context.setFillColor(black)
        context.fillEllipse(in: CGRect(x: 134, y: 321, width: 18, height: 18))
        // Highlight
        context.setFillColor(white)
        context.fillEllipse(in: CGRect(x: 140, y: 330, width: 7, height: 7))

        // === Right eye (smaller, higher — cubist displacement) ===
        let re = CGMutablePath()
        re.move(to: CGPoint(x: 310, y: 360))
        re.addCurve(to: CGPoint(x: 410, y: 360),
                    control1: CGPoint(x: 330, y: 400),
                    control2: CGPoint(x: 390, y: 400))
        re.addCurve(to: CGPoint(x: 310, y: 360),
                    control1: CGPoint(x: 390, y: 320),
                    control2: CGPoint(x: 330, y: 320))
        re.closeSubpath()
        context.setFillColor(white)
        context.addPath(re)
        context.fillPath()
        context.setStrokeColor(black)
        context.setLineWidth(4)
        context.addPath(re)
        context.strokePath()

        // Iris
        context.setFillColor(darkGreen)
        context.fillEllipse(in: CGRect(x: 342, y: 344, width: 32, height: 32))
        // Pupil
        context.setFillColor(black)
        context.fillEllipse(in: CGRect(x: 350, y: 352, width: 16, height: 16))
        // Highlight
        context.setFillColor(white)
        context.fillEllipse(in: CGRect(x: 354, y: 358, width: 6, height: 6))

        // === Mouth (angular, asymmetric — black with green teeth/segments) ===
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: 180, y: 150))
        mouth.addLine(to: CGPoint(x: 200, y: 120))
        mouth.addLine(to: CGPoint(x: 360, y: 130))
        mouth.addLine(to: CGPoint(x: 370, y: 160))
        mouth.addLine(to: CGPoint(x: 340, y: 155))
        mouth.addLine(to: CGPoint(x: 280, y: 165))
        mouth.addLine(to: CGPoint(x: 220, y: 155))
        mouth.closeSubpath()
        context.setFillColor(black)
        context.addPath(mouth)
        context.fillPath()

        // Teeth lines (vertical green segments)
        context.setStrokeColor(brightGreen)
        context.setLineWidth(2.5)
        let teethXs: [CGFloat] = [220, 248, 276, 304, 332]
        for tx in teethXs {
            context.move(to: CGPoint(x: tx, y: 128))
            context.addLine(to: CGPoint(x: tx, y: 158))
            context.strokePath()
        }

        // Mouth outline
        context.setStrokeColor(black)
        context.setLineWidth(4)
        context.addPath(mouth)
        context.strokePath()

        // === Antenna (quirky, sticking up from top) ===
        context.setStrokeColor(darkGreen)
        context.setLineWidth(7)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: 200, y: 460))
        context.addLine(to: CGPoint(x: 175, y: 488))
        context.strokePath()

        // Antenna ball
        context.setFillColor(brightGreen)
        context.fillEllipse(in: CGRect(x: 167, y: 484, width: 16, height: 16))

        context.restoreGState() // end bg clip

        image.unlockFocus()
        return image
    }
}

@main
struct MandroidTransferApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Folder…") {
                    NotificationCenter.default.post(name: .newFolderRequested, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandMenu("Go") {
                Button("Back") {
                    Task { await appState.goBack() }
                }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!appState.canGoBack)

                Button("Forward") {
                    Task { await appState.goForward() }
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!appState.canGoForward)

                Button("Enclosing Folder") {
                    Task { await appState.navigateUp() }
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!appState.canGoUp)

                Divider()

                Button("Refresh") {
                    Task { await appState.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }

            CommandMenu("View") {
                Toggle("Show Hidden Files", isOn: Binding(
                    get: { appState.showHiddenFiles },
                    set: { appState.showHiddenFiles = $0 }
                ))
                .keyboardShortcut(".", modifiers: [.command, .shift])

            }
        }
    }
}

extension Notification.Name {
    static let newFolderRequested = Notification.Name("newFolderRequested")
}
