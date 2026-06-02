# react-native-gps-tracker

Background GPS tracking lib for React Native with support for IOS and Android

## Installation


```sh
npm install react-native-gps-tracker
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

On iOS, HTTP actions support batching with option names similar to
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
- `maxBatchSize`: number of queued records required before iOS sends one batch
  request. After a successful response, only that uploaded batch is removed
  from SQLite.
- `batchBody`: optional wrapper for the batch request body. Use `$locations`
  where the queued array should be injected. If omitted, the request body is
  the raw locations array.

If `autoSync` is `false`, locations are only queued until you call:

```ts
sync();
```

On iOS, the batched HTTP queue is persisted in SQLite at the native layer.
Successful HTTP responses in the `2xx` range remove only the uploaded rows;
failed requests keep their rows for the next automatic or manual sync.
Android currently keeps the existing immediate-send behavior; batching can be
implemented there separately with the same JavaScript config shape.


## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
