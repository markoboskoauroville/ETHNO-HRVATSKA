import AppKit
import SwiftUI
import PDFKit

let VERSION = 1
let APP_NAME = "Ethno Song Sheets (Mantra)"

@main
enum Entry {
    static func main() {
        let app = NSApplication.shared
        let d = AppDelegate()
        app.delegate = d
        app.setActivationPolicy(.regular)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var store: Store!

    /// Test hooks, so nothing needs the screen or a click:
    ///   --library DIR            use this library folder
    ///   --render-all OUT         write every PDF and a PNG per page into OUT, then quit (no window)
    ///   --shot FILE [--song NN] [--preview]   write a picture of the window, then quit
    func arg(_ name: String) -> String? {
        let a = CommandLine.arguments
        guard let i = a.firstIndex(of: name), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        let lib = arg("--library").map { URL(fileURLWithPath: $0) }
        store = Store(library: lib)
        if let out = arg("--render-all") { renderAll(to: URL(fileURLWithPath: out)); exit(0) }
        buildMenu()
        if let nn = arg("--song"), let s = store.songs.first(where: { $0.number == nn }) { store.selected = s.id }
        if CommandLine.arguments.contains("--preview") { Launch.tab = 1 }
        let hosting = NSHostingController(rootView: ContentView().environmentObject(store))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = APP_NAME
        window.contentViewController = hosting
        window.minSize = NSSize(width: 860, height: 540)
        window.isReleasedWhenClosed = false
        if arg("--shot") == nil {
            if !window.setFrameUsingName("main") { window.center() }
            window.setFrameAutosaveName("main")
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            Updater.checkAtStart()
        } else {
            window.setContentSize(NSSize(width: 1100, height: 720))
            if let s = NSScreen.screens.first(where: { $0.localizedName.contains("Built-in") }) ?? NSScreen.screens.first {
                window.setFrameOrigin(NSPoint(x: s.frame.minX + 40, y: s.frame.minY + 40))
            }
            window.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { self.shot(arg("--shot")!) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }   // window X quits: no ON/OFF button

    func shot(_ path: String) {
        let id = CGWindowID(window.windowNumber)
        if let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming]) {
            let rep = NSBitmapImageRep(cgImage: cg)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        NSApp.terminate(nil)
    }

    func renderAll(to out: URL) {
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for s in store.songs {
            do {
                let r = try Renderer.render(s)
                try r.data.write(to: out.appendingPathComponent(s.pdfName))
                print("\(s.pdfName): guitar \(r.guitarColumns) col, scale \(Double(r.guitarScale))\(r.warnings.isEmpty ? "" : " WARN " + r.warnings.joined(separator: "; "))")
                if let doc = PDFDocument(data: r.data) {
                    for i in 0..<doc.pageCount {
                        guard let page = doc.page(at: i) else { continue }
                        let size = NSSize(width: 595.28 * 110 / 72, height: 841.89 * 110 / 72)
                        let img = page.thumbnail(of: size, for: .mediaBox)
                        if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
                           let png = rep.representation(using: .png, properties: [:]) {
                            try? png.write(to: out.appendingPathComponent("\(s.number)-p\(i + 1).png"))
                        }
                    }
                }
            } catch { print("\(s.title): \(error.localizedDescription)") }
        }
    }

    func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Check for updates...", action: #selector(checkUpdates), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(APP_NAME)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }

    @objc func checkUpdates() { Updater.checkAtStart(delay: 0.1, manual: true) }
}
