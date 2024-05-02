import os
import SwiftUI
import CloudKit
import Foundation

struct SettingsAboutSection: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Section(header: Text("About")) {
            share
            review
            support
        }
    }

    var share: some View {
        ShareLink(item: Links.AppShare) {
            Label {
                Text("Share App").tint(.primary)
            } icon: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(settings.theme.tint)
            }
        }
    }

    var review: some View {
        Link(destination: Links.AppStore) {
            Label {
                Text("Leave a Review").tint(.primary)
            } icon: {
                Image(systemName: "star")
                    .symbolVariant(.fill)
                    .foregroundStyle(settings.theme.tint)
            }
        }
    }

    var support: some View {
        Button {
            Task { await openSupportEmail() }
        } label: {
            Label {
                Text("Email Support").tint(.primary)
            } icon: {
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(settings.theme.tint)
            }
        }
    }

    // If desired add `mailto` to `LSApplicationQueriesSchemes` in `Info.plist`
    @MainActor
    func openSupportEmail() async {
        let uuid = UUID().uuidString.prefix(8)
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"

        let cloudKitStatus = try? await CKContainer.default().accountStatus()
        let cloudKitUserId = try? await CKContainer.default().userRecordID().recordName
        let ckStatus = Telemetry.shared.cloudKitStatus(cloudKitStatus)

        let address = "ruddarr@icloud.com"
        let subject = "Support Request (\(uuid))"

        let body = """
        ---
        The following information will help with debugging:

        Version: \(appVersion) (\(appBuild))
        Platform: \(systemName) (\(systemVersion))
        Account: \(ckStatus) (\(cloudKitUserId ?? "unknown"))
        Device: \(deviceId)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: "\n\n\(body)")
        ]

        if let mailtoUrl = components.url {
            if UIApplication.shared.canOpenURL(mailtoUrl) {
                if await UIApplication.shared.open(mailtoUrl) {
                    return
                }
            }

            leaveBreadcrumb(.warning, category: "settings.about", message: "Unable to open mailto", data: ["url": mailtoUrl])
        }

        if await UIApplication.shared.open(Links.GitHubDiscussions) {
            return
        }

        leaveBreadcrumb(.warning, category: "settings.about", message: "Unable to open GitHub Discussions")
    }

    var systemName: String {
        UIDevice.current.systemName
    }

    var systemVersion: String {
        UIDevice.current.systemVersion
    }

    var appVersion: String {
        if let appVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String {
            return appVersion
        }

        return String(localized: "Unknown")
    }

    var appBuild: String {
        if let buildNumber = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String {
            return buildNumber
        }

        return String(localized: "Unknown")
    }
}

#Preview {
    dependencies.router.selectedTab = .settings

    return ContentView()
        .withAppState()
}
