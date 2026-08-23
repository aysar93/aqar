import Foundation

let projectDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let entitlementsURL = projectDirectory
    .appendingPathComponent("ios/Runner/Runner.entitlements")

let data = try Data(contentsOf: entitlementsURL)
let plist = try PropertyListSerialization.propertyList(
    from: data,
    options: [],
    format: nil
)

guard var entitlements = plist as? [String: Any] else {
    throw NSError(
        domain: "AqarEntitlements",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid entitlements plist"]
    )
}

entitlements["com.apple.developer.applesignin"] = ["Default"]

let updatedData = try PropertyListSerialization.data(
    fromPropertyList: entitlements,
    format: .xml,
    options: 0
)
try updatedData.write(to: entitlementsURL, options: .atomic)

print("Configured Sign in with Apple entitlement")
