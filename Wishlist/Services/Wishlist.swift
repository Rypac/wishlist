//
//  Wishlist.swift
//  Wishlist
//
//  Created by Ryan Davis on 6/10/19.
//  Copyright © 2019 Ryan Davis. All rights reserved.
//

import Foundation
import Combine

final class Wishlist {
  let apps: AnyPublisher<[App], Never>

  private let database: Database
  private let appsUpdatedSubject = PassthroughSubject<Void, Never>()

  init(database: Database) throws {
    self.database = database
    self.apps = appsUpdatedSubject
      .map(database.read)
      .eraseToAnyPublisher()
  }

  func write(apps: [App]) {
    database.write(apps: apps)
  }
}
