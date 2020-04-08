import Foundation

public extension NSRecursiveLock {
  func synchronized(_ execute: () -> Void) {
    lock()
    defer { unlock() }
    execute()
  }

  func synchronized<T>(_ execute: () -> T) -> T {
    lock()
    defer { unlock() }
    return execute()
  }
}
