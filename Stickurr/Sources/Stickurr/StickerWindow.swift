import Cocoa
import SwiftUI

class StickerWindow: NSPanel {
    let state: StickerState
    
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
        
        // Önemli: Normal seviyeye alıyoruz ama arkada sabitliyoruz
        self.level = .normal 
        
        // Masaüstünde sabit kalmasını ve pencerelerin altında durmasını sağlar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        self.hidesOnDeactivate = false
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = false
        
        state.window = self
        
        let stickerView = StickerView(state: state)
        self.contentView = NSHostingView(rootView: stickerView)
        
        self.makeKeyAndOrderFront(nil)
        
        // Pencereleri arkaya gönder
        self.order(.below, relativeTo: 0)
    }
    
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}
