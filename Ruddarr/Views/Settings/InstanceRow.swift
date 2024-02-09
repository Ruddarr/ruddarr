import os
import SwiftUI

struct InstanceRow: View {
    @Binding var instance: Instance

    @State private var status: Status = .pending

    @EnvironmentObject var settings: AppSettings

    private let log: Logger = logger("settings")

    enum Status {
        case pending
        case reachable
        case unreachable
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(instance.label)

            HStack {
                switch status {
                case .pending: Text("Connecting...")
                case .reachable: Text("Connected")
                case .unreachable: Text("Connection failed").foregroundStyle(.red)
                }
            }
            .font(.footnote)
            .foregroundStyle(.gray)
        }.task {
            // I still kinda hate that this is happening, especially happening here on a list row that could run the task repeatedly as the user scrolls.
            do {
                status = .pending

                let data = try await dependencies.api.systemStatus(instance)

                instance.version = data.version
                instance.rootFolders = try await dependencies.api.rootFolders(instance)
                instance.qualityProfiles = try await dependencies.api.qualityProfiles(instance)

                settings.saveInstance(instance)

                status = .reachable
            } catch is CancellationError {
                // do nothing when task is cancelled
            } catch {
                log.error("Instance check failed: \(error)")
                status = .unreachable
            }
        }
    }
}
