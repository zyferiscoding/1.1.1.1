import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dns: DNSManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    StatusHeader(isInstalled: dns.isInstalled, isActive: dns.isActive)
                }

                Section("Resolver") {
                    Picker("Resolver", selection: $dns.resolver) {
                        ForEach(Resolver.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()

                    Picker("Protocol", selection: $dns.proto) {
                        ForEach(DNSProtocolChoice.allCases) { Text("DNS over \($0.rawValue)").tag($0) }
                    }
                }

                Section {
                    Button(dns.isInstalled ? "Update 1.1.1.1" : "Install 1.1.1.1") {
                        Task { await dns.install() }
                    }
                    .disabled(dns.isBusy)

                    if dns.isInstalled {
                        Button("Remove", role: .destructive) {
                            Task { await dns.remove() }
                        }
                        .disabled(dns.isBusy)
                    }
                } footer: {
                    if dns.isInstalled && !dns.isActive {
                        Text("Installed but not switched on. Open Settings → General → VPN & Device Management → DNS and choose 1.1.1.1.")
                    }
                }

                Section {
                    Link("Check it's working", destination: URL(string: "https://one.one.one.one/help/")!)
                }
            }
            .navigationTitle("1.1.1.1")
        }
        .onChange(of: scenePhase) { phase in
            // Coming back from Settings: pick up whether the user switched it on.
            if phase == .active { Task { await dns.refresh() } }
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { dns.errorMessage != nil },
            set: { if !$0 { dns.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dns.errorMessage ?? "")
        }
    }
}

private struct StatusHeader: View {
    let isInstalled: Bool
    let isActive: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: isActive ? "lock.shield.fill" : "shield.slash")
                .font(.system(size: 44))
                .foregroundStyle(isActive ? .orange : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(isActive ? "Connected" : "Not connected")
                    .font(.title2.bold())
                Text(isActive
                     ? "Your DNS queries are encrypted by 1.1.1.1."
                     : isInstalled ? "Turn it on in Settings to finish." : "Install to encrypt your DNS.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
