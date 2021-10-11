import SwiftUI

@main
final class Wishlist: App {
  @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

  var body: some Scene {
    WindowGroup { [handleURLScheme = appDelegate.urlSchemeHandler.handle] in
      ContentView(
        environment: ContentViewEnvironment(
          repository: AppListRepository(
            apps: appDelegate.appRepository.appsPublisher,
            app: appDelegate.appRepository.appPublisher(forId:),
            versionHistory: appDelegate.appRepository.versionsPublisher(forId:),
            checkForUpdates: appDelegate.updateChecker.update,
            recordViewed: appDelegate.appRepository.recordAppViewed,
            addApps: appDelegate.appAdder.addApps(from:),
            deleteApps: appDelegate.appRepository.deleteApps(ids:),
            deleteAllApps: appDelegate.appRepository.deleteAllApps
          ),
          theme: appDelegate.settings.$theme,
          notificationsEnabled: appDelegate.settings.$enableNotificaitons,
          sortOrderState: appDelegate.settings.sortOrderStatePublisher,
          refresh: appDelegate.appRepository.refresh,
          checkForUpdates: appDelegate.updateChecker.updateIfNeeded,
          scheduleBackgroundTasks: appDelegate.scheduleBackgroundTasks,
          system: appDelegate.system
        )
      )
      .onOpenURL { url in
        if let urlScheme = URLScheme(rawValue: url) {
          try? handleURLScheme(urlScheme)
        }
      }
    }
  }
}
