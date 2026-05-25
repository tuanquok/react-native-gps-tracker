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
      actions: [
        {
          type: 'http',
          url: 'https://example.com/api/locations',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: {
            latitude: '$latitude',
            longitude: '$longitude',
            accuracy: '$accuracy',
            speed: '$speed',
            course: '$course',
            timestamp: '$timestamp',
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
