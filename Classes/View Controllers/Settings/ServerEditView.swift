//
//  ServerEditView.swift
//  iSub
//
//  Created by Ben Baron on 7/11/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import SwiftUI
import Resolver

// The add/edit server form, presented as a sheet. Save validates the fields
// (ServerFormValidator), verifies the server with a ping, persists it, makes it the
// current server, and runs the switch teardown.
//
// Unlike the old ServerEditViewController, saving an edited server builds the record
// from the current field values (with the same id), so renaming a server's URL,
// username, or password actually persists (fixes the long-standing edit bug).
struct ServerEditView: View {
    var serverToEdit: Server? = nil

    @Environment(\.dismiss) private var dismiss

    private let store: Store = Resolver.resolve()
    private let settings: SavedSettings = Resolver.resolve()
    private let serverSwitcher: ServerSwitcher = Resolver.resolve()

    private struct AlertInfo: Identifiable {
        let id = UUID()
        let message: String
        var focus: Field? = nil
    }

    private enum Field {
        case url, username, password
    }

    @State private var url = ""
    @State private var username = ""
    @State private var password = ""
    @State private var alert: AlertInfo?
    @State private var checkTask: Task<Void, Never>?
    @FocusState private var focusedField: Field?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://myserver.subsonic.org", text: $url)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .url)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .username }
                        .accessibilityIdentifier(AccessibilityId.serverEditURL)

                    TextField("username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier(AccessibilityId.serverEditUsername)

                    SecureField("password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { saveAction() }
                        .accessibilityIdentifier(AccessibilityId.serverEditPassword)
                } footer: {
                    Text("The URL must be in the format: http://mywebsite.com:port/folder — both the :port and /folder are optional.")
                }
            }
            .navigationTitle(serverToEdit == nil ? "Add Server" : "Edit Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(AccessibilityId.serverEditClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAction() }
                        .accessibilityIdentifier(AccessibilityId.serverEditSave)
                }
            }
            .alert("Error", isPresented: Binding(get: { alert != nil }, set: { if !$0 { alert = nil } })) {
                Button("OK") {
                    focusedField = alert?.focus
                    alert = nil
                }
            } message: {
                Text(alert?.message ?? "")
            }
        }
        .onAppear {
            if let serverToEdit {
                url = serverToEdit.url.absoluteString
                username = serverToEdit.username
                password = serverToEdit.password
            } else {
                focusedField = .url
            }
        }
        .onDisappear {
            checkTask?.cancel()
        }
    }

    private func saveAction() {
        guard let normalizedURL = ServerFormValidator.normalizeURL(url) else {
            alert = AlertInfo(message: "The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional", focus: .url)
            return
        }
        url = normalizedURL

        guard ServerFormValidator.isValidUsername(username) else {
            alert = AlertInfo(message: "Please enter a username", focus: .username)
            return
        }
        guard ServerFormValidator.isValidPassword(password) else {
            alert = AlertInfo(message: "Please enter a password", focus: .password)
            return
        }

        checkServer(urlString: normalizedURL)
    }

    private func checkServer(urlString: String) {
        // Prevent a double submission (e.g. keyboard return plus a Save tap) from
        // racing two status checks and persisting the server twice
        checkTask?.cancel()

        let task = Task {
            do {
                defer {
                    HUD.hide()
                }

                let responseData = try await AsyncStatusLoader(urlString: urlString, username: username, password: password).load()
                try Task.checkCancellation()

                guard let serverURL = URL(string: urlString) else {
                    alert = AlertInfo(message: "The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional", focus: .url)
                    return
                }

                // Reuse the edited server's id, or update an existing entry for the
                // same URL and username (e.g. a retry after a failed check) instead
                // of ever adding a duplicate
                let existingId = serverToEdit?.id ?? store.servers().first { $0.url == serverURL && $0.username == username }?.id
                let server = Server(id: existingId ?? store.nextServerId(), type: responseData.serverType, url: serverURL, username: username, password: password)
                server.isVideoSupported = responseData.isVideoSupported
                server.isNewSearchSupported = responseData.isNewSearchSupported
                if store.add(server: server) {
                    settings.currentServer = server
                }

                NotificationCenter.postOnMainThread(name: Notifications.reloadServerList)

                dismiss()

                if UIDevice.isPad {
                    SceneDelegate.shared.padRootViewController?.menuViewController.showHome()
                }

                serverSwitcher.switchServer()
            } catch {
                if error.isCanceled {
                    return
                }

                let message: String
                if let error = error as? SubsonicError, case .badCredentials = error {
                    message = "Either your username or password is incorrect, please try again"
                } else {
                    message = "Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError: \(error)"
                }
                alert = AlertInfo(message: message)
            }
        }
        checkTask = task

        HUD.show(message: "Checking Server") {
            HUD.hide()
            task.cancel()
        }
    }
}
