import Cocoa
import SwiftUI

// Kaydedilecek veri yapısı
struct StickerData: Codable {
    let url: URL
    let name: String?
    let x: CGFloat
    let y: CGFloat
    let scale: CGFloat
    let rotation: Double
    let showOutline: Bool?
    let inFront: Bool?
    let isCenterSaved: Bool? // Flag to distinguish new vs old data
    let screenID: CGDirectDisplayID?
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        return deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var windows: [StickerWindow] = []
    
    lazy var stickersFolder: URL = {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent("Stickurr", isDirectory: true)
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport
    }()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "face.smiling", accessibilityDescription: "Stickers")
        }
        
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        
        // Kayıtlı stickerları yükle
        loadStickers()
        
        // Ekran değişikliklerini dinle
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    
    @objc func screensChanged() {
        checkWindowVisibility()
    }
    
    func checkWindowVisibility() {
        for window in windows {
            if let savedScreenID = window.state.lastSavedScreenID {
                let screenExists = NSScreen.screens.contains { $0.displayID == savedScreenID }
                if !screenExists {
                    window.orderOut(nil)
                } else {
                    // Önce konumu bizim verimize göre zorla güncelle (macOS'in taşımasını ezmek için)
                    window.updateWindowSize()
                    
                    window.makeKeyAndOrderFront(nil)
                    // Pencere seviyesini tekrar güncelle
                    window.updateWindowLevel(isInFront: window.state.inFront)
                }
            }
        }
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(NSMenuItem(title: "Add New Sticker...", action: #selector(addSticker), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Add from Clipboard", action: #selector(addFromClipboard), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Reload Stickers", action: #selector(reloadStickers), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        
        if windows.isEmpty {
            let emptyItem = NSMenuItem(title: "No stickers yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for (index, window) in windows.enumerated() {
                let stickerMenu = NSMenuItem(title: "\(index + 1). \(window.state.imageName)", action: nil, keyEquivalent: "")
                let subMenu = NSMenu()

                let renameItem = NSMenuItem(title: "Rename", action: #selector(renameSticker(_:)), keyEquivalent: "")
                renameItem.representedObject = window
                subMenu.addItem(renameItem)

                subMenu.addItem(NSMenuItem.separator())

                let toggleOutlineItem = NSMenuItem(title: window.state.showOutline ? "Hide Outline" : "Show Outline", action: #selector(toggleOutline(_:)), keyEquivalent: "")
                toggleOutlineItem.representedObject = window
                subMenu.addItem(toggleOutlineItem)

                let toggleInFrontItem = NSMenuItem(title: window.state.inFront ? "Send to Desktop" : "Bring to Front", action: #selector(toggleInFront(_:)), keyEquivalent: "")
                toggleInFrontItem.representedObject = window
                subMenu.addItem(toggleInFrontItem)

                subMenu.addItem(NSMenuItem.separator())
                let growItem = NSMenuItem(title: "Grow", action: #selector(growSticker(_:)), keyEquivalent: "")
                growItem.representedObject = window
                subMenu.addItem(growItem)

                let shrinkItem = NSMenuItem(title: "Shrink", action: #selector(shrinkSticker(_:)), keyEquivalent: "")
                shrinkItem.representedObject = window
                subMenu.addItem(shrinkItem)

                subMenu.addItem(NSMenuItem.separator())

                let rotateCWItem = NSMenuItem(title: "Rotate Clockwise", action: #selector(rotateStickerCW(_:)), keyEquivalent: "")
                rotateCWItem.representedObject = window
                subMenu.addItem(rotateCWItem)

                let rotateCCWItem = NSMenuItem(title: "Rotate Counter-Clockwise", action: #selector(rotateStickerCCW(_:)), keyEquivalent: "")
                rotateCCWItem.representedObject = window
                subMenu.addItem(rotateCCWItem)

                subMenu.addItem(NSMenuItem.separator())

                let removeItem = NSMenuItem(title: "Remove", action: #selector(removeSticker(_:)), keyEquivalent: "")
                removeItem.representedObject = window
                subMenu.addItem(removeItem)

                stickerMenu.submenu = subMenu
                menu.addItem(stickerMenu)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.7.3"

        let versionItem = NSMenuItem(title: "Stickurr v\(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        
        menu.addItem(NSMenuItem(title: "Quit Stickurr", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc func renameSticker(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            showRenameAlert(for: window.state)
        }
    }

    func showRenameAlert(for state: StickerState) {
        let alert = NSAlert()
        alert.messageText = "Rename Sticker"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        // Sol taraftaki ikonu sticker yapalım (Thumbnail olarak kalacak)
        alert.icon = state.image
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        input.stringValue = state.imageName
        input.placeholderString = "Sticker Name"
        
        alert.accessoryView = input
        alert.window.initialFirstResponder = input
        
        if alert.runModal() == .alertFirstButtonReturn {
            state.imageName = input.stringValue
            saveStickers()
            state.triggerChange()
        }
    }

    @objc func toggleOutline(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                window.state.showOutline.toggle()
            }
            saveStickers()
        }
    }

    @objc func toggleInFront(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                window.state.inFront.toggle()
            }
            saveStickers()
        }
    }

    @objc func addSticker() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.png]
        openPanel.allowsMultipleSelection = true
        
        openPanel.begin { response in
            if response == .OK {
                for url in openPanel.urls {
                    self.createSticker(from: url)
                }
            }
        }
    }
    
    @objc func addFromClipboard() {
        let pasteboard = NSPasteboard.general
        
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            for url in urls {
                createSticker(from: url)
            }
            return
        }
        
        if let image = NSImage(pasteboard: pasteboard) {
            let fileName = "clipboard_\(Int(Date().timeIntervalSince1970)).png"
            let fileURL = stickersFolder.appendingPathComponent(fileName)
            
            if let tiffData = image.tiffRepresentation,
               let bitmapImage = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                try? pngData.write(to: fileURL)
                createSticker(from: fileURL)
            }
        }
    }
    
    func createSticker(from url: URL, savedData: StickerData? = nil) {
        guard let image = NSImage(contentsOf: url) else { return }
        
        let name = savedData?.name ?? url.lastPathComponent
        let state = StickerState(image: image, url: url, name: name)
        state.onChanged = { [weak self] in self?.saveStickers() }
        
        if let data = savedData {
            state.scale = data.scale
            state.rotation = data.rotation
            state.showOutline = data.showOutline ?? true
            state.inFront = data.inFront ?? false
            state.lastSavedScreenID = data.screenID
            state.x = data.x
            state.y = data.y
            
            // Eski data uyumluluğu: Eğer x/y merkez değilse (isCenterSaved yoksa)
            if data.isCenterSaved != true {
                state.x += 175
                state.y += 175
            }
        } else {
            let mouse = NSEvent.mouseLocation
            state.x = mouse.x
            state.y = mouse.y
        }
        
        // StickerWindow will calculate its own size based on state.x/y
        let rect = NSRect(x: state.x - 1, y: state.y - 1, width: 2, height: 2)
        
        let window = StickerWindow(state: state, contentRect: rect)
        windows.append(window)
        
        // Eğer ekran şu an yoksa sakla
        if let screenID = state.lastSavedScreenID {
            let screenExists = NSScreen.screens.contains { $0.displayID == screenID }
            if !screenExists {
                window.orderOut(nil)
            }
        }
        
        saveStickers()
    }
    
    func saveStickers() {
        let data = windows.map { window in
            StickerData(
                url: window.state.imageURL,
                name: window.state.imageName,
                x: window.state.x,
                y: window.state.y,
                scale: window.state.scale,
                rotation: window.state.rotation,
                showOutline: window.state.showOutline,
                inFront: window.state.inFront,
                isCenterSaved: true,
                screenID: window.screen?.displayID ?? window.state.lastSavedScreenID
            )
        }
        
        // Update state with last saved screen ID
        for window in windows {
            if let screenID = window.screen?.displayID {
                window.state.lastSavedScreenID = screenID
            }
        }
        
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "SavedStickers")
        }
    }
    
    func loadStickers() {
        guard let savedData = UserDefaults.standard.data(forKey: "SavedStickers"),
              let decoded = try? JSONDecoder().decode([StickerData].self, from: savedData) else {
            return
        }
        
        for item in decoded {
            createSticker(from: item.url, savedData: item)
        }
    }
    
    @objc func growSticker(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            let amount: CGFloat = isShiftPressed ? 0.5 : 0.1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                window.state.scale += amount
            }
            saveStickers()
        }
    }
    
    @objc func shrinkSticker(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            let amount: CGFloat = isShiftPressed ? 0.5 : 0.1
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                window.state.scale -= amount
            }
            saveStickers()
        }
    }
    
    @objc func rotateStickerCW(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            let amount: Double = isShiftPressed ? 30 : 15
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                window.state.rotation += amount
            }
            saveStickers()
        }
    }
    
    @objc func rotateStickerCCW(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
            let amount: Double = isShiftPressed ? 30 : 15
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                window.state.rotation -= amount
            }
            saveStickers()
        }
    }
    
    @objc func reloadStickers() {
        // Mevcut pencereleri kapat
        for window in windows {
            window.close()
        }
        windows.removeAll()
        
        // Verileri ve görselleri yeniden yükle
        loadStickers()
    }
    
    @objc func removeSticker(_ sender: NSMenuItem) {
        if let window = sender.representedObject as? StickerWindow {
            window.close()
            windows.removeAll { $0 === window }
            saveStickers()
        }
    }
}
