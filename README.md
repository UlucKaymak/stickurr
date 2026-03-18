# Stickurr 🖼️

Stickurr is a lightweight, native macOS application that allows you to place stickers (images) anywhere on your desktop. It's designed to be simple, interactive, and persistent.

## Features

### 🚀 Core Functionality
- **Add Stickers:** Add any image (PNG, JPG, etc.) from your local files to your desktop.
- **Clipboard Support:** Quickly add stickers directly from your clipboard (Image or File URL).
- **Persistence:** Your stickers stay exactly where you left them. All positions, scales, and rotations are saved and restored automatically when you restart the app.
- **Menu Bar App:** Runs discreetly in your macOS menu bar for quick access.

### 🖱️ Interactive Gestures
- **Move:** Long-press on a sticker to "pick it up" and drag it anywhere on your screen.
- **Context Menu:** Right-click any sticker to access quick actions:
  - **Grow/Shrink:** Resize your stickers (hold `Shift` for 5x faster scaling).
  - **Rotate:** Spin your stickers clockwise or counter-clockwise.
  - **Toggle Outline:** Show or hide a clean white border around your sticker.
  - **Reset:** Instantly restore a sticker to its original size and rotation.
  - **Remove:** Delete a single sticker from your desktop.

### 🛠️ Technical Highlights
- **Native Swift:** Built entirely with Swift 5.9+.
- **Hybrid Architecture:** Combines **AppKit** (`NSPanel`, `NSStatusItem`) for window management and **SwiftUI** for a modern, interactive user interface.
- **Reactive State:** Uses **Combine** to sync state between windows and the menu bar.
- **Persistence:** Efficiently saves data in JSON format within `UserDefaults`.
- **Lightweight:** Minimal CPU and memory footprint.

## Requirements
- macOS 13.0 or later (Ventura+)
- Apple Silicon or Intel Mac

## Development
To build the project locally:
```bash
cd Stickurr
swift build
```
To run the application:
```bash
swift run Stickurr
```

## License
Created by Uluc Kaymak. All rights reserved.
