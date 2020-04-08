import Foundation

public extension FileManager {
  func storeURL(for appGroup: String, databaseName: String) -> URL {
    guard let fileContainer = containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
      fatalError("Shared file container could not be created.")
    }
    return fileContainer.appendingPathComponent("\(databaseName).sqlite")
  }
}
