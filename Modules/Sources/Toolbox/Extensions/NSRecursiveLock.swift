import Foundation

public extension NSRecursiveLock {
  @inline(__always)
  func synchronized(_ execute: () -> Void) {
    lock()
    defer { unlock() }
    execute()
  }

  @inline(__always)
  func synchronized<T>(_ execute: () -> T) -> T {
    lock()
    defer { unlock() }
    return execute()
  }
}
