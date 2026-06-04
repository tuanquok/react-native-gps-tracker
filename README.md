# react-native-gps-tracker

Background GPS tracking lib for React Native with support for IOS and Android

## Installation

```sh
npm install react-native-gps-tracker
```

or:

```sh
yarn add react-native-gps-tracker
```

### iOS setup

Install pods after adding the package:

```sh
cd ios
pod install
```

Add the required location, motion, and background mode entries to your app
`Info.plist`:

```xml
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Your app needs location access in the background to track GPS trips.</string>

<key>NSLocationWhenInUseUsageDescription</key>
<string>Your app needs location access while it is open to read the current GPS position.</string>

<key>NSMotionUsageDescription</key>
<string>Your app uses motion data to optimize GPS tracking while the device moves or stays still.</string>

<key>UIBackgroundModes</key>
<array>
  <string>location</string>
</array>
```

In Xcode, also enable the same background mode:

1. Open your app workspace.
2. Select your app target.
3. Open `Signing & Capabilities`.
4. Add `Background Modes`.
5. Enable `Location updates`.

If your app needs tracking to resume after the process is relaunched, import the
native module in `AppDelegate.swift`:

```swift
import GpsTracker
```

Then call `restoreTrackingIfNeeded()` from
`application(_:didFinishLaunchingWithOptions:)` after your React Native setup:

```swift
GPSManager.shared.restoreTrackingIfNeeded()
```

This does not replace calling `requestPermission()` and `startTracking()` from
JavaScript. It only restores native tracking if it was already enabled before
the app process restarted.

### Android setup

The library manifest declares the service, boot receiver, and required
permissions, and React Native/Gradle should merge them into your app manifest:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

The merged manifest also includes:

```xml
<service
  android:name="com.gpstracker.GpsTrackerLocationService"
  android:exported="false"
  android:foregroundServiceType="location"
  android:stopWithTask="false" />

<receiver
  android:name="com.gpstracker.GpsTrackerBootReceiver"
  android:enabled="true"
  android:exported="false">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED" />
  </intent-filter>
</receiver>
```

If your app manifest uses strict manifest tooling or a custom manifest merge
setup, copy the entries above into `android/app/src/main/AndroidManifest.xml`.

For Android 10+ background tracking, the user must grant background location.
For Android 13+, notification permission is also required for the foreground
service notification. `requestPermission()` asks for foreground location,
notification permission where applicable, and background location when needed.

If you send locations to a local `http://` backend during development, allow
cleartext traffic in your app manifest or use HTTPS:

```xml
<application
  android:usesCleartextTraffic="true">
  ...
</application>
```

## Usage


```ts
import {
  configure,
  requestPermission,
  startTracking,
  stopTracking,
  sync,
} from 'react-native-gps-tracker';

configure({
  android: {
    intervalMs: 3000,
    distanceFilterMeters: 0,
    providers: ['gps', 'network'],
    writeLastKnownLocationOnStart: true,
  },
  ios: {
    distanceFilterMeters: 10,
    stationaryRadiusMeters: 150,
  },
  actions: [
    {
      type: 'http',
      url: 'https://example.com/api/locations',
      method: 'POST',
      headers: {
        Authorization: 'Bearer token',
        'Content-Type': 'application/json',
      },
      body: {
        latitude: '$latitude',
        longitude: '$longitude',
        accuracy: '$accuracy',
        timestamp: '$timestamp',
      },
    },
  ],
});

requestPermission();
startTracking();

// Optional.
stopTracking();
```

## Batched HTTP uploads

HTTP actions support batching with option names similar to
`react-native-background-geolocation`: `autoSync`, `autoSyncThreshold`,
`batchSync`, and `maxBatchSize`.

```ts
configure({
  actions: [
    {
      type: 'http',
      url: 'https://example.com/api/locations/batch',
      method: 'POST',
      batchSync: true,
      autoSync: true,
      autoSyncThreshold: 10,
      maxBatchSize: 50,
      body: {
        latitude: '$latitude',
        longitude: '$longitude',
        accuracy: '$accuracy',
        speed: '$speed',
        course: '$course',
        timestamp: '$timestamp',
      },
      batchBody: {
        locations: '$locations',
      },
    },
  ],
});
```

- `batchSync: true`: stores each rendered location body in a native queue
  instead of uploading immediately.
- `autoSync: true`: automatically flushes the queue. Defaults to `true`.
- `autoSyncThreshold`: fallback minimum queued records before auto sync when
  `maxBatchSize` is not set.
- `maxBatchSize`: number of queued records required before native sends one batch
  request. After a successful response, only that uploaded batch is removed
  from the native queue.
- `batchBody`: optional wrapper for the batch request body. Use `$locations`
  where the queued array should be injected. If omitted, the request body is
  the raw locations array.

If `autoSync` is `false`, locations are only queued until you call:

```ts
sync();
```

On iOS, the batched HTTP queue is persisted in SQLite at the native layer. On
Android, it is persisted with Room. Successful HTTP responses in the `2xx`
range remove only the uploaded rows; failed requests keep their rows for the
next automatic or manual sync.


## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
