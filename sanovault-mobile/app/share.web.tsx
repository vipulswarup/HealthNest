import { Text, View } from 'react-native';

export default function ShareScreen() {
  return (
    <View style={{ flex: 1, padding: 24, justifyContent: 'center' }}>
      <Text>Share from WhatsApp or Mail only works in the iOS app, not in the browser.</Text>
    </View>
  );
}
