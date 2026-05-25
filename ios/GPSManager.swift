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
  
  private let locationManager = CLLocationManager()
  
  private var isTracking = false
  
  public override init() {
    
    super.init()
    
    locationManager.delegate = self
    
  }
  
  public func requestPermission( ) {
    locationManager.requestAlwaysAuthorization()
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
    locationManager
      .stopUpdatingLocation()
    print(
      
      "STOP TRACKING"
      
    )
  }
  
}
