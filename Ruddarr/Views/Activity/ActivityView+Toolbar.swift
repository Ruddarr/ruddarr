import SwiftUI

extension ActivityView {
    func updateSortDirection() {
        switch sort.option {
        case .byAdded:
            sort.isAscending = false
        default:
            sort.isAscending = true
        }
    }

    func updateDisplayedItems() {
        var items: [QueueItem] = queue.items
            .flatMap { $0.value }
            .sorted(by: sort.option.isOrderedBefore)

        if sort.instance != ".all" {
            items = items.filter { $0.instanceId?.rawValue ?? nil == sort.instance }
        }

        if sort.errors {
            items = items.filter { $0.trackedDownloadStatus != .ok }
        }

        if !sort.isAscending {
            items = items.reversed()
        }

        self.items = items
    }

    @ToolbarContentBuilder
    var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            HStack {
                toolbarFilterButton
                toolbarSortingButton
            }
            .id(hotfixId)
        }
        ToolbarItem(placement: .primaryAction) {
            if let sableURL = sable {
                toolbarOpenSable
            }
        }
    }

    var toolbarFilterButton: some View {
        Menu {
            if queue.instances.count > 1 {
                instancePicker
            }

            Section {
                Toggle("Issues", systemImage: "exclamationmark.triangle", isOn: $sort.errors)
            }
        } label: {
            if sort.hasFilter {
                Image("filters.badge").offset(y: 3.2)
            } else{
                Image(systemName: "line.3.horizontal.decrease")
            }
        }
    }

    var instancePicker: some View {
        Menu {
            Picker("Instance", selection: $sort.instance) {
                Text("Any Instance").tag(".all")

                ForEach(queue.instances) { instance in
                    Text(instance.label).tag(instance.id.uuidString)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label("Instance", systemImage: "internaldrive")
        }
    }

    var toolbarSortingButton: some View {
        Menu {
            Section {
                Picker("Sort By", selection: $sort.option) {
                    ForEach(QueueSort.Option.allCases) { option in
                        option.label
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Picker("Direction", selection: $sort.isAscending) {
                    Label("Ascending", systemImage: "arrowtriangle.up").tag(true)
                    Label("Descending", systemImage: "arrowtriangle.down").tag(false)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .imageScale(.medium)
        }
    }
    
    var toolbarOpenSable: some View {
        Link("Open Sable", destination: URL(string: "sable://open")!)
    }
    
    var sable: String? {
        #if os(iOS)
            let url = "sable://open"

            if UIApplication.shared.canOpenURL(URL(string: url)!) {
                return url
            }
        #endif

        return nil
    }
}
