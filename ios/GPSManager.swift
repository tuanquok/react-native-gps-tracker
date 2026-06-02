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
  private let httpQueue = GpsTrackerSQLiteQueue.shared
  private let batchFlushStateQueue = DispatchQueue(label: "GpsTrackerBatchFlushState")
  private var flushingBatchActionIndexes = Set<Int>()
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

  @objc(sync)
  public func sync() {
    guard let actions = config["actions"] as? [[String: Any]] else {
      return
    }

    for (index, action) in actions.enumerated() {
      guard
        action["type"] as? String == "http",
        boolValue(action["batchSync"]) == true
      else {
        continue
      }

      flushBatchHttpAction(action, actionIndex: index)
    }
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

    for (index, action) in actions.enumerated() {
      guard action["type"] as? String == "http" else {
        continue
      }

      runHttpAction(action, actionIndex: index, locationPayload: locationPayload)
    }
  }

  private func runHttpAction(
    _ action: [String: Any],
    actionIndex: Int,
    locationPayload: [String: Any]
  ) {
    let body = renderLocationBody(action, locationPayload: locationPayload)
    guard boolValue(action["batchSync"]) == true else {
      sendHttpAction(action, body: body)
      return
    }

    guard let locationBody = body as? [String: Any] else {
      print("GpsTracker batch action skipped: body must be a JSON object")
      return
    }

    let queueSize = enqueueBatchLocation(locationBody, actionIndex: actionIndex)
    guard boolValue(action["autoSync"], defaultValue: true) else {
      return
    }

    let requiredBatchSize = requiredAutoSyncBatchSize(action)
    print("GpsTracker batch queued: \(queueSize)/\(requiredBatchSize)")
    if queueSize >= requiredBatchSize {
      flushBatchHttpAction(action, actionIndex: actionIndex)
    }
  }

  private func sendHttpAction(
    _ action: [String: Any],
    body: Any,
    completion: ((Bool) -> Void)? = nil
  ) {
    guard
      let urlString = action["url"] as? String,
      let url = URL(string: urlString)
    else {
      print("GpsTracker http action skipped: invalid url")
      completion?(false)
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

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
    } catch {
      print("GpsTracker http action skipped: invalid body \(error)")
      completion?(false)
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
        completion?(false)
        return
      }

      if let response = response as? HTTPURLResponse {
        print("GpsTracker http action completed: \(response.statusCode)")
        completion?((200 ... 299).contains(response.statusCode))
        return
      }

      completion?(false)
    }.resume()
  }

  private func enqueueBatchLocation(_ locationBody: [String: Any], actionIndex: Int) -> Int {
    httpQueue.enqueue(actionIndex: actionIndex, body: locationBody)
  }

  private func flushBatchHttpAction(_ action: [String: Any], actionIndex: Int) {
    let queueSize = httpQueue.count(actionIndex: actionIndex)
    let requiredBatchSize = requiredAutoSyncBatchSize(action)
    guard requiredBatchSize > 0, queueSize >= requiredBatchSize else {
      print("GpsTracker batch sync skipped: \(queueSize)/\(requiredBatchSize) queued")
      return
    }

    guard beginBatchFlush(actionIndex: actionIndex) else {
      print("GpsTracker batch sync skipped: request already in flight")
      return
    }

    let batchSize = resolveBatchSize(action, queueSize: queueSize)
    let batch = httpQueue.loadBatch(actionIndex: actionIndex, limit: batchSize)
    guard !batch.isEmpty else {
      endBatchFlush(actionIndex: actionIndex)
      return
    }

    let locations = batch.map(\.body)
    let body = renderBatchBody(action, locations: locations)

    print("GpsTracker batch sync sending: \(batch.count) locations")
    sendHttpAction(action, body: body) { success in
      defer {
        self.endBatchFlush(actionIndex: actionIndex)
      }

      guard success else {
        return
      }

      self.httpQueue.delete(ids: batch.map(\.id))
      print("GpsTracker batch sync deleted: \(batch.count) locations")
    }
  }

  private func resolveBatchSize(_ action: [String: Any], queueSize: Int) -> Int {
    guard let maxBatchSize = intValue(action["maxBatchSize"]), maxBatchSize > 0 else {
      return queueSize
    }

    return min(maxBatchSize, queueSize)
  }

  private func requiredAutoSyncBatchSize(_ action: [String: Any]) -> Int {
    if let maxBatchSize = intValue(action["maxBatchSize"]), maxBatchSize > 0 {
      return maxBatchSize
    }

    return max(intValue(action["autoSyncThreshold"]) ?? 1, 1)
  }

  private func beginBatchFlush(actionIndex: Int) -> Bool {
    batchFlushStateQueue.sync {
      guard !flushingBatchActionIndexes.contains(actionIndex) else {
        return false
      }

      flushingBatchActionIndexes.insert(actionIndex)
      return true
    }
  }

  private func endBatchFlush(actionIndex: Int) {
    batchFlushStateQueue.sync {
      flushingBatchActionIndexes.remove(actionIndex)
    }
  }

  private func renderLocationBody(
    _ action: [String: Any],
    locationPayload: [String: Any]
  ) -> Any {
    let bodyTemplate = action["body"] ?? locationPayload
    return renderTemplate(bodyTemplate, with: locationPayload)
  }

  private func renderBatchBody(_ action: [String: Any], locations: [[String: Any]]) -> Any {
    guard let batchBodyTemplate = action["batchBody"] else {
      return locations
    }

    return renderBatchTemplate(batchBodyTemplate, locations: locations)
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

  private func renderBatchTemplate(_ value: Any, locations: [[String: Any]]) -> Any {
    if let string = value as? String {
      return string == "$locations" ? locations : string
    }

    if let dictionary = value as? [String: Any] {
      return dictionary.mapValues { renderBatchTemplate($0, locations: locations) }
    }

    if let array = value as? [Any] {
      return array.map { renderBatchTemplate($0, locations: locations) }
    }

    return value
  }

  private func boolValue(_ value: Any?, defaultValue: Bool = false) -> Bool {
    if let value = value as? Bool {
      return value
    }

    if let value = value as? NSNumber {
      return value.boolValue
    }

    return defaultValue
  }

  private func intValue(_ value: Any?) -> Int? {
    if let value = value as? Int {
      return value
    }

    if let value = value as? NSNumber {
      return value.intValue
    }

    return nil
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
