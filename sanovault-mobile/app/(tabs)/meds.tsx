import { useEffect, useState } from 'react';
import { Pressable, ScrollView, Text, TextInput, View } from 'react-native';
import { api } from '../../lib/api';

type Patient = { id: string; firstName: string; lastName?: string };
type Medication = {
  id: string;
  originalBrandName: string;
  composition: { ingredients: Array<{ canonicalInn: string; strength: string; strengthUnit: string }>; requiresWarning: boolean };
};

export default function Meds() {
  const [people, setPeople] = useState<Patient[]>([]);
  const [patientId, setPatientId] = useState('');
  const [meds, setMeds] = useState<Medication[]>([]);
  const [brand, setBrand] = useState('');
  const [dosage, setDosage] = useState('');
  const [frequency, setFrequency] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    void api('/api/patients').then((data) => {
      const list = Array.isArray(data) ? data as Patient[] : [];
      setPeople(list);
      if (list[0]) setPatientId(list[0].id);
    }).catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load'));
  }, []);

  useEffect(() => {
    if (!patientId) return;
    void api(`/api/medications?patientId=${patientId}`)
      .then((data) => setMeds(Array.isArray(data) ? data : []))
      .catch((caught) => setError(caught instanceof Error ? caught.message : 'Could not load medicines'));
  }, [patientId]);

  const add = async () => {
    setError('');
    await api('/api/medications', {
      method: 'POST',
      body: JSON.stringify({
        patientId,
        name: brand,
        purchaseCountry: 'IN',
        dosage,
        frequency,
        route: 'Oral',
        startDate: new Date().toISOString().slice(0, 10),
        composition: { status: 'UNCONFIRMED', ingredients: [] },
      }),
    });
    setBrand('');
    setDosage('');
    setFrequency('');
    const data = await api(`/api/medications?patientId=${patientId}`);
    setMeds(Array.isArray(data) ? data : []);
  };

  return (
    <ScrollView style={{ flex: 1, backgroundColor: '#f8fafc' }} contentContainerStyle={{ padding: 16 }}>
      <Text style={{ fontSize: 24, fontWeight: '700' }}>Medicines</Text>
      {people.map((person) => (
        <Pressable key={person.id} onPress={() => setPatientId(person.id)} style={{ marginTop: 8 }}>
          <Text style={{ color: person.id === patientId ? '#0175C2' : '#111827' }}>{`${person.firstName} ${person.lastName || ''}`.trim()}</Text>
        </Pressable>
      ))}
      {meds.map((med) => (
        <View key={med.id} style={{ marginTop: 12, padding: 12, backgroundColor: '#fff', borderRadius: 12, borderWidth: 1, borderColor: med.composition.requiresWarning ? '#f59e0b' : '#e5e7eb' }}>
          <Text style={{ fontWeight: '600' }}>{med.originalBrandName}</Text>
        </View>
      ))}
      <Text style={{ marginTop: 20, fontWeight: '600' }}>Add (unconfirmed until you match the catalogue on the website)</Text>
      <TextInput value={brand} onChangeText={setBrand} placeholder="Brand name" style={input} />
      <TextInput value={dosage} onChangeText={setDosage} placeholder="Dose" style={input} />
      <TextInput value={frequency} onChangeText={setFrequency} placeholder="How often" style={input} />
      <Pressable onPress={() => void add()} style={{ marginTop: 16, backgroundColor: '#0175C2', minHeight: 48, borderRadius: 12, alignItems: 'center', justifyContent: 'center' }}>
        <Text style={{ color: '#fff', fontWeight: '600' }}>Save medicine</Text>
      </Pressable>
      {error ? <Text style={{ marginTop: 12, color: '#b91c1c' }}>{error}</Text> : null}
    </ScrollView>
  );
}

const input = { marginTop: 12, backgroundColor: '#fff', borderWidth: 1, borderColor: '#d1d5db', borderRadius: 10, padding: 12, fontSize: 16 };
