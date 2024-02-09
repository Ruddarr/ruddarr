import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    enum Path: Hashable {
        case libraries
        case createInstance
        case editInstance(Instance.ID)
    }

    var body: some View {
        NavigationStack(path: dependencies.$router.settingsPath) {
            List {
                instanceSection
                preferencesSection
                SettingsAboutSection()
                SettingsSystemSection()
            }
            .navigationTitle("Settings")
            .navigationDestination(for: Path.self) {
                switch $0 {
                case .libraries:
                    LibrariesView()

                case .createInstance:
                    let instance = Instance()
                    InstanceView(mode: .create, instance: instance)

                case .editInstance(let instanceId):
                    if let instance = settings.instanceById(instanceId) {
                        InstanceView(mode: .update, instance: instance)
                    }
                }
            }
        }
    }

    var instanceSection: some View {
        Section(header: Text("Instances")) {
            ForEach($settings.instances) { $instance in
                NavigationLink(value: Path.editInstance(instance.id)) {
                    InstanceRow(instance: $instance)
                }
            }

            NavigationLink(value: Path.createInstance) {
                Text("Add instance")
            }
        }
    }

    var preferencesSection: some View {
        Section {
            Picker("Theme", selection: $settings.theme) {
                ForEach(Theme.allCases) { theme in
                    Text(theme.rawValue)
                }
            }
            .tint(.secondary)
            .onChange(of: settings.theme) {
                dependencies.router.reset()
            }
        } header: {
            Text("Preferences")
        } footer: {
            Text("Styling options might be a paid feature in the final version, available as an in-app purchase.")
        }
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
