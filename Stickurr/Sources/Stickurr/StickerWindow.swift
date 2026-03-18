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
    }
    
    private func updateWindowLevel(isInFront: Bool) {
        if isInFront {
            self.level = .floating
            self.orderFront(nil)
        } else {
            // Masaüstü modu
            self.level = .normal
            self.order(.below, relativeTo: 0)
        }
    }
    
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}
