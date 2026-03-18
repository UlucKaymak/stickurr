import SwiftUI
import Combine

class StickerState: ObservableObject {
    let id = UUID()
    let imageURL: URL
    let imageName: String
    let image: NSImage
    @Published var scale: CGFloat = 1.0
    @Published var rotation: Double = 0.0
    @Published var isPasted: Bool = false
    @Published var showOutline: Bool = true
    @Published var inFront: Bool = false
    
    weak var window: NSWindow?
    var onChanged: (() -> Void)? // Kayıt için callback
    
    init(image: NSImage, url: URL, name: String) {
        self.image = image
        self.imageURL = url
        self.imageName = name
    }
    
    func triggerChange() {
        onChanged?()
    }
}

struct StickerView: View {
    @ObservedObject var state: StickerState
    
    @State private var isLongPressed = false
    @State private var startMouseLocation: NSPoint = .zero
    @State private var startWindowOrigin: NSPoint = .zero
    
    let outlineSize: CGFloat = 4
    let outlineColor: Color = .white
    let padding: CGFloat = 30
    let baseDimension: CGFloat = 230
    
    private var baseSize: CGSize {
        let imageSize = state.image.size
        let aspectRatio = imageSize.width / imageSize.height
        if aspectRatio > 1 {
            return CGSize(width: baseDimension, height: baseDimension / aspectRatio)
        } else {
            return CGSize(width: baseDimension * aspectRatio, height: baseDimension)
        }
    }
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.00)
                .contentShape(Rectangle())
            
            Image(nsImage: state.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: baseSize.width, height: baseSize.height)
                .rotationEffect(.degrees(state.rotation))
                .scaleEffect(state.scale)
                .scaleEffect(isLongPressed ? 1.1 : 1.0)
                .rotation3DEffect(
                    .degrees(state.isPasted ? 0 : -45),
                    axis: (x: 1, y: -0.5, z: 0),
                    anchor: .topLeading,
                    perspective: 0.5
                )
                .opacity(state.isPasted ? 1.0 : 0.0)
                // Outline shadows (Conditional based on state.showOutline)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: outlineSize, y: 0)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: -outlineSize, y: 0)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: 0, y: outlineSize)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: 0, y: -outlineSize)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: outlineSize, y: outlineSize)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: -outlineSize, y: -outlineSize)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: outlineSize, y: -outlineSize)
                .shadow(color: state.showOutline ? outlineColor : .clear, radius: 0, x: -outlineSize, y: outlineSize)
                // Shadow
                .shadow(
                    color: Color.black.opacity(state.isPasted ? 0.4 : 0.2),
                    radius: state.isPasted ? 8 : 20,
                    x: state.isPasted ? 0 : 15,
                    y: state.isPasted ? 4 : 25
                )
        }
        .padding(padding)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75, blendDuration: 0)) {
                state.isPasted = true
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2, coordinateSpace: .global)
                .onChanged { value in
                    if !isLongPressed {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLongPressed = true
                        }
                        startMouseLocation = NSEvent.mouseLocation
                        if let window = state.window {
                            startWindowOrigin = window.frame.origin
                        }
                        NSSound.beep()
                    }
                    
                    if let window = state.window {
                        let currentMouse = NSEvent.mouseLocation
                        let deltaX = currentMouse.x - startMouseLocation.x
                        let deltaY = currentMouse.y - startMouseLocation.y
                        let newOrigin = NSPoint(
                            x: startWindowOrigin.x + deltaX,
                            y: startWindowOrigin.y + deltaY
                        )
                        window.setFrameOrigin(newOrigin)
                    }
                }
                .onEnded { _ in
                    if isLongPressed {
                        isLongPressed = false
                        // "Yapıştırma" efekti için animasyonu tekrar tetikle
                        state.isPasted = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                            state.isPasted = true
                        }
                        state.triggerChange() // Konum değişince kaydet
                    }
                }
        )
        .contextMenu {
            Section("Appearance") {
                Button(state.showOutline ? "Hide Outline" : "Show Outline") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.showOutline.toggle()
                    }
                    state.triggerChange()
                }
                Button(state.inFront ? "Send to Desktop" : "Bring to Front") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.inFront.toggle()
                    }
                    state.triggerChange()
                }
            }
            Section("Size") {
                Button("Grow") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.scale += 0.1
                    }
                    state.triggerChange()
                }
                Button("Shrink") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.scale -= 0.1
                    }
                    state.triggerChange()
                }
            }
            Section("Rotate") {
                Button("Rotate Clockwise") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.rotation += 15
                    }
                    state.triggerChange()
                }
                Button("Rotate Counter-Clockwise") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        state.rotation -= 15
                    }
                    state.triggerChange()
                }
            }
            Divider()
            Button("Remove") {
                state.window?.close()
                // Notification veya callback ile listeden silinecek
            }
            Button("Reset") {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.scale = 1.0
                    state.rotation = 0.0
                    state.showOutline = true
                }
                state.triggerChange()
            }
        }
    }
}
