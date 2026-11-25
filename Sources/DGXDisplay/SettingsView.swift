import DGXDisplayCore
import SwiftUI

/// Host, user, and key for the SSH session. The menu bar's own appearance.
struct SettingsView: View {
    @ObservedObject var store: Store

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("Host", prompt: "IP or hostname", text: $store.host)
            field("User", prompt: SSHLaunch.defaultUser, text: $store.user)
            field("Key", prompt: "nvsync.key", text: $store.identity)
        }
        .padding(20)
        .frame(width: 420)
    }

    private func field(_ name: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
                .onSubmit { store.commitConnection() }
        }
    }
}
