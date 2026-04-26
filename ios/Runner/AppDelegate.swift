import Flutter
import UIKit
import GoogleMaps
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()
      
      // Request notification permissions
    UNUserNotificationCenter.current().delegate = self
    GMSServices.provideAPIKey("AIzaSyA-fyd6Kwg5R2H4ea-PFYI5ulsV7XTTmtQ") // ✅ moved inside here
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
