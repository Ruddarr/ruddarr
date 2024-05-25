import SwiftUI

#if os(iOS)
struct ContentView: View {
    @EnvironmentObject var settings: AppSettings

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.deviceType) private var deviceType

    @State private var isPortrait = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showTabViewOverlay: Bool = true

    @ScaledMetric(relativeTo: .body) var safeAreaInsetHeight = 48

    private let orientationChangePublisher = NotificationCenter.default.publisher(
        for: UIDevice.orientationDidChangeNotification
    )

    init() {
        UITabBar.appearance().unselectedItemTintColor = .clear
        UITabBar.appearance().tintColor = .clear // this does not work (see `.tint` below)
        UITabBarItem.appearance().badgeColor = .orange
    }

    var body: some View {
        if deviceType == .pad {
            padBody
        } else {
            phoneBody
        }
    }

    var padBody: some View {
        NavigationSplitView(
            columnVisibility: $columnVisibility,
            sidebar: {
                sidebar
                    .ignoresSafeArea(.all, edges: .bottom)
            },
            detail: {
                screen(for: dependencies.router.selectedTab)
            }
        )
        .displayToasts()
        .whatsNewSheet()
        .onAppear {
            isPortrait = UIDevice.current.orientation.isPortrait
            columnVisibility = isPortrait ? .automatic : .doubleColumn
        }
        .onChange(of: scenePhase, handleScenePhaseChange)
        .onReceive(orientationChangePublisher, perform: handleOrientationChange)
    }

    var phoneBody: some View {
        TabView(selection: dependencies.$router.selectedTab.onSet {
            if dependencies.router.selectedTab == $0 { goToRootOrTop(tab: $0) }
        }) {
            ForEach(Tab.allCases) { tab in
                screen(for: tab)
                    .tint(settings.theme.tint) // restore tint for view
                    .tabItem { tab.label }
                    .badge(tab == .activity ? Queue.shared.badgeCount : 0)
                    .displayToasts()
                    .tag(tab)
            }
        }
        .tint(.clear) // hide selected `tabItem` tint
        .overlay(alignment: .bottom) { // the default `tabItem`s are hidden, display our own
            let columns: [GridItem] = Array(repeating: .init(.flexible()), count: Tab.allCases.count)

            if showTabViewOverlay {
                LazyVGrid(columns: columns) {
                    ForEach(Tab.allCases) { tab in
                        tab.stack
                            .foregroundStyle(
                                dependencies.router.selectedTab == tab ? settings.theme.tint : .gray
                            )
                    }
                }
                .allowsHitTesting(false)
                .padding(.horizontal, 4)
            }
        }
        .whatsNewSheet()
        .onChange(of: scenePhase, handleScenePhaseChange)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            showTabViewOverlay = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            showTabViewOverlay = true
        }
    }

    var sidebar: some View {
        List(selection: dependencies.$router.selectedTab.optional) {
            Text(verbatim: "Ruddarr")
                .font(.largeTitle.bold())

            ForEach(Tab.allCases) { tab in
                if tab != .settings {
                    rowButton(for: tab)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            List(selection: dependencies.$router.selectedTab.optional) {
                ForEach(Tab.allCases) { tab in
                    if tab == .settings {
                        rowButton(for: tab)
                    }
                }
            }
            .frame(height: safeAreaInsetHeight)
            .scrollDisabled(true)
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView()
        case .series:
            SeriesView()
        case .activity:
            ActivityView()
        case .calendar:
            CalendarView()
        case .settings:
            SettingsView()
        }
    }

    @ViewBuilder
    func rowButton(for tab: Tab) -> some View {
        Button {
            if dependencies.router.selectedTab == tab {
                goToRootOrTop(tab: tab)
            } else {
                dependencies.router.selectedTab = tab
            }

            columnVisibility = isPortrait ? .automatic : .doubleColumn
        } label: {
            tab.row
        }
    }

    func handleScenePhaseChange(_ oldPhase: ScenePhase, _ phase: ScenePhase) {
        if phase == .active {
            Notifications.shared.maybeUpdateWebhooks(settings)
            Telemetry.shared.maybeUploadTelemetry(settings)
        }

        if phase == .background {
            addQuickActions()
        }
    }

    func handleOrientationChange(_ notification: Notification) {
        isPortrait = UIDevice.current.orientation.isPortrait

        if !isPortrait {
            columnVisibility = .doubleColumn
        }

        if isPortrait {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                columnVisibility = .detailOnly
            }
        }
    }

    func goToRootOrTop(tab: Tab) {
        switch tab {
        case .movies:
            dependencies.router.moviesPath.isEmpty
                ? dependencies.router.moviesScroll.send()
                : (dependencies.router.moviesPath = .init())
        case .series:
            dependencies.router.seriesPath.isEmpty
                ? dependencies.router.seriesScroll.send()
                : (dependencies.router.seriesPath = .init())
        case .activity:
            break
        case .calendar:
            dependencies.router.calendarScroll.send()
        case .settings:
            dependencies.router.settingsPath = .init()
        }
    }

    func addQuickActions() {
        QuickActions().registerShortcutItems()
    }
}

#Preview {
    ContentView()
        .withAppState()
}
#endif
