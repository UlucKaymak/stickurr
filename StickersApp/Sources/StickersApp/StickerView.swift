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
    
    var body: some View {
        ZStack {
            Color.white.opacity(0.01)
                .contentShape(Rectangle())
            
            Image(nsImage: state.image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .rotationEffect(.degrees(state.rotation))
                .scaleEffect(state.scale)
                .scaleEffect(isLongPressed ? 1.05 : 1.0)
                .rotation3DEffect(
                    .degrees(state.isPasted ? 0 : -90),
                    axis: (x: 1, y: -1, z: 0),
                    anchor: .topLeading,
                    perspective: 0.3
                )
                .opacity(state.isPasted ? 1.0 : 0.0)
                .shadow(color: outlineColor, radius: 0, x: outlineSize, y: 0)
                .shadow(color: outlineColor, radius: 0, x: -outlineSize, y: 0)
                .shadow(color: outlineColor, radius: 0, x: 0, y: outlineSize)
                .shadow(color: outlineColor, radius: 0, x: 0, y: -outlineSize)
                .shadow(color: outlineColor, radius: 0, x: outlineSize, y: outlineSize)
                .shadow(color: outlineColor, radius: 0, x: -outlineSize, y: -outlineSize)
                .shadow(color: outlineColor, radius: 0, x: outlineSize, y: -outlineSize)
                .shadow(color: outlineColor, radius: 0, x: -outlineSize, y: outlineSize)
                .shadow(color: Color.black.opacity(state.isPasted ? 0.4 : 0), radius: 8, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(isLongPressed ? 0.5 : 0), lineWidth: 2)
                )
        }
        .padding(60)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                state.isPasted = true
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    isLongPressed = true
                    startMouseLocation = NSEvent.mouseLocation
                    if let window = state.window {
                        startWindowOrigin = window.frame.origin
                    }
                    NSSound.beep()
                }
                .sequenced(before: DragGesture(coordinateSpace: .global))
                .onChanged { value in
                    switch value {
                    case .second(true, _):
                        if isLongPressed, let window = state.window {
                            let currentMouse = NSEvent.mouseLocation
                            let deltaX = currentMouse.x - startMouseLocation.x
                            let deltaY = currentMouse.y - startMouseLocation.y
                            let newOrigin = NSPoint(
                                x: startWindowOrigin.x + deltaX,
                                y: startWindowOrigin.y + deltaY
                            )
                            window.setFrameOrigin(newOrigin)
                        }
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    isLongPressed = false
                    state.triggerChange() // Konum değişince kaydet
                }
        )
        .contextMenu {
            Section("Size") {
                Button("Grow") { state.scale += 0.1; state.triggerChange() }
                Button("Shrink") { state.scale -= 0.1; state.triggerChange() }
            }
            Section("Rotate") {
                Button("Rotate Clockwise") { state.rotation += 15; state.triggerChange() }
                Button("Rotate Counter-Clockwise") { state.rotation -= 15; state.triggerChange() }
            }
            Divider()
            Button("Remove") {
                state.window?.close()
                // Notification veya callback ile listeden silinecek
            }
            Button("Reset") {
                state.scale = 1.0
                state.rotation = 0.0
                state.triggerChange()
            }
        }
    }
}
