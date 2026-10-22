import SwiftUI

@main
struct OneOneVPNApp: App {
    @StateObject private var dns = DNSManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dns)
        }
    }
}
