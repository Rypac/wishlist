import Foundation
import SwiftUI

extension Binding {
  func contains<Element>(_ element: Element) -> Binding<Bool> where Value == Set<Element> {
    Binding<Bool>(
      get: { wrappedValue.contains(element) },
      set: { newValue, transaction in
        if transaction.animation != nil {
          withTransaction(transaction) {
            if newValue {
              wrappedValue.insert(element)
            } else {
              wrappedValue.remove(element)
            }
          }
        } else {
          if newValue {
            wrappedValue.insert(element)
          } else {
            wrappedValue.remove(element)
          }
        }
      }
    )
  }
}
