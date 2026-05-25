import Foundation

import CoreLocation


struct TrackingData {
  
  let lat: Double
  
  let lng: Double
  
  let speed: Double
  
  let course: Double
  
  let accuracy: Double
  
  let timestamp: Date
  
}
@objcMembers
public class GPSManager:
                    
  NSObject,

CLLocationManagerDelegate {
  
  public static let shared = GPSManager()
  private static let trackingEnabledKey = "GpsTracker.trackingEnabled"
  
  private let locationManager = CLLocationManager()
  
  private var isTracking =
    UserDefaults.standard.bool(
      forKey: GPSManager.trackingEnabledKey
    )
  
  public override init() {
    
    super.init()
    
    locationManager.delegate = self
    
  }
  
  public func requestPermission( ) {
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
  
  public func getCurrentLocation( ) {
    locationManager.requestLocation()
  }
  
  public func locationManager(
    _ manager:
    CLLocationManager,
    
    didUpdateLocations
    locations:
    [CLLocation]
  ) {
    guard let location =
            
            locations.last else {
      
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
    
  }
  
  public func locationManager(
    _ manager:
    CLLocationManager,
    
    didFailWithError
    error: Error
  ) {
    
    if let error = error as? CLError {
      print(error.code)
    }
    
  }
  //Chỉ update khi di chuyển > 10m
  
  public func startTracking() {
    guard !isTracking else {
      
      print(
        
        "ALREADY TRACKING"
        
      )
      
      return
      
    }
    
    isTracking = true
    
    UserDefaults.standard.set(
      true,
      forKey: GPSManager.trackingEnabledKey
    )
    
    startLocationMonitoring()
    
  }
  
  private func startLocationMonitoring() {
    
    locationManager
      .desiredAccuracy =
    kCLLocationAccuracyBest
    
    locationManager
      .distanceFilter =
    10
    locationManager
      .allowsBackgroundLocationUpdates
    = true
    
    locationManager
      .pausesLocationUpdatesAutomatically
    = false
    
    print("START SIGNIFICANT TRACKING")
    locationManager
      .startMonitoringSignificantLocationChanges()
  }
  
  public func stopTracking() {
    guard isTracking else {
      
      return
      
    }
    
    isTracking =
    
    false
    
    UserDefaults.standard.set(
      false,
      forKey: GPSManager.trackingEnabledKey
    )
    
    locationManager
      .stopMonitoringSignificantLocationChanges()
    print(
      
      "STOP TRACKING"
      
    )
  }
  
}
