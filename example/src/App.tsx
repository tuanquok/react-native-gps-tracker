import { useEffect } from 'react';
import { Text, View, StyleSheet } from 'react-native';
import { requestPermission, startTracking } from 'react-native-gps-tracker';

export default function App() {
  useEffect(() => {
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
