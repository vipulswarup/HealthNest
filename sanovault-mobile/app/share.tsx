import { useShareIntentContext } from 'expo-share-intent';
import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text } from 'react-native';
import { api, uploadFile } from '../lib/api';
import { getToken } from '../lib/session';

type Patient = { id: string; firstName: string; lastName?: string };

export default function ShareScreen() {
  const router = useRouter();
  const { hasShareIntent, shareIntent, resetShareIntent } = useShareIntentContext();
  const [people, setPeople] = useState<Patient[]>([]);
  const [status, setStatus] = useState('Choose who this file is for.');
  const [error, setError] = useState('');

  useEffect(() => {
    void getToken().then((token) => {
      if (!token) router.replace('/sign-in');
    });
    void api('/api/patients').then((data) => setPeople(Array.isArray(data) ? data : [])).catch((caught) => {
      setError(caught instanceof Error ? caught.message : 'Could not load people');
    });
  }, [router]);

  const saveFor = async (patientId: string) => {
    setError('');
    const files = shareIntent.files || [];
    if (!files.length) {
      setError('No file was shared.');
      return;
    }
    try {
      for (const file of files) {
        setStatus('Uploading…');
        const document = await uploadFile(file.path, file.fileName || 'shared', file.mimeType || 'application/octet-stream');
        const documentId = document.id || document._id;
        let ocrText = '';
        try {
          const ocr = await api('/api/ocr/process', { method: 'POST', body: JSON.stringify({ documentId }) });
          ocrText = typeof ocr.text === 'string' ? ocr.text : '';
        } catch {
          ocrText = '';
        }
        await api('/api/health-records', {
          method: 'POST',
          body: JSON.stringify({
            patientId,
            recordType: 'OTHER',
            data: {},
            documentId,
            ocrText,
            source: 'Share',
          }),
        });
      }
      resetShareIntent();
      setStatus('Saved.');
      router.replace('/home');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not save the shared file');
    }
  };

  if (!hasShareIntent) {
    return (
      <ScrollView contentContainerStyle={{ padding: 24 }}>
        <Text>Nothing is waiting to be filed. Open WhatsApp, Mail, or Files and share to SanoVault.</Text>
      </ScrollView>
    );
  }

  return (
    <ScrollView contentContainerStyle={{ padding: 24 }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>Who is this for?</Text>
      <Text style={{ marginTop: 8, color: '#4b5563' }}>{status}</Text>
      {people.map((person) => (
        <Pressable
          key={person.id}
          onPress={() => void saveFor(person.id)}
          style={{ marginTop: 12, backgroundColor: '#0175C2', minHeight: 52, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}
        >
          <Text style={{ color: '#fff', fontWeight: '600', fontSize: 16 }}>{`${person.firstName} ${person.lastName || ''}`.trim()}</Text>
        </Pressable>
      ))}
      {error ? <Text style={{ marginTop: 16, color: '#b91c1c' }}>{error}</Text> : null}
    </ScrollView>
  );
}
