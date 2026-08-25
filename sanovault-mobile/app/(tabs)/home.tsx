import { useFocusEffect, useRouter } from 'expo-router';
import { useCallback, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { api } from '../../lib/api';
import { registerPushAndReminders } from '../../lib/notifications';
import { clearToken } from '../../lib/session';

type Patient = { id: string; firstName: string; lastName?: string };
type RecordRow = { id: string; patientId: string; recordType: string; documentDate?: string; createdAt: string };

export default function Home() {
  const router = useRouter();
  const [people, setPeople] = useState<Patient[]>([]);
  const [records, setRecords] = useState<RecordRow[]>([]);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      setError('');
      await registerPushAndReminders();
      const [patientData, recordData] = await Promise.all([
        api('/api/patients'),
        api('/api/health-records'),
      ]);
      setPeople(Array.isArray(patientData) ? patientData : []);
      setRecords(Array.isArray(recordData) ? recordData : []);
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : 'Could not load home');
    }
  }, []);

  useFocusEffect(useCallback(() => { void load(); }, [load]));

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#f8fafc' }} contentContainerStyle={{ padding: 16, paddingBottom: 40 }}>
      <Text style={{ fontSize: 28, fontWeight: '700', color: '#111827' }}>Family</Text>
      <Text style={{ marginTop: 6, color: '#4b5563' }}>Choose a person, add a report, or open what a doctor needs.</Text>
      {error ? <Text style={{ marginTop: 12, color: '#b91c1c' }}>{error}</Text> : null}
      {people.map((person) => {
        const recent = records.filter((row) => row.patientId === person.id).slice(0, 3);
        const name = `${person.firstName} ${person.lastName || ''}`.trim();
        return (
          <View key={person.id} style={{ marginTop: 16, backgroundColor: '#fff', borderRadius: 16, padding: 16, borderWidth: 1, borderColor: '#e5e7eb' }}>
            <Text style={{ fontSize: 20, fontWeight: '600' }}>{name}</Text>
            <View style={{ flexDirection: 'row', gap: 8, marginTop: 12 }}>
              <Pressable onPress={() => router.push({ pathname: '/add', params: { patientId: person.id } })} style={btn}>
                <Text style={btnText}>Add report</Text>
              </Pressable>
              <Pressable onPress={() => router.push({ pathname: '/doctor', params: { patientId: person.id } })} style={btnSecondary}>
                <Text style={btnSecondaryText}>For the doctor</Text>
              </Pressable>
            </View>
            {recent.map((row) => (
              <Text key={row.id} style={{ marginTop: 8, color: '#6b7280' }}>{row.recordType} · {String(row.documentDate || row.createdAt).slice(0, 10)}</Text>
            ))}
          </View>
        );
      })}
      <Pressable
        onPress={() => { void clearToken().then(() => router.replace('/sign-in')); }}
        style={{ marginTop: 32, alignSelf: 'flex-start' }}
      >
        <Text style={{ color: '#9ca3af', fontSize: 13 }}>Sign out</Text>
      </Pressable>
    </ScrollView>
  );
}

const btn = { backgroundColor: '#0175C2', paddingVertical: 12, paddingHorizontal: 14, borderRadius: 10 };
const btnText = { color: '#fff', fontWeight: '600' as const };
const btnSecondary = { borderWidth: 1, borderColor: '#d1d5db', paddingVertical: 12, paddingHorizontal: 14, borderRadius: 10, backgroundColor: '#fff' };
const btnSecondaryText = { color: '#111827', fontWeight: '600' as const };
