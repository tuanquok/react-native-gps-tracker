import { type TurboModule, TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  requestPermission(): void;

  startTracking(): void;

  stopTracking(): void;

  getCurrentLocation(): void;
}

export default TurboModuleRegistry.getEnforcing<Spec>('GpsTracker');
