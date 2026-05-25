import GpsTracker from './NativeGpsTracker';

export type HttpActionConfig = {
  type: 'http';
  url: string;
  method?: 'POST' | 'PUT' | 'PATCH';
  headers?: Record<string, string>;
  body?: Record<string, unknown>;
  timeoutMs?: number;
};

export type FileActionConfig = {
  type: 'file';
  fileName?: string;
};

export type AndroidTrackerConfig = {
  intervalMs?: number;
  distanceFilterMeters?: number;
  providers?: Array<'gps' | 'network'>;
  writeLastKnownLocationOnStart?: boolean;
};

export type GpsTrackerConfig = {
  actions?: Array<HttpActionConfig | FileActionConfig>;
  android?: AndroidTrackerConfig;
};

export function configure(config: GpsTrackerConfig) {
  return GpsTracker.configure(config);
}

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
