import * as DocumentPicker from 'expo-document-picker';
import * as ImagePicker from 'expo-image-picker';
import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { api, uploadFile } from '../../lib/api';

type Patient = { id: string; firstName: string; lastName?: string };

export default function AddReport() {
  const params = useLocalSearchParams<{ patientId?: string }>();
  const [people, setPeople] = useState<Patient[]>([]);
  const [patientId, setPatientId] = useState(params.patientId || '');
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    void api('/api/patients').then((data) => {
      const list = Array.isArray(data) ? data as Patient[] : [];
      setPeople(list);
      if (!patientId && list[0]) setPatientId(list[0].id);
    }).catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load people'));
  }, [patientId]);

  const fileAndSave = async (uri: string, name: string, type: string) => {
    if (!patientId) throw new Error('Choose who this is for first');
    setStatus('Uploading…');
    const document = await uploadFile(uri, name, type);
    const documentId = document.id || document._id;
    setStatus('Reading the file…');
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
        source: 'Phone',
      }),
    });
    setStatus('Saved.');
  };

  const pickFile = async () => {
    setError('');
    const result = await DocumentPicker.getDocumentAsync({ type: ['application/pdf', 'image/*'], copyToCacheDirectory: true });
    if (result.canceled || !result.assets[0]) return;
    const asset = result.assets[0];
    try {
      await fileAndSave(asset.uri, asset.name, asset.mimeType || 'application/pdf');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not save');
      setStatus('');
    }
  };

  const takePhoto = async () => {
    setError('');
    const permission = await ImagePicker.requestCameraPermissionsAsync();
    if (!permission.granted) {
      setError('Allow camera access to photograph a report.');
      return;
    }
    const result = await ImagePicker.launchCameraAsync({ quality: 0.7 });
    if (result.canceled || !result.assets[0]) return;
    const asset = result.assets[0];
    try {
      await fileAndSave(asset.uri, asset.fileName || 'photo.jpg', asset.mimeType || 'image/jpeg');
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not save');
      setStatus('');
    }
  };

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#f8fafc' }} contentContainerStyle={{ padding: 16 }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>Who is this for?</Text>
      {people.map((person) => {
        const selected = person.id === patientId;
        return (
          <Pressable
            key={person.id}
            onPress={() => setPatientId(person.id)}
            style={{
              marginTop: 10,
              padding: 14,
              borderRadius: 12,
              borderWidth: 1,
              borderColor: selected ? '#0175C2' : '#e5e7eb',
              backgroundColor: selected ? '#eff6ff' : '#fff',
            }}
          >
            <Text style={{ fontSize: 17, fontWeight: '600' }}>{`${person.firstName} ${person.lastName || ''}`.trim()}</Text>
          </Pressable>
        );
      })}
      <Pressable onPress={() => void takePhoto()} style={{ marginTop: 24, backgroundColor: '#0175C2', minHeight: 52, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: '#fff', fontWeight: '600', fontSize: 16 }}>Take photo</Text>
      </Pressable>
      <Pressable onPress={() => void pickFile()} style={{ marginTop: 12, minHeight: 52, borderRadius: 12, alignItems: 'center', justifyContent: 'center', borderWidth: 1, borderColor: '#d1d5db', backgroundColor: '#fff' }}>
        <Text style={{ fontWeight: '600', fontSize: 16 }}>Choose from Files or WhatsApp</Text>
      </Pressable>
      {status ? <Text style={{ marginTop: 16, color: '#0175C2' }}>{status}</Text> : null}
      {error ? <Text style={{ marginTop: 16, color: '#b91c1c' }}>{error}</Text> : null}
    </ScrollView>
  );
}
