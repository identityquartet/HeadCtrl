import SwiftUI

struct KeysView: View {
    let api: HeadscaleAPI
    @State private var selected = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Key Type", selection: $selected) {
                    Text("Pre-Auth").tag(0)
                    Text("API Keys").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if selected == 0 {
                    PreAuthKeysView(api: api)
                        .navigationTitle("Keys")
                } else {
                    APIKeysView(api: api)
                        .navigationTitle("Keys")
                }
            }
            .navigationTitle("Keys")
        }
    }
}
