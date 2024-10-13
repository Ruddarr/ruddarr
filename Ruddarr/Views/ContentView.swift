import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    #if os(macOS)
        @Environment(\.controlActiveState) var controlActiveState
        private var deviceType = nil as DeviceType?
    #else
        @Environment(\.scenePhase) private var scenePhase
        @Environment(\.deviceType) private var deviceType
    #endif

    var body: some View {
        TabView(selection: dependencies.$router.selectedTab) {
            Tab(movies.label, image: movies.icon, value: movies) {
                MoviesView()
            }

            Tab(series.label, image: series.icon, value: series) {
                SeriesView()
            }

            Tab(calendar.label, systemImage: calendar.icon, value: calendar) {
                CalendarView()
            }

            Tab(activity.label, systemImage: activity.icon, value: activity) {
                ActivityView()
            }
            .badge(Queue.shared.badgeCount)

            Tab(TabItem.settings.label, systemImage: TabItem.settings.icon, value: TabItem.settings) {
                SettingsView()
            }
            .defaultVisibility(.hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(iOS)
            .tabViewSidebarHeader {
                Text(verbatim: "Ruddarr")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        #endif
        .tabViewSidebarBottomBar {
            instancePickers
        }
        .onAppear {
            if !isRunningIn(.preview) {
                dependencies.router.selectedTab = settings.tab
            }

            #if os(iOS)
                UITabBarItem.appearance().badgeColor = UIColor(settings.theme.tint)
            #endif
        }
        #if os(macOS)
            .onChange(of: controlActiveState, handleScenePhaseChange)
        #else
            .onChange(of: scenePhase, handleScenePhaseChange)
        #endif
        .displayToasts()
        .whatsNewSheet()
    }

    var movies: TabItem { TabItem.movies }
    var series: TabItem { TabItem.series }
    var calendar: TabItem { TabItem.calendar }
    var activity: TabItem { TabItem.activity }

#if os(macOS)
    func handleScenePhaseChange() {
        if controlActiveState == .key {
            Notifications.shared.maybeUpdateWebhooks(settings)
            Telemetry.shared.maybeUploadTelemetry(settings)
        }
    }
#else
    func handleScenePhaseChange(_ oldPhase: ScenePhase, _ phase: ScenePhase) {
        if phase == .active {
            Notifications.shared.maybeUpdateWebhooks(settings)
            Telemetry.shared.maybeUploadTelemetry(settings)
        }

        if phase == .background {
            QuickActions().registerShortcutItems()
        }
    }
#endif

    @ViewBuilder
    var instancePickers: some View {
        if dependencies.router.selectedTab == .movies {
            instancePicker(
                instances: settings.radarrInstances,
                selection: $settings.radarrInstanceId,
                label: settings.radarrInstance?.label,
                onChange: {
                    dependencies.router.moviesPath = .init()
                    dependencies.router.switchToRadarrInstance = settings.radarrInstanceId
                }
            )
        }

        if dependencies.router.selectedTab == .series {
            instancePicker(
                instances: settings.sonarrInstances,
                selection: $settings.sonarrInstanceId,
                label: settings.sonarrInstance?.label,
                onChange: {
                    dependencies.router.seriesPath = .init()
                    dependencies.router.switchToSonarrInstance = settings.sonarrInstanceId
                }
            )
        }
    }

    @ViewBuilder
    func instancePicker(
        instances: [Instance],
        selection: Binding<Instance.ID?>,
        label: String?,
        onChange: @escaping () -> Void
    ) -> some View {
        if instances.count > 1 {
            Menu {
                Picker("Instances", selection: selection) {
                    ForEach(instances) { instance in
                        Text(instance.label).tag(Optional.some(instance.id))
                    }
                }
                .onChange(of: selection.wrappedValue, onChange)
            } label: {
                HStack {
                    Image(systemName: "internaldrive")
                        .imageScale(.large)

                    Text(label ?? "")
                        .tint(.primary)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    ContentView()
        .withAppState()
}
