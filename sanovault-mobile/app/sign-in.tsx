import * as AppleAuthentication from 'expo-apple-authentication';
import * as WebBrowser from 'expo-web-browser';
import * as Linking from 'expo-linking';
import { useRouter } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { Platform, Pressable, Text, View } from 'react-native';
import { API_URL, api } from '../lib/api';
import { setToken } from '../lib/session';

WebBrowser.maybeCompleteAuthSession();

export default function SignIn() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [appleAvailable, setAppleAvailable] = useState(false);

  const finish = useCallback(async (token: string) => {
    await setToken(token);
    const ack = await api('/api/users/beta-acknowledgement');
    router.replace(ack.acknowledged ? '/home' : '/beta');
  }, [router]);

  useEffect(() => {
    if (Platform.OS === 'ios') {
      void AppleAuthentication.isAvailableAsync().then(setAppleAvailable);
    }
    const sub = Linking.addEventListener('url', ({ url }) => {
      const parsed = Linking.parse(url);
      const token = typeof parsed.queryParams?.token === 'string' ? parsed.queryParams.token : '';
      if (token) {
        void finish(token);
      }
    });
    return () => sub.remove();
  }, [finish]);

  const signInWithApple = async () => {
    setError('');
    try {
      const credential = await AppleAuthentication.signInAsync({
        requestedScopes: [
          AppleAuthentication.AppleAuthenticationScope.FULL_NAME,
          AppleAuthentication.AppleAuthenticationScope.EMAIL,
        ],
      });
      if (!credential.identityToken) throw new Error('Apple did not return a token');
      const fullName = [credential.fullName?.givenName, credential.fullName?.familyName].filter(Boolean).join(' ');
      const body = await api('/api/auth/mobile/apple', {
        method: 'POST',
        body: JSON.stringify({
          identityToken: credential.identityToken,
          email: credential.email,
          fullName: fullName || null,
        }),
      });
      if (!body.token) throw new Error('Could not start the app session');
      await finish(body.token);
    } catch (caught) {
      if (caught && typeof caught === 'object' && 'code' in caught && caught.code === 'ERR_REQUEST_CANCELED') return;
      setError(caught instanceof Error ? caught.message : 'Apple sign-in failed');
    }
  };

  const openWebSignIn = async () => {
    setError('');
    try {
      const result = await WebBrowser.openAuthSessionAsync(
        `${API_URL}/auth/signin?native=1`,
        'sanovault://auth',
      );
      if (result.type === 'success' && result.url) {
        const parsed = Linking.parse(result.url);
        const token = typeof parsed.queryParams?.token === 'string' ? parsed.queryParams.token : '';
        if (token) {
          await finish(token);
          return;
        }
      }
      setError('Sign-in did not finish. Use Apple on this iPhone, or Google / email in the browser window.');
    } catch {
      setError('Could not open sign-in.');
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: '#fff', padding: 24, justifyContent: 'center' }}>
      <Text style={{ fontSize: 32, fontWeight: '700', color: '#111827' }}>SanoVault</Text>
      <Text style={{ marginTop: 8, fontSize: 16, color: '#4b5563', lineHeight: 22 }}>
        On this iPhone, use Apple. Google and email stay on the website if that is how you already sign in.
      </Text>
      {appleAvailable ? (
        <AppleAuthentication.AppleAuthenticationButton
          buttonType={AppleAuthentication.AppleAuthenticationButtonType.SIGN_IN}
          buttonStyle={AppleAuthentication.AppleAuthenticationButtonStyle.BLACK}
          cornerRadius={12}
          style={{ width: '100%', height: 52, marginTop: 28 }}
          onPress={() => void signInWithApple()}
        />
      ) : null}
      <Pressable
        onPress={() => void openWebSignIn()}
        style={{
          marginTop: appleAvailable ? 12 : 28,
          minHeight: 52,
          borderRadius: 12,
          alignItems: 'center',
          justifyContent: 'center',
          borderWidth: 1,
          borderColor: '#d1d5db',
        }}
      >
        <Text style={{ fontSize: 17, fontWeight: '600', color: '#111827' }}>Google or email</Text>
      </Pressable>
      {error ? <Text style={{ marginTop: 16, color: '#b91c1c' }}>{error}</Text> : null}
    </View>
  );
}
