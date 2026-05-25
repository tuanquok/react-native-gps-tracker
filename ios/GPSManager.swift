import Foundation

import CoreLocation

class GPSManager:
                    
  NSObject,

CLLocationManagerDelegate {
  
  static let shared = GPSManager()
  
  private let locationManager =
  
  CLLocationManager()
  
  override init() {
    
    super.init()
    
    locationManager.delegate = self
    
  }
  
  func requestPermission( ) {
    locationManager.requestAlwaysAuthorization()
  }
  
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
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
  
  func getCurrentLocation( ) {
    locationManager.requestLocation()
  }
  
  func locationManager(
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
      "LAT:",
      location.coordinate.latitude
    )
    
    print(
      "LNG:",
      location.coordinate.longitude
    )
    
  }
  
  func locationManager(
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
  
  func startTracking() {
    
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
    
    locationManager
      .startUpdatingLocation()
    
  }
  
  func stopTracking() {
    
    locationManager
      .stopUpdatingLocation()
    
  }
}

