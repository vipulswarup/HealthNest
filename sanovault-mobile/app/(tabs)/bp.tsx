import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { api } from '../../lib/api';
import { syncHealthBidirectional } from '../../lib/health';

type Patient = { id: string; firstName: string; lastName?: string };
type Week = {
  readings: Array<{ id: string; systolic: number; diastolic: number; pulse: number | null; recordedAt: string; vaultOwned?: boolean }>;
  lines: string[];
};

export default function BloodPressure() {
  const [people, setPeople] = useState<Patient[]>([]);
  const [patientId, setPatientId] = useState('');
  const [systolic, setSystolic] = useState('');
  const [diastolic, setDiastolic] = useState('');
  const [pulse, setPulse] = useState('');
  const [week, setWeek] = useState<Week | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    void api('/api/patients').then((data) => {
      const list = Array.isArray(data) ? data as Patient[] : [];
      setPeople(list);
      if (list[0]) setPatientId(list[0].id);
    }).catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load'));
  }, []);

  const load = async (id: string) => {
    const data = await api(`/api/vitals/blood-pressure?patientId=${id}`);
    setWeek(data);
    const owned = (data.readings || []).filter((row: { vaultOwned?: boolean }) => row.vaultOwned !== false);
    await syncHealthBidirectional(id, owned).catch(() => undefined);
  };

  useEffect(() => {
    if (patientId) void load(patientId).catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load BP'));
  }, [patientId]);

  const save = async () => {
    setError('');
    await api('/api/vitals/blood-pressure', {
      method: 'POST',
      body: JSON.stringify({
        patientId,
        systolic: Number(systolic),
        diastolic: Number(diastolic),
        pulse: pulse ? Number(pulse) : null,
      }),
    });
    setSystolic('');
    setDiastolic('');
    setPulse('');
    await load(patientId);
  };

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#f8fafc' }} contentContainerStyle={{ padding: 16 }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>Blood pressure</Text>
      {people.map((person) => (
        <Pressable key={person.id} onPress={() => setPatientId(person.id)} style={{ marginTop: 8 }}>
          <Text style={{ color: person.id === patientId ? '#0175C2' : '#111827' }}>{`${person.firstName} ${person.lastName || ''}`.trim()}</Text>
        </Pressable>
      ))}
      <TextInput value={systolic} onChangeText={setSystolic} keyboardType="number-pad" placeholder="Systolic" style={input} />
      <TextInput value={diastolic} onChangeText={setDiastolic} keyboardType="number-pad" placeholder="Diastolic" style={input} />
      <TextInput value={pulse} onChangeText={setPulse} keyboardType="number-pad" placeholder="Pulse (optional)" style={input} />
      <Pressable onPress={() => void save()} style={{ marginTop: 16, backgroundColor: '#0175C2', minHeight: 48, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: '#fff', fontWeight: '600' }}>Save</Text>
      </Pressable>
      <Text style={{ marginTop: 20, fontWeight: '600' }}>Last week</Text>
      {(week?.lines || []).map((line) => <Text key={line} style={{ marginTop: 6 }}>{line}</Text>)}
      {error ? <Text style={{ marginTop: 12, color: '#b91c1c' }}>{error}</Text> : null}
    </ScrollView>
  );
}

const input = { marginTop: 12, backgroundColor: '#fff', borderWidth: 1, borderColor: '#d1d5db', borderRadius: 10, padding: 12, fontSize: 16 };
