public extension Result.Publisher where Failure == Error {
  init(catching body: () throws -> Success) {
    do {
      self.init(try body())
    } catch {
      self.init(error)
    }
  }
}
