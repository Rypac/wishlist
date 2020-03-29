//
//  AppDelegate.swift
//  Wishlist
//
//  Created by Ryan Davis on 1/9/19.
//  Copyright © 2019 Ryan Davis. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  let wishlist = Wishlist(database: try! Database())
  let settings = SettingsStore()

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    settings.register()

    return true
  }

  // MARK: UISceneSession Lifecycle

  func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
    let activity: ActivityIdentifier

    if let userActivity = options.userActivities.first, let specifiedActivity = ActivityIdentifier(rawValue: userActivity.activityType) {
      activity = specifiedActivity
      connectingSceneSession.userInfo = userActivity.userInfo as? [String: Any]
    } else {
      activity = .list
    }

    return activity.sceneConfiguration()
  }

}
