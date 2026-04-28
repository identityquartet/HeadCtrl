import SwiftUI

struct ContentView: View {
    @State private var api = HeadscaleAPI()

    var body: some View {
        if api.serverURL.isEmpty || api.apiKey.isEmpty {
            NavigationStack {
                SettingsView(api: api, isInitialSetup: true)
            }
        } else {
            TabView {
                NodesView(api: api)
                    .tabItem { Label("Nodes", systemImage: "network") }
                UsersView(api: api)
                    .tabItem { Label("Users", systemImage: "person.2") }
                RoutesView(api: api)
                    .tabItem { Label("Routes", systemImage: "arrow.triangle.branch") }
                APIKeysView(api: api)
                    .tabItem { Label("API Keys", systemImage: "key") }
                SettingsView(api: api, isInitialSetup: false)
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
        }
    }
}
