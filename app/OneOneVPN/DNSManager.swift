import Foundation
import NetworkExtension

/// Which Cloudflare resolver to use.
enum Resolver: String, CaseIterable, Identifiable {
    case standard, malware, family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "1.1.1.1"
        case .malware: return "Block malware"
        case .family: return "Block malware + adult content"
        }
    }

    var dohURL: URL {
        switch self {
        case .standard: return URL(string: "https://cloudflare-dns.com/dns-query")!
        case .malware: return URL(string: "https://security.cloudflare-dns.com/dns-query")!
        case .family: return URL(string: "https://family.cloudflare-dns.com/dns-query")!
        }
    }

    var dotServerName: String {
        switch self {
        case .standard: return "one.one.one.one"
        case .malware: return "security.cloudflare-dns.com"
        case .family: return "family.cloudflare-dns.com"
        }
    }

    var addresses: [String] {
        switch self {
        case .standard: return ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001"]
        case .malware: return ["1.1.1.2", "1.0.0.2", "2606:4700:4700::1112", "2606:4700:4700::1002"]
        case .family: return ["1.1.1.3", "1.0.0.3", "2606:4700:4700::1113", "2606:4700:4700::1003"]
        }
    }
}

enum DNSProtocolChoice: String, CaseIterable, Identifiable {
    case https = "HTTPS"
    case tls = "TLS"

    var id: String { rawValue }
}

/// Wraps `NEDNSSettingsManager`, which installs a system-wide encrypted DNS
/// configuration. iOS only lets the *user* switch it on, in
/// Settings → General → VPN & Device Management → DNS, so `isActive` reflects
/// what they picked there.
@MainActor
final class DNSManager: ObservableObject {
    @Published var resolver: Resolver = .standard
    @Published var proto: DNSProtocolChoice = .https
    @Published private(set) var isInstalled = false
    @Published private(set) var isActive = false
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private let manager = NEDNSSettingsManager.shared()

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        do {
            try await manager.loadFromPreferences()
            isInstalled = manager.dnsSettings != nil
            isActive = manager.isEnabled
            if let doh = manager.dnsSettings as? NEDNSOverHTTPSSettings,
               let match = Resolver.allCases.first(where: { $0.dohURL == doh.serverURL }) {
                resolver = match
                proto = .https
            } else if let dot = manager.dnsSettings as? NEDNSOverTLSSettings,
                      let match = Resolver.allCases.first(where: { $0.dotServerName == dot.serverName }) {
                resolver = match
                proto = .tls
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func install() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await manager.loadFromPreferences()
            manager.localizedDescription = "1.1.1.1 – \(resolver.title) (\(proto.rawValue))"
            switch proto {
            case .https:
                let settings = NEDNSOverHTTPSSettings(servers: resolver.addresses)
                settings.serverURL = resolver.dohURL
                manager.dnsSettings = settings
            case .tls:
                let settings = NEDNSOverTLSSettings(servers: resolver.addresses)
                settings.serverName = resolver.dotServerName
                manager.dnsSettings = settings
            }
            try await manager.saveToPreferences()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }

    func remove() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await manager.loadFromPreferences()
            try await manager.removeFromPreferences()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }
}
