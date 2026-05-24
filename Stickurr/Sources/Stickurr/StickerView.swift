import SwiftUI
import Combine

class StickerState: ObservableObject {
    let id = UUID()
    let imageURL: URL
    @Published var imageName: String
    let image: NSImage
    @Published var scale: CGFloat = 1.0
    @Published var rotation: Double = 0.0
    @Published var isPasted: Bool = false
    @Published var showOutline: Bool = true
    @Published var inFront: Bool = false
    @Published var lastSavedScreenID: CGDirectDisplayID?
    
    @Published var x: CGFloat = 0
    @Published var y: CGFloat = 0
    
    weak var window: NSWindow?
    var onChanged: (() -> Void)?
    var onRemove: (() -> Void)?
    
    init(image: NSImage, url: URL, name: String) {
        self.image = image
        self.imageURL = url
        self.imageName = name
    }
    
    func triggerChange() {
        onChanged?()
    }
    
    func triggerRemove() {
        onRemove?()
    }
}

struct StickerView: View {
    @ObservedObject var state: StickerState
    
    @State private var isLongPressed = false
    @State private var startMouseLocation: NSPoint = .zero
    @State private var startWindowOrigin: NSPoint = .zero
    
    let outlineSize: CGFloat = 4.5
    let outlineColor: Color = .white
    let padding: CGFloat = 30
    let baseDimension: CGFloat = 230
    
    var body: some View {
        StickerContent(
            image: state.image,
            scale: state.scale,
            rotation: state.rotation,
            showOutline: state.showOutline,
            isPasted: state.isPasted,
            isLongPressed: isLongPressed,
            outlineColor: outlineColor,
            outlineSize: outlineSize
        )
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
                        startWindowOrigin = NSPoint(x: state.x, y: state.y)
                        NSSound.beep()
                    }
                    
                    let currentMouse = NSEvent.mouseLocation
                    let deltaX = currentMouse.x - startMouseLocation.x
                    let deltaY = currentMouse.y - startMouseLocation.y
                    
                    state.x = startWindowOrigin.x + deltaX
                    state.y = startWindowOrigin.y + deltaY
                }
                .onEnded { _ in
                    if isLongPressed {
                        isLongPressed = false
                        state.isPasted = false
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0)) {
                            state.isPasted = true
                        }
                        state.triggerChange()
                    }
                }
        )
        .contextMenu {
            contextMenuContent
        }
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
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
                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                let amount: CGFloat = isShiftPressed ? 0.5 : 0.1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.scale += amount
                }
                state.triggerChange()
            }
            Button("Shrink") {
                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                let amount: CGFloat = isShiftPressed ? 0.5 : 0.1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.scale -= amount
                }
                state.triggerChange()
            }
        }
        Section("Rotate") {
            Button("Rotate Clockwise") {
                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                let amount: Double = isShiftPressed ? 30 : 15
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.rotation += amount
                }
                state.triggerChange()
            }
            Button("Rotate Counter-Clockwise") {
                let isShiftPressed = NSEvent.modifierFlags.contains(.shift)
                let amount: Double = isShiftPressed ? 30 : 15
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    state.rotation -= amount
                }
                state.triggerChange()
            }
        }
        Divider()
        Button("Rename") {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showRenameAlert(for: state)
            }
        }
        Button("Remove") {
            state.triggerRemove()
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

struct StickerContent: View {
    let image: NSImage
    let scale: CGFloat
    let rotation: Double
    let showOutline: Bool
    let isPasted: Bool
    let isLongPressed: Bool
    let outlineColor: Color
    let outlineSize: CGFloat
    
    let baseDimension: CGFloat = 230
    
    private var baseSize: CGSize {
        let imageSize = image.size
        let aspectRatio = imageSize.width / imageSize.height
        if aspectRatio > 1 {
            return CGSize(width: baseDimension, height: baseDimension / aspectRatio)
        } else {
            return CGSize(width: baseDimension * aspectRatio, height: baseDimension)
        }
    }
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.001)
                .contentShape(Rectangle())
            
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: baseSize.width, height: baseSize.height)
                .cornerRadius(12 / scale)
                .rotationEffect(.degrees(rotation))
                .scaleEffect(scale)
                .scaleEffect(isLongPressed ? 1.1 : 1.0)
                .rotation3DEffect(
                    .degrees(isPasted ? 0 : -45),
                    axis: (x: 1, y: -0.5, z: 0),
                    anchor: .topLeading,
                    perspective: 0.5
                )
                .opacity(isPasted ? 1.0 : 0.0)
                .stickerOutline(show: showOutline, color: outlineColor, size: outlineSize)
                // Subtle 1px drop shadow for depth
                .shadow(color: Color.black.opacity(0.3), radius: 1, x: 1, y: 1)
        }
    }
}

extension View {
    @ViewBuilder
    func stickerOutline(show: Bool, color: Color, size: CGFloat) -> some View {
        if show {
            self
                .compositingGroup()
                // Back to radius 0 for maximum sharpness, but with more offsets for thickness
                .shadow(color: color, radius: 0, x: size, y: 0)
                .shadow(color: color, radius: 0, x: -size, y: 0)
                .shadow(color: color, radius: 0, x: 0, y: size)
                .shadow(color: color, radius: 0, x: 0, y: -size)
                // Diagonals at full size
                .shadow(color: color, radius: 0, x: size * 0.71, y: size * 0.71)
                .shadow(color: color, radius: 0, x: size * 0.71, y: -size * 0.71)
                .shadow(color: color, radius: 0, x: -size * 0.71, y: size * 0.71)
                .shadow(color: color, radius: 0, x: -size * 0.71, y: -size * 0.71)
        } else {
            self
        }
    }
}
