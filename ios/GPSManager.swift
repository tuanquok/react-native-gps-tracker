import CoreLocation
import Foundation
import UIKit

private enum TrackingMode: String {
  case stationary
  case moving
}

@objcMembers
@objc(GpsTrackerGPSManager)
public class GPSManager: NSObject, CLLocationManagerDelegate, MotionManagerDelegate {
  public static let shared = GPSManager()

  private static let configKey = "GpsTracker.config"
  private static let trackingEnabledKey = "GpsTracker.trackingEnabled"
  private static let trackingModeKey = "GpsTracker.trackingMode"
  private static let stationaryRegionIdentifier = "GpsTracker.stationary"

  private let locationManager = CLLocationManager()
  private let motionManager = MotionManager.shared
  private var config: [String: Any] = GPSManager.loadConfig()
  private var isTracking = UserDefaults.standard.bool(
    forKey: GPSManager.trackingEnabledKey
  )
  private var trackingMode: TrackingMode = {
    let rawValue = UserDefaults.standard.string(forKey: trackingModeKey)
    return TrackingMode(rawValue: rawValue ?? "") ?? .stationary
  }()
  private var lastLocation: CLLocation?

  public override init() {
    super.init()
    locationManager.delegate = self
    motionManager.delegate = self
  }

  @objc(configureWithConfig:)
  public func configure(config: NSDictionary) {
    guard let nextConfig = config as? [String: Any] else {
      print("GpsTracker configure failed: invalid config")
      return
    }

    self.config = nextConfig
    GPSManager.saveConfig(nextConfig)
  }

  @objc(requestPermission)
  public func requestPermission() {
    locationManager.requestAlwaysAuthorization()
  }

  @objc(restoreTrackingIfNeeded)
  public func restoreTrackingIfNeeded() {
    guard isTracking else {
      return
    }

    configureLocationManager()
    startPassiveMonitoring()

    switch trackingMode {
    case .moving:
      startMovingTracking()
    case .stationary:
      requestCurrentLocation()
    }
  }

  public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedAlways:
      print("AUTHORIZED ALWAYS")
      if isTracking {
        configureLocationManager()
        startPassiveMonitoring()
        requestCurrentLocation()
      }
    case .authorizedWhenInUse:
      print("AUTHORIZED WHEN IN USE")
      if isTracking {
        configureLocationManager()
        startPassiveMonitoring()
        requestCurrentLocation()
      }
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

  @objc(getCurrentLocation)
  public func getCurrentLocation() {
    requestCurrentLocation()
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

    lastLocation = location
    refreshStationaryRegion(around: location)
    runConfiguredActions(for: location)
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didExitRegion region: CLRegion
  ) {
    guard
      isTracking,
      region.identifier == GPSManager.stationaryRegionIdentifier
    else {
      return
    }

    print("GpsTracker exited stationary region")
    setTrackingMode(.moving)
    startMovingTracking()
    requestCurrentLocation()
  }

  public func locationManager(
    _ manager: CLLocationManager,
    monitoringDidFailFor region: CLRegion?,
    withError error: Error
  ) {
    print("GpsTracker region monitoring failed: \(error)")
  }

  public func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    if let error = error as? CLError {
      print(error.code)
    }
  }

  @objc(startTracking)
  public func startTracking() {
    guard !isTracking else {
      print("ALREADY TRACKING - REFRESH MONITORING")
      configureLocationManager()
      startPassiveMonitoring()
      motionManager.startMonitoring()
      requestCurrentLocation()
      return
    }

    isTracking = true
    UserDefaults.standard.set(true, forKey: GPSManager.trackingEnabledKey)

    configureLocationManager()
    startPassiveMonitoring()
    motionManager.startMonitoring()
    requestCurrentLocation()
  }

  @objc(stopTracking)
  public func stopTracking() {
    guard isTracking else {
      return
    }

    isTracking = false
    UserDefaults.standard.set(false, forKey: GPSManager.trackingEnabledKey)

    stopAllLocationMonitoring()
    motionManager.stopMonitoring()
    print("STOP TRACKING")
  }

  func motionManager(_ manager: MotionManager, didChangeState state: MotionState) {
    guard isTracking else {
      return
    }

    if state.isMoving {
      setTrackingMode(.moving)
      startMovingTracking()
      requestCurrentLocation()
      return
    }

    if state == .stationary {
      setTrackingMode(.stationary)
      stopMovingTracking()

      if let lastLocation {
        refreshStationaryRegion(around: lastLocation)
      } else {
        requestCurrentLocation()
      }
    }
  }

  private func configureLocationManager() {
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.distanceFilter = iosDistanceFilter
    locationManager.allowsBackgroundLocationUpdates = true
    locationManager.pausesLocationUpdatesAutomatically = false
    locationManager.activityType = .otherNavigation
  }

  private func startPassiveMonitoring() {
    print("START SIGNIFICANT TRACKING")
    locationManager.startMonitoringSignificantLocationChanges()
    motionManager.startMonitoring()
  }

  private func startMovingTracking() {
    configureLocationManager()
    print("GpsTracker start moving GPS")
    locationManager.startUpdatingLocation()
    locationManager.startMonitoringSignificantLocationChanges()
  }

  private func stopMovingTracking() {
    print("GpsTracker stop moving GPS")
    locationManager.stopUpdatingLocation()
    locationManager.startMonitoringSignificantLocationChanges()
  }

  private func stopAllLocationMonitoring() {
    locationManager.stopUpdatingLocation()
    locationManager.stopMonitoringSignificantLocationChanges()

    for region in locationManager.monitoredRegions
    where region.identifier == GPSManager.stationaryRegionIdentifier {
      locationManager.stopMonitoring(for: region)
    }
  }

  private func requestCurrentLocation() {
    guard CLLocationManager.locationServicesEnabled() else {
      return
    }

    configureLocationManager()
    locationManager.requestLocation()
  }

  private func refreshStationaryRegion(around location: CLLocation) {
    guard isTracking else {
      return
    }

    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      return
    }

    for region in locationManager.monitoredRegions
    where region.identifier == GPSManager.stationaryRegionIdentifier {
      locationManager.stopMonitoring(for: region)
    }

    let region = CLCircularRegion(
      center: location.coordinate,
      radius: stationaryRadius,
      identifier: GPSManager.stationaryRegionIdentifier
    )
    region.notifyOnEntry = false
    region.notifyOnExit = true

    print(
      "GpsTracker monitor stationary region \(stationaryRadius)m " +
        "\(location.coordinate.latitude),\(location.coordinate.longitude)"
    )
    locationManager.startMonitoring(for: region)
  }

  private func setTrackingMode(_ mode: TrackingMode) {
    guard trackingMode != mode else {
      return
    }

    trackingMode = mode
    UserDefaults.standard.set(mode.rawValue, forKey: GPSManager.trackingModeKey)
    print("GpsTracker tracking mode: \(mode.rawValue)")
  }

  private var iosConfig: [String: Any] {
    config["ios"] as? [String: Any] ?? [:]
  }

  private var iosDistanceFilter: CLLocationDistance {
    numericIosConfigValue("distanceFilterMeters") ?? 10
  }

  private var stationaryRadius: CLLocationDistance {
    numericIosConfigValue("stationaryRadiusMeters") ?? 150
  }

  private func numericIosConfigValue(_ key: String) -> Double? {
    if let value = iosConfig[key] as? Double {
      return value
    }

    if let value = iosConfig[key] as? NSNumber {
      return value.doubleValue
    }

    return nil
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
