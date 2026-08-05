import Cocoa

struct GitHubAsset: Codable {
    let name: String
    let browser_download_url: String
}

struct GitHubRelease: Codable {
    let tag_name: String
    let html_url: String
    let assets: [GitHubAsset]
}

enum UpdateChecker {
    // GitHub repo used to publish releases (owner/repo)
    static let repo = "UlucKaymak/Stickurr-MacOS"

    private static var progressWindow: NSWindow?

    /// Checks GitHub Releases for a newer version.
    /// - Parameter silent: if true, stays quiet when already up to date or on error (used on app launch).
    ///   If false, always shows a result alert (used when the user manually clicks the version item).
    static func checkForUpdates(silent: Bool) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                guard error == nil,
                      let data = data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data) else {
                    if !silent { showErrorAlert(message: "Please check your internet connection and try again.") }
                    return
                }

                let latestVersion = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

                if isVersion(latestVersion, newerThan: currentVersion) {
                    showUpdateAlert(release: release, latestVersion: latestVersion)
                } else if !silent {
                    showUpToDateAlert(currentVersion: currentVersion)
                }
            }
        }.resume()
    }

    private static func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let count = max(parts1.count, parts2.count)
        for i in 0..<count {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 != p2 { return p1 > p2 }
        }
        return false
    }

    // MARK: - Alerts

    private static func showUpdateAlert(release: GitHubRelease, latestVersion: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update Available"
        alert.informativeText = "Stickurr v\(latestVersion) is available. Download and install it now?"
        alert.addButton(withTitle: "Download & Install")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            downloadAndInstall(release: release, version: latestVersion)
        }
    }

    private static func showUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "You're up to date!"
        alert.informativeText = "Stickurr v\(currentVersion) is the latest version."
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Update Failed"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")

        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func promptRestart(version: String) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Update Installed"
        alert.informativeText = "Stickurr v\(version) has been installed. Restart now to use the new version?"
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            relaunch()
        }
    }

    // MARK: - Progress window

    private static func showProgressWindow(version: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 110),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.title = "Stickurr"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))

        let label = NSTextField(labelWithString: "Downloading Stickurr v\(version)…")
        label.frame = NSRect(x: 20, y: 60, width: 280, height: 20)
        label.alignment = .center
        container.addSubview(label)

        let spinner = NSProgressIndicator(frame: NSRect(x: 140, y: 25, width: 40, height: 20))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        container.addSubview(spinner)

        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        progressWindow = window
    }

    private static func closeProgressWindow() {
        progressWindow?.close()
        progressWindow = nil
    }

    // MARK: - Download & install

    private static func downloadAndInstall(release: GitHubRelease, version: String) {
        guard let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }),
              let assetURL = URL(string: asset.browser_download_url) else {
            // No installable asset found — fall back to opening the release page.
            if let releaseURL = URL(string: release.html_url) {
                NSWorkspace.shared.open(releaseURL)
            }
            return
        }

        showProgressWindow(version: version)

        let task = URLSession.shared.downloadTask(with: assetURL) { location, _, error in
            guard error == nil, let location = location else {
                DispatchQueue.main.async {
                    closeProgressWindow()
                    showErrorAlert(message: "The update couldn't be downloaded. Please check your connection and try again.")
                }
                return
            }

            do {
                let fm = FileManager.default
                let workDir = fm.temporaryDirectory.appendingPathComponent("StickurrUpdate-\(UUID().uuidString)")
                try fm.createDirectory(at: workDir, withIntermediateDirectories: true)

                let zipPath = workDir.appendingPathComponent(asset.name)
                try fm.moveItem(at: location, to: zipPath)

                try installUpdate(zipPath: zipPath, workDir: workDir)

                DispatchQueue.main.async {
                    closeProgressWindow()
                    promptRestart(version: version)
                }
            } catch {
                DispatchQueue.main.async {
                    closeProgressWindow()
                    showErrorAlert(message: "Couldn't install the update: \(error.localizedDescription)")
                }
            }
        }
        task.resume()
    }

    /// Runs on a background thread (URLSession's download callback).
    private static func installUpdate(zipPath: URL, workDir: URL) throws {
        let fm = FileManager.default

        // Unzip the downloaded archive
        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        unzip.arguments = ["-o", "-q", zipPath.path, "-d", workDir.path]
        let pipe = Pipe()
        unzip.standardOutput = pipe
        unzip.standardError = pipe
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw NSError(domain: "UpdateChecker", code: 1, userInfo: [NSLocalizedDescriptionKey: "Couldn't unpack the update archive."])
        }

        guard let newAppPath = findAppBundle(in: workDir) else {
            throw NSError(domain: "UpdateChecker", code: 2, userInfo: [NSLocalizedDescriptionKey: "Couldn't find Stickurr.app inside the update."])
        }

        // Best-effort: strip the quarantine flag so Gatekeeper doesn't block the relaunch
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", newAppPath.path]
        try? xattr.run()
        xattr.waitUntilExit()

        let currentAppPath = Bundle.main.bundleURL
        let backupPath = currentAppPath.deletingLastPathComponent()
            .appendingPathComponent(".Stickurr-old-\(UUID().uuidString)")

        // Swap the running app bundle for the new one. Safe even while running:
        // the current process keeps its already-open file handles, and the
        // relaunch below picks up whatever is on disk at that path afterwards.
        try fm.moveItem(at: currentAppPath, to: backupPath)
        do {
            try fm.moveItem(at: newAppPath, to: currentAppPath)
        } catch {
            try? fm.moveItem(at: backupPath, to: currentAppPath)
            throw error
        }

        try? fm.removeItem(at: backupPath)
        try? fm.removeItem(at: workDir)
    }

    private static func findAppBundle(in directory: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator {
            if url.pathExtension == "app" {
                return url
            }
        }
        return nil
    }

    private static func relaunch() {
        let appPath = Bundle.main.bundlePath
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appPath]
        try? process.run()
        NSApp.terminate(nil)
    }
}
