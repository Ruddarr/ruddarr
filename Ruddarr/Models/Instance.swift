import Foundation

struct Instance: Identifiable, Equatable, Codable {
    var id = UUID()
    var label: String
    var urlString: String
}

typealias SavedInstances = [Instance]

extension SavedInstances: RawRepresentable {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder()
                .decode(SavedInstances.self, from: data)
        else {
            return nil
        }
        self = result
    }
    
    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return result
    }
}


//typealias Instance = URL
//@AppStorage("instances") var instances: [Instance] = []

//extension Array<Instance>: RawRepresentable {
//    public init?(rawValue: String) {
//        guard let data = rawValue.data(using: .utf8),
//            let result = try? JSONDecoder().decode([URL].self, from: data)
//        else {
//            return nil
//        }
//        self = result
//    }
//
//    public var rawValue: String {
//        guard let data = try? JSONEncoder().encode(self),
//            let result = String(data: data, encoding: .utf8)
//        else {
//            return "[]"
//        }
//        return result
//    }
//}

// https://stackoverflow.com/questions/49651571/is-sharing-userdefaults-between-ios-and-tvos-still-possible
