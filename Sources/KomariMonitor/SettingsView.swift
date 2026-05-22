import SwiftUI

struct SettingsView: View {
    @State private var draft: Config
    @State private var revealSecrets = false
    @State private var errorMessage: String?
    let onSave: (Config) -> Void
    let onCancel: () -> Void

    init(config: Config, onSave: @escaping (Config) -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: config)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            form
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            footer
        }
        .padding(22)
        .frame(width: 520)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("VPSMonitor Settings")
                .font(.system(size: 20, weight: .semibold))
            Text("Connect this menu bar client to your Komari server. Credentials are saved only to your local user config file.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var form: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 12) {
            GridRow {
                Text("Komari URL")
                    .settingsLabel()
                TextField("https://komari.example.com", text: $draft.baseURL)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("API Key")
                    .settingsLabel()
                secretField("Optional bearer token", text: $draft.apiKey)
            }
            GridRow {
                Text("Session Token")
                    .settingsLabel()
                secretField("Optional session_token cookie value", text: $draft.sessionToken)
            }
            GridRow {
                Text("Cookie")
                    .settingsLabel()
                secretField("Optional raw Cookie header", text: $draft.cookie)
            }
            GridRow {
                Text("")
                Toggle("Verify TLS certificates", isOn: $draft.verifyTLS)
            }
            GridRow {
                Text("")
                Toggle("Show credentials while editing", isOn: $revealSecrets)
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(Config.path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Cancel", action: onCancel)
            Button("Save") {
                save()
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    @ViewBuilder
    private func secretField(_ prompt: String, text: Binding<String>) -> some View {
        if revealSecrets {
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        } else {
            SecureField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func save() {
        var next = draft
        next.normalize()
        guard !next.baseURL.isEmpty, URL(string: next.baseURL) != nil else {
            errorMessage = "Enter a valid Komari URL."
            return
        }
        do {
            try Config.save(next)
            onSave(next)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension Text {
    func settingsLabel() -> some View {
        self
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 104, alignment: .trailing)
    }
}

