import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, Text, View } from 'react-native';
import { api } from '../lib/api';

export default function Beta() {
  const router = useRouter();
  const [version, setVersion] = useState('');
  const [agreed, setAgreed] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    void api('/api/users/beta-acknowledgement').then((body) => {
      if (body.acknowledged) router.replace('/home');
      else setVersion(body.version || '');
    }).catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load'));
  }, [router]);

  const accept = async () => {
    setError('');
    try {
      await api('/api/users/beta-acknowledgement', {
        method: 'POST',
        body: JSON.stringify({ version }),
      });
      router.replace('/home');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not save');
    }
  };

  return (
    <View style={{ flex: 1, backgroundColor: '#fff', padding: 24, justifyContent: 'center' }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>Before you continue</Text>
      <Text style={{ marginTop: 12, fontSize: 16, color: '#4b5563', lineHeight: 22 }}>
        SanoVault is a private family folder in beta. It is not a hospital system, and it is not certified under HIPAA, GDPR, or India’s DPDP Act. You are choosing to keep family records here anyway.
      </Text>
      <Pressable onPress={() => setAgreed((value) => !value)} style={{ marginTop: 24, minHeight: 48, justifyContent: 'center' }}>
        <Text style={{ fontSize: 16 }}>{agreed ? '[x] ' : '[ ] '}I understand and want to continue</Text>
      </Pressable>
      <Pressable
        disabled={!agreed || !version}
        onPress={() => void accept()}
        style={{ marginTop: 16, backgroundColor: agreed ? '#0175C2' : '#9ca3af', minHeight: 52, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}
      >
        <Text style={{ color: '#fff', fontWeight: '600' }}>Continue</Text>
      </Pressable>
      {error ? <Text style={{ marginTop: 16, color: '#b91c1c' }}>{error}</Text> : null}
    </View>
  );
}
