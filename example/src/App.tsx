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
        distanceFilterMeters: 10,
        stationaryRadiusMeters: 150,
      },
      actions: [
        {
          type: 'file',
          fileName: 'gps-tracker-locations.txt',
        },
        {
          type: 'http',
          url: 'https://webhook.site/2ad471f0-7406-4fcb-9553-541fa0963b11',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: {
            lat: '$latitude',
            long: '$longitude',
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
