//
//  AboutView.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import WebKit
import Resolver
import CocoaLumberjackSwift

// Version and storage info plus the maintenance actions from the old options screen:
// reset album art cache, share app logs, open source licenses
struct AboutView: View {
    @Environment(\.settingsCoordinator) private var coordinator

    private let settings: SavedSettings = Resolver.resolve()
    private let downloadsManager: DownloadsManager = Resolver.resolve()
    private let store: Store = Resolver.resolve()

    @State private var resetArtConfirmationPresented = false
    @State private var shareLogsItem: ShareLogsItem?

    private struct ShareLogsItem: Identifiable {
        let url: URL
        var id: String { url.path }
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "???"
        let build = Bundle.main.infoDictionary?[kCFBundleVersionKey as String] ?? "???"
        return "\(version) build \(build)"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Version", value: versionString)
                LabeledContent("Free Space", value: formatFileSize(bytes: downloadsManager.freeSpace))
                LabeledContent("Total Space", value: formatFileSize(bytes: downloadsManager.totalSpace))
            }

            Section {
                Button("Reset Album Art Cache") {
                    resetArtConfirmationPresented = true
                }
                .accessibilityIdentifier("options.resetAlbumArtCache")

                Button("Share App Logs") {
                    shareAppLogs()
                }
                .accessibilityIdentifier("options.shareAppLogs")

                Button("Open Source Licenses") {
                    coordinator?.showLicenses()
                }
                .accessibilityIdentifier("options.openSourceLicenses")
            }
        }
        .listStyle(.insetGrouped)
        .alert("Reset Album Art Cache", isPresented: $resetArtConfirmationPresented) {
            Button("OK", role: .destructive) { resetAlbumArtCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to do this? This will clear all saved album art.")
        }
        .sheet(item: $shareLogsItem) { item in
            ShareSheet(activityItems: [item.url]) {
                // Delete the zip once the share sheet is done with it
                do {
                    try FileManager.default.removeItem(at: item.url)
                } catch {
                    DDLogError("[AboutView] Failed to remove log file at path \(item.url.path) with error: \(error)")
                }
            }
        }
    }

    private func resetAlbumArtCache() {
        let serverId = settings.currentServerId
        store.resetCoverArtCache(serverId: serverId)
        store.resetArtistArtCache(serverId: serverId)
        SceneDelegate.shared?.popLibraryTab()
    }

    private func shareAppLogs() {
        guard let path = settings.zipAllLogFiles() else {
            DDLogError("[AboutView] Failed to share logs due to a problem with the path")
            return
        }
        shareLogsItem = ShareLogsItem(url: URL(fileURLWithPath: path))
    }
}

// UIActivityViewController bridge; ShareLink can't run a completion to clean up the
// shared file, so the old share-sheet flow is kept
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var completion: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            completion?()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// The bundled open source licenses page
struct LicensesView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        if let url = Bundle.main.url(forResource: "open_source_licenses", withExtension: "html") {
            webView.loadFileURL(url, allowingReadAccessTo: url)
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
