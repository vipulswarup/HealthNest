import { Platform } from 'react-native';
import { api } from './api';

export type HealthReading = {
  systolic: number;
  diastolic: number;
  pulse?: number | null;
  recordedAt: string;
  externalId: string;
};

export async function syncHealthBidirectional(patientId: string, vaultOwned: Array<{
  systolic: number;
  diastolic: number;
  pulse: number | null;
  recordedAt: string;
  id: string;
}>) {
  try {
    if (Platform.OS === 'ios') {
      await syncHealthKit(patientId, vaultOwned);
      return;
    }
    if (Platform.OS === 'android') {
      await syncHealthConnect(patientId, vaultOwned);
    }
  } catch {
    // Health permissions or native modules are optional until a dev client is built.
  }
}

async function syncHealthKit(patientId: string, vaultOwned: Array<{
  systolic: number;
  diastolic: number;
  pulse: number | null;
  recordedAt: string;
  id: string;
}>) {
  const HK = await import('@kingstinct/react-native-healthkit');
  if (!HK.isHealthDataAvailable()) return;
  await HK.requestAuthorization({
    toRead: ['HKCorrelationTypeIdentifierBloodPressure', 'HKQuantityTypeIdentifierHeartRate'],
    toShare: ['HKCorrelationTypeIdentifierBloodPressure'],
  });

  const start = new Date();
  start.setDate(start.getDate() - 8);
  const samples = await HK.queryCorrelationSamples('HKCorrelationTypeIdentifierBloodPressure', {
    filter: { startDate: start, endDate: new Date() },
    limit: 50,
  });

  const inbound: HealthReading[] = [];
  for (const sample of samples) {
    const quantities = (sample as { objects?: Array<{ quantityType?: string; quantity?: { quantity?: number }; uuid?: string }> }).objects || [];
    const sys = quantities.find((q) => String(q.quantityType || '').includes('Systolic'));
    const dia = quantities.find((q) => String(q.quantityType || '').includes('Diastolic'));
    if (!sys?.quantity?.quantity || !dia?.quantity?.quantity) continue;
    inbound.push({
      systolic: Math.round(sys.quantity.quantity),
      diastolic: Math.round(dia.quantity.quantity),
      recordedAt: new Date((sample as { startDate?: string }).startDate || Date.now()).toISOString(),
      externalId: String((sample as { uuid?: string }).uuid || ''),
    });
  }

  if (inbound.length) {
    await api('/api/vitals/blood-pressure/sync', {
      method: 'POST',
      body: JSON.stringify({
        readings: inbound.filter((row) => row.externalId).map((row) => ({
          patientId,
          ...row,
          source: 'healthkit',
        })),
      }),
    });
  }

  for (const reading of vaultOwned) {
    const startDate = new Date(reading.recordedAt);
    await HK.saveCorrelationSample(
      'HKCorrelationTypeIdentifierBloodPressure',
      [
        { quantityType: 'HKQuantityTypeIdentifierBloodPressureSystolic', unit: 'mmHg', value: reading.systolic },
        { quantityType: 'HKQuantityTypeIdentifierBloodPressureDiastolic', unit: 'mmHg', value: reading.diastolic },
      ],
      startDate,
      startDate,
      { 'SanoVault.id': reading.id },
    ).catch(() => undefined);
  }
}

async function syncHealthConnect(patientId: string, vaultOwned: Array<{
  systolic: number;
  diastolic: number;
  pulse: number | null;
  recordedAt: string;
  id: string;
}>) {
  const HC = await import('react-native-health-connect');
  await HC.initialize();
  await HC.requestPermission([
    { accessType: 'read', recordType: 'BloodPressure' },
    { accessType: 'write', recordType: 'BloodPressure' },
  ]);
  const start = new Date();
  start.setDate(start.getDate() - 8);
  const result = await HC.readRecords('BloodPressure', {
    timeRangeFilter: { operator: 'between', startTime: start.toISOString(), endTime: new Date().toISOString() },
  });
  const records = (result as { records?: Array<{
    metadata?: { id?: string };
    time?: string;
    systolic?: { inMillimetersOfMercury?: number };
    diastolic?: { inMillimetersOfMercury?: number };
  }> }).records || [];

  const inbound = records.map((record) => ({
    patientId,
    source: 'health_connect' as const,
    systolic: Math.round(record.systolic?.inMillimetersOfMercury || 0),
    diastolic: Math.round(record.diastolic?.inMillimetersOfMercury || 0),
    recordedAt: record.time || new Date().toISOString(),
    externalId: String(record.metadata?.id || ''),
  })).filter((row) => row.systolic && row.diastolic && row.externalId);

  if (inbound.length) {
    await api('/api/vitals/blood-pressure/sync', {
      method: 'POST',
      body: JSON.stringify({ readings: inbound }),
    });
  }

  if (vaultOwned.length) {
    await HC.insertRecords(vaultOwned.map((reading) => ({
      recordType: 'BloodPressure',
      time: reading.recordedAt,
      systolic: { value: reading.systolic, unit: 'millimetersOfMercury' },
      diastolic: { value: reading.diastolic, unit: 'millimetersOfMercury' },
      metadata: { clientRecordId: reading.id },
    }))).catch(() => undefined);
  }
}
