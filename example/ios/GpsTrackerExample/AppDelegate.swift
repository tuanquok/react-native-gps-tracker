import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import GpsTracker

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  var window: UIWindow?
  
  var reactNativeDelegate: ReactNativeDelegate?
  var reactNativeFactory: RCTReactNativeFactory?
  
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let delegate = ReactNativeDelegate()
    let factory = RCTReactNativeFactory(delegate: delegate)
    delegate.dependencyProvider = RCTAppDependencyProvider()
    
    reactNativeDelegate = delegate
    reactNativeFactory = factory
    
    GPSManager.shared.restoreTrackingIfNeeded()
    
    let rootView = factory.rootViewFactory.view(
      withModuleName: "GpsTrackerExample",
      initialProperties: nil,
      launchOptions: launchOptions
    )
    let rootViewController = UIViewController()
    rootViewController.view = rootView

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = rootViewController
    window?.makeKeyAndVisible()
    
    return true
  }
  func applicationDidEnterBackground(
    
    _ application:
    
    UIApplication
    
  ) {
    
    print(
      
  """
  
  APP -> BACKGROUND
  
  \(Date())
  
  """
  
    )
    
  }
  
  func applicationWillTerminate(
      _ application:
      UIApplication
  ) {

      print(
  """
  APP TERMINATED
  \(Date())
  """
      )

  }
}

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
  override func sourceURL(for bridge: RCTBridge) -> URL? {
    self.bundleURL()
  }
  
  override func bundleURL() -> URL? {
#if DEBUG
    RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
#else
    Bundle.main.url(forResource: "main", withExtension: "jsbundle")
#endif
  }
}
