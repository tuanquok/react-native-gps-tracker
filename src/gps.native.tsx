import GpsTracker from './NativeGpsTracker';

export function requestPermission() {
  return GpsTracker.requestPermission();
}

export function startTracking() {
  return GpsTracker.startTracking();
}

export function stopTracking() {
  return GpsTracker.stopTracking();
}

export function getCurrentLocation() {
  return GpsTracker.getCurrentLocation();
}
