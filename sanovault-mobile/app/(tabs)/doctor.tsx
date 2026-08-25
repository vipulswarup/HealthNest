import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { api } from '../../lib/api';

type Packet = {
  patient: { firstName: string; lastName: string; age: number | null };
  medicines: Array<{ id: string; line: string }>;
  labHighlights: string[];
  bloodPressure: { lines: string[] };
  pleaseAsk: string;
};

type Patient = { id: string; firstName: string; lastName?: string };

export default function Doctor() {
  const params = useLocalSearchParams<{ patientId?: string }>();
  const [people, setPeople] = useState<Patient[]>([]);
  const [patientId, setPatientId] = useState(params.patientId || '');
  const [packet, setPacket] = useState<Packet | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    void api('/api/patients').then((data) => {
      const list = Array.isArray(data) ? data as Patient[] : [];
      setPeople(list);
      if (!patientId && list[0]) setPatientId(list[0].id);
    }).catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load'));
  }, [patientId]);

  useEffect(() => {
    if (!patientId) return;
    void api(`/api/reports/doctor-packet?patientId=${patientId}`)
      .then(setPacket)
      .catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load packet'));
  }, [patientId]);

  const share = async () => {
    if (!patientId) return;
    await api('/api/reports/doctor-packet', { method: 'POST', body: JSON.stringify({ patientId }) });
  };

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#f8fafc' }} contentContainerStyle={{ padding: 16 }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>For the doctor</Text>
      {people.map((person) => (
        <Pressable key={person.id} onPress={() => setPatientId(person.id)} style={{ marginTop: 8 }}>
          <Text style={{ color: person.id === patientId ? '#0175C2' : '#111827', fontSize: 16 }}>
            {`${person.firstName} ${person.lastName || ''}`.trim()}
          </Text>
        </Pressable>
      ))}
      {packet ? (
        <View style={{ marginTop: 16, backgroundColor: '#fff', padding: 16, borderRadius: 12 }}>
          <Text style={{ fontSize: 20, fontWeight: '700' }}>{packet.patient.firstName} {packet.patient.lastName}</Text>
          <Text style={{ marginTop: 12, fontWeight: '600' }}>Medicines</Text>
          {packet.medicines.map((row) => <Text key={row.id} style={{ marginTop: 4 }}>{row.line}</Text>)}
          <Text style={{ marginTop: 12, fontWeight: '600' }}>Labs</Text>
          {packet.labHighlights.map((line) => <Text key={line} style={{ marginTop: 4 }}>{line}</Text>)}
          <Text style={{ marginTop: 12, fontWeight: '600' }}>Blood pressure</Text>
          {packet.bloodPressure.lines.map((line) => <Text key={line} style={{ marginTop: 4 }}>{line}</Text>)}
          {packet.pleaseAsk ? <Text style={{ marginTop: 12 }}>Please ask: {packet.pleaseAsk}</Text> : null}
        </View>
      ) : null}
      <Pressable onPress={() => void share()} style={{ marginTop: 20, backgroundColor: '#0175C2', minHeight: 48, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: '#fff', fontWeight: '600' }}>Notify family this packet was shared</Text>
      </Pressable>
      {error ? <Text style={{ marginTop: 12, color: '#b91c1c' }}>{error}</Text> : null}
    </ScrollView>
  );
}
