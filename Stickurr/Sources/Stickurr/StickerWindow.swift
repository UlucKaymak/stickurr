import Cocoa
import SwiftUI
import Combine

class StickerWindow: NSPanel {
    let state: StickerState
    private var cancellables = Set<AnyCancellable>()
    
    init(state: StickerState, contentRect: NSRect) {
        self.state = state
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = false
        
        state.window = self
        
        let stickerView = StickerView(state: state)
        self.contentView = NSHostingView(rootView: stickerView)
        
        self.makeKeyAndOrderFront(nil)
        
        // inFront değişimini dinle ve pencere seviyesini güncelle
        state.$inFront
            .sink { [weak self] isInFront in
                self?.updateWindowLevel(isInFront: isInFront)
            }
            .store(in: &cancellables)
            
        // Scale ve Rotation değişimini dinle ve pencere boyutunu güncelle
        Publishers.CombineLatest(state.$scale, state.$rotation)
            .sink { [weak self] _, _ in
                self?.updateWindowSize()
            }
            .store(in: &cancellables)
            
        updateWindowSize()
    }
    
    private func updateWindowSize() {
        let baseDimension: CGFloat = 230
        let padding: CGFloat = 30
        let imageSize = state.image.size
        let aspectRatio = imageSize.width / imageSize.height
        
        var w, h: CGFloat
        if aspectRatio > 1 {
            w = baseDimension
            h = baseDimension / aspectRatio
        } else {
            h = baseDimension
            w = baseDimension * aspectRatio
        }
        
        // Scale it up (including a buffer for the 1.1x pickup scale)
        let s = state.scale * 1.1
        w *= s
        h *= s
        
        // Rotation bounding box
        let rad = CGFloat(state.rotation * .pi / 180)
        let rotatedW = abs(w * cos(rad)) + abs(h * sin(rad))
        let rotatedH = abs(w * sin(rad)) + abs(h * cos(rad))
        
        let newSize = NSSize(
            width: ceil(rotatedW + padding * 2),
            height: ceil(rotatedH + padding * 2)
        )
        
        let oldFrame = self.frame
        let newOrigin = NSPoint(
            x: oldFrame.midX - newSize.width / 2,
            y: oldFrame.midY - newSize.height / 2
        )
        
        self.setFrame(NSRect(origin: newOrigin, size: newSize), display: true, animate: false)
    }
    
    private func updateWindowLevel(isInFront: Bool) {
        if isInFront {
            self.level = .floating
            self.orderFront(nil)
        } else {
            // Masaüstü modu: Masaüstü simgelerinin hemen üstünde, diğer pencerelerin arkasında
            self.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        }
    }
    
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}
