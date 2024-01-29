import SwiftUI
import MetricKit

@main
struct RuddarrApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if DEBUG
        dependencies = .mock
        #endif

        NetworkMonitor.shared.start()

        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil
        ) { _ in
            Telemetry.shared.maybeUploadTelemetry()
        }
    }

    @AppStorage("theme", store: dependencies.store) var theme: Theme = .purple
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(theme.color)
                .withAppState()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, MXMetricManagerSubscriber {
    func application(_ application: UIApplication) -> Bool {
        let metricManager = MXMetricManager.shared
        metricManager.add(self)

        URLSession.shared.configuration.waitsForConnectivity = true

        return true
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        guard let firstPayload = payloads.first else { return }
        print(firstPayload.dictionaryRepresentation())
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let firstPayload = payloads.first else { return }
        print(firstPayload.dictionaryRepresentation())
    }
}

extension ShapeStyle where Self == Color {
    static var systemBackground: Color { Color(UIColor.systemBackground) }
    static var secondarySystemBackground: Color { Color(UIColor.secondarySystemBackground) }
}
