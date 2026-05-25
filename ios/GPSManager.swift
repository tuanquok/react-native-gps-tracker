import CoreLocation
import Foundation
import UIKit

struct TrackingData {
  let lat: Double
  let lng: Double
  let speed: Double
  let course: Double
  let accuracy: Double
  let timestamp: Date
}

@objcMembers
public class GPSManager: NSObject, CLLocationManagerDelegate {
  public static let shared = GPSManager()

  private static let configKey = "GpsTracker.config"
  private static let trackingEnabledKey = "GpsTracker.trackingEnabled"

  private let locationManager = CLLocationManager()
  private var config: [String: Any] = GPSManager.loadConfig()
  private var isTracking = UserDefaults.standard.bool(
    forKey: GPSManager.trackingEnabledKey
  )

  public override init() {
    super.init()
    locationManager.delegate = self
  }

  public func configure(config: NSDictionary) {
    guard let nextConfig = config as? [String: Any] else {
      print("GpsTracker configure failed: invalid config")
      return
    }

    self.config = nextConfig
    GPSManager.saveConfig(nextConfig)
  }

  public func requestPermission() {
    locationManager.requestAlwaysAuthorization()
  }

  public func restoreTrackingIfNeeded() {
    guard isTracking else {
      return
    }

    startLocationMonitoring()
  }

  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways:
      print("AUTHORIZED ALWAYS")
    case .authorizedWhenInUse:
      print("AUTHORIZED WHEN IN USE")
    case .denied:
      print("DENIED")
    case .restricted:
      print("RESTRICTED")
    case .notDetermined:
      print("NOT DETERMINED")
    @unknown default:
      print("UNKNOWN")
    }
  }

  public func getCurrentLocation() {
    locationManager.requestLocation()
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didUpdateLocations locations: [CLLocation]
  ) {
    guard let location = locations.last else {
      return
    }

    print(
      """

      ==================

      WAKE APP

      TIME:

      \(Date())

      LAT:

      \(location.coordinate.latitude)

      LNG:

      \(location.coordinate.longitude)

      ==================

      """
    )

    runConfiguredActions(for: location)
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    if let error = error as? CLError {
      print(error.code)
    }
  }

  public func startTracking() {
    guard !isTracking else {
      print("ALREADY TRACKING")
      return
    }

    isTracking = true
    UserDefaults.standard.set(true, forKey: GPSManager.trackingEnabledKey)

    startLocationMonitoring()
  }

  public func stopTracking() {
    guard isTracking else {
      return
    }

    isTracking = false
    UserDefaults.standard.set(false, forKey: GPSManager.trackingEnabledKey)

    locationManager.stopMonitoringSignificantLocationChanges()
    print("STOP TRACKING")
  }

  private func startLocationMonitoring() {
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = 10
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false

    print("START SIGNIFICANT TRACKING")
    locationManager.startMonitoringSignificantLocationChanges()
  }

  private func runConfiguredActions(for location: CLLocation) {
    guard let actions = config["actions"] as? [[String: Any]] else {
      return
    }

    let locationPayload = makeLocationPayload(location)

    for action in actions {
      guard action["type"] as? String == "http" else {
        continue
      }

      sendHttpAction(action, locationPayload: locationPayload)
    }
  }

  private func sendHttpAction(
    _ action: [String: Any],
    locationPayload: [String: Any]
  ) {
    guard
      let urlString = action["url"] as? String,
      let url = URL(string: urlString)
    else {
      print("GpsTracker http action skipped: invalid url")
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = action["method"] as? String ?? "POST"
    request.timeoutInterval = action["timeoutMs"] as? TimeInterval ?? 30

    if let headers = action["headers"] as? [String: String] {
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
    }

    if request.value(forHTTPHeaderField: "Content-Type") == nil {
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }

    let bodyTemplate = action["body"] as? [String: Any] ?? locationPayload
    let body = renderTemplate(bodyTemplate, with: locationPayload)

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    } catch {
      print("GpsTracker http action skipped: invalid body \(error)")
      return
    }

    let backgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "GpsTrackerHttpAction",
      expirationHandler: nil
    )

    URLSession.shared.dataTask(with: request) { _, response, error in
      defer {
        if backgroundTask != .invalid {
          UIApplication.shared.endBackgroundTask(backgroundTask)
        }
      }

      if let error = error {
        print("GpsTracker http action failed: \(error)")
        return
      }

      if let response = response as? HTTPURLResponse {
        print("GpsTracker http action completed: \(response.statusCode)")
      }
    }.resume()
  }

  private func makeLocationPayload(_ location: CLLocation) -> [String: Any] {
    [
      "latitude": location.coordinate.latitude,
      "longitude": location.coordinate.longitude,
      "accuracy": location.horizontalAccuracy,
      "altitude": location.altitude,
      "speed": location.speed,
      "course": location.course,
      "timestamp": ISO8601DateFormatter().string(from: location.timestamp),
    ]
  }

  private func renderTemplate(
    _ value: Any,
    with locationPayload: [String: Any]
  ) -> Any {
    if let string = value as? String {
      guard string.hasPrefix("$") else {
        return string
      }

      let key = String(string.dropFirst())
      return locationPayload[key] ?? string
    }

    if let dictionary = value as? [String: Any] {
      return dictionary.mapValues { renderTemplate($0, with: locationPayload) }
    }

    if let array = value as? [Any] {
      return array.map { renderTemplate($0, with: locationPayload) }
    }

    return value
  }

  private static func loadConfig() -> [String: Any] {
    guard
      let data = UserDefaults.standard.data(forKey: configKey),
      let object = try? JSONSerialization.jsonObject(with: data),
      let config = object as? [String: Any]
    else {
      return [:]
    }

    return config
  }

  private static func saveConfig(_ config: [String: Any]) {
    guard JSONSerialization.isValidJSONObject(config) else {
      print("GpsTracker configure failed: config must be JSON serializable")
      return
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: config)
      UserDefaults.standard.set(data, forKey: configKey)
    } catch {
      print("GpsTracker configure failed: \(error)")
    }
  }
}
