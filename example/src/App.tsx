import { useEffect } from 'react';
import { Text, View, StyleSheet } from 'react-native';
import {
  configure,
  requestPermission,
  startTracking,
} from 'react-native-gps-tracker';

export default function App() {
  useEffect(() => {
    configure({
      android: {
        intervalMs: 3000,
        distanceFilterMeters: 0,
        providers: ['gps', 'network'],
        writeLastKnownLocationOnStart: true,
      },
      ios: {
        distanceFilterMeters: 100,
        stationaryRadiusMeters: 150,
      },
      actions: [
        {
          type: 'file',
          fileName: 'gps-tracker-locations.txt',
        },
        {
          // Loai action: gui du lieu location len API.
          type: 'http',
          // Endpoint nhan du lieu location.
          url: 'https://webhook.site/afeccc43-dcd6-42d2-a1cb-f4657df582a8',
          // HTTP method dung de gui request.
          method: 'POST',
          // Bat che do gom location vao queue truoc khi gui.
          batchSync: true,
          // Tu dong gui request khi queue du so diem cau hinh.
          autoSync: true,
          // So diem toi thieu de auto sync khi khong cau hinh maxBatchSize.
          autoSyncThreshold: 5,
          // Gom du 5 diem thi gui 1 request, moi request toi da 5 diem.
          maxBatchSize: 10,
          // Header gui kem request.
          headers: {
            'Content-Type': 'application/json',
          },
          // Template cho tung location duoc luu vao queue.
          body: {
            lat: '$latitude',
            long: '$longitude',
            accuracy: '$accuracy',
            timestamp: '$timestamp',
          },
          // Template cho request batch, $locations la mang cac body da gom.
          batchBody: {
            locations: '$locations',
          },
        },
      ],
    });
    requestPermission();
    startTracking();
    return () => {};
  }, []);
  return (
    <View style={styles.container}>
      <Text>Result: {2134234}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
