//
//  Database.swift
//  Wishlist
//
//  Created by Ryan Davis on 6/10/19.
//  Copyright © 2019 Ryan Davis. All rights reserved.
//

import Foundation

class Database {
  private let databaseLocation: URL

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(fileManager: FileManager = .default) throws {
    let documentsDirectory = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    databaseLocation = documentsDirectory.appendingPathComponent("apps.json", isDirectory: false)
  }

  private func populate() throws {
    let url = Bundle.main.url(forResource: "apps", withExtension: "json")!
    let data = try Data(contentsOf: url)
    let apps = try JSONDecoder().decode([App].self, from: data)
    write(apps: apps)
  }

  func read() -> [App] {
    do {
      let data = try Data(contentsOf: databaseLocation)
      return try decoder.decode([App].self, from: data)
    } catch {
      print("Error while reading apps: \(error)")
      return []
    }
  }

  func write(apps: [App]) {
    do {
      let data = try encoder.encode(apps)
      try data.write(to: databaseLocation)
    } catch {
      print("Error while writing apps: \(error)")
    }
  }
}
