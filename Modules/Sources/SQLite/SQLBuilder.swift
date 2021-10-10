import Foundation

@resultBuilder
struct SQLBuilder {
  static func buildBlock(_ components: String...) -> String {
    components.joined(separator: "\n")
  }

  static func buildOptional(_ component: String?) -> String {
    component ?? ""
  }

  static func buildEither(first component: String) -> String {
    component
  }

  static func buildEither(second component: String) -> String {
    component
  }

  static func buildArray(_ components: [String]) -> String {
    components.joined(separator: "\n")
  }

  static func buildExpression(_ expression: String) -> String {
    expression
  }

  static func buildFinalResult(_ component: String) -> String {
    component
  }
}
