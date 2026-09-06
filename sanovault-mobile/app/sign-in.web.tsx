import { useRouter } from 'expo-router';
import { Pressable, Text, View } from 'react-native';
import { API_URL } from '../lib/api';

export default function SignIn() {
  const router = useRouter();

  return (
    <View style={{ flex: 1, backgroundColor: '#fff', padding: 24, justifyContent: 'center', maxWidth: 480, alignSelf: 'center', width: '100%' }}>
      <Text style={{ fontSize: 32, fontWeight: '700', color: '#111827' }}>SanoVault</Text>
      <Text style={{ marginTop: 8, fontSize: 16, color: '#4b5563', lineHeight: 22 }}>
        The website is the signed-in family vault. Open sanovault.com in this browser, or run the iOS app for Share and Apple Health.
      </Text>
      <Pressable
        onPress={() => {
          window.location.assign(`${API_URL}/auth/signin`);
        }}
        style={{ marginTop: 28, backgroundColor: '#0175C2', minHeight: 52, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}
      >
        <Text style={{ color: '#fff', fontSize: 17, fontWeight: '600' }}>Open sanovault.com</Text>
      </Pressable>
      <Pressable onPress={() => router.replace('/home')} style={{ marginTop: 12, minHeight: 44, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: '#6b7280' }}>I already have an app session in this browser</Text>
      </Pressable>
    </View>
  );
}
