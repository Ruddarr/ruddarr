import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.scenePhase) private var scenePhase

    @State private var isPortrait = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn
    @State private var showTabViewOverlay: Bool = true

    private let orientationChangePublisher = NotificationCenter.default.publisher(
        for: UIDevice.orientationDidChangeNotification
    )

    init() {
        UITabBar.appearance().unselectedItemTintColor = .clear

        // this does not work (see `.tint` below)
        UITabBar.appearance().tintColor = .red
    }

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView(
                columnVisibility: $columnVisibility,
                sidebar: {
                    sidebar
                },
                detail: {
                    screen(for: dependencies.router.selectedTab)
                }
            )
            .displayToasts()
            .onAppear {
                isPortrait = UIDevice.current.orientation.isPortrait
                columnVisibility = isPortrait ? .automatic : .doubleColumn
            }
            .onReceive(orientationChangePublisher) { _ in
                handleOrientationChange()
            }
            .onChange(of: scenePhase) { previous, phase in
                handleScenePhaseChange(phase, previous)
            }
        } else {
            TabView(selection: dependencies.$router.selectedTab.onSet {
                if $0 == dependencies.router.selectedTab {
                    pop(tab: $0)
                }
            }) {
                ForEach(Tab.allCases) { tab in
                    screen(for: tab)
                        .tint(settings.theme.tint) // restore tint for view
                        .tabItem { tab.label }
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
                                .onTapGesture { dependencies.router.selectedTab = tab }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .onChange(of: scenePhase) { previous, phase in
                handleScenePhaseChange(phase, previous)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                showTabViewOverlay = false
            }.onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                showTabViewOverlay = true
            }
        }
    }

    func pop(tab: Tab) {
        switch tab {
        case .movies:
            dependencies.router.moviesPath = .init()
        case .settings:
            dependencies.router.settingsPath = .init()
        default:
            break
        }
    }

    var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Ruddarr")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 20)
                .padding(.horizontal, 8)
                .offset(y: -4)

            ForEach(Tab.allCases) { tab in
                let button = Button {
                    dependencies.router.selectedTab = tab

                    if isPortrait {
                        columnVisibility = .detailOnly
                    }
                } label: {
                    HStack {
                        tab.row
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        Color(
                            dependencies.router.selectedTab == tab ? .secondarySystemFill : .clear
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if case .settings = tab {
                    Spacer()
                }

                button
            }
        }
        .scenePadding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(isPortrait ? .clear : .secondarySystemBackground)
        )
        .hideSidebarToggle(!isPortrait)
    }

    @ViewBuilder
    func screen(for tab: Tab) -> some View {
        switch tab {
        case .movies:
            MoviesView()
        case .shows:
            ShowsView()
        case .settings:
            SettingsView()
        }
    }

    func handleScenePhaseChange(_ phase: ScenePhase, _ previous: ScenePhase) {
        if phase == .active && previous == .inactive {
            Telemetry.shared.maybeUploadTelemetry(settings: settings)
        }

        if phase == .background {
            addQuickActions()
        }
    }

    func handleOrientationChange() {
        if let windowScene = UIApplication.shared.connectedScenes.first(
            where: { $0.activationState == .foregroundActive }
        ) as? UIWindowScene {
            isPortrait = windowScene.interfaceOrientation.isPortrait
            columnVisibility = isPortrait ? .detailOnly : .doubleColumn
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
