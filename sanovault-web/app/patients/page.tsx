'use client';

import { useSession } from '@/lib/auth/client';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import AppNav from '@/components/layout/AppNav';

interface Patient {
  id: string;
  firstName: string;
  lastName?: string;
  dateOfBirth: string;
  gender: string;
  abhaNumber?: string;
  bloodGroup?: string;
}

export default function PatientsPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [patients, setPatients] = useState<Patient[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    if (status === 'loading') return;

    if (!session?.user?.id) {
      router.push('/auth/signin');
      return;
    }

    fetchPatients();
  }, [session?.user?.id, status, router]);

  const fetchPatients = async () => {
    try {
      setLoading(true);
      setError('');
      const response = await fetch('/api/patients');
      const data = await response.json();
      if (!response.ok) {
        if (data.code === 'NO_HOUSEHOLD') {
          setError('Ask a family member to add you to the family folder first.');
          setPatients([]);
          return;
        }
        throw new Error(data.error || 'Failed to fetch patients');
      }
      setPatients(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  if (status === 'loading' || loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#0175C2] mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    );
  }

  if (!session) {
    return null;
  }

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />

      <main className="max-w-7xl mx-auto py-8 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="rounded-xl border border-slate-200 bg-white p-8 shadow-sm">
            <div className="flex justify-between items-center mb-6">
              <h2 className="text-2xl font-bold text-gray-900">Family</h2>
              <Link
                href="/patients/new"
                className="min-h-12 px-4 py-2 bg-[#0175C2] text-white rounded-lg hover:bg-[#015a96] transition-colors text-base font-medium"
              >
                Add a person
              </Link>
            </div>

            {error && (
              <div className="mb-4 rounded-md bg-red-50 p-4">
                <div className="text-sm text-red-800">{error}</div>
                {error.includes('folder') && (
                  <Link href="/households" className="mt-2 inline-block text-sm font-medium text-[#0175C2] hover:underline">
                    Go to who can see this
                  </Link>
                )}
              </div>
            )}

            {patients.length === 0 ? (
              <div className="text-center py-12">
                <h3 className="text-lg font-semibold text-gray-900 mb-2">
                  Add Dad, your daughter, or anyone you keep reports for
                </h3>
                <p className="text-gray-600 mb-6">
                  You only need a name to start.
                </p>
                <Link
                  href="/patients/new"
                  className="inline-block min-h-12 px-6 py-3 bg-[#0175C2] text-white rounded-lg hover:bg-[#015a96] transition-colors font-medium"
                >
                  Add a person
                </Link>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {patients.map((patient) => (
                  <Link
                    key={patient.id}
                    href={`/patients/${patient.id}`}
                    className="cursor-pointer rounded-xl border border-slate-200 bg-white p-6 shadow-sm transition hover:border-blue-200 hover:shadow-md"
                  >
                    <div className="flex items-start justify-between mb-4">
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900">
                          {patient.firstName} {patient.lastName || ''}
                        </h3>
                        <p className="text-sm text-gray-600 mt-1">
                          {new Date(patient.dateOfBirth).toLocaleDateString()}
                        </p>
                      </div>
                      <div className="text-2xl">👤</div>
                    </div>
                    <div className="space-y-2 text-sm">
                      <div className="flex items-center text-gray-600">
                        <span className="font-medium mr-2">Gender:</span>
                        {patient.gender}
                      </div>
                      {patient.bloodGroup && (
                        <div className="flex items-center text-gray-600">
                          <span className="font-medium mr-2">Blood Group:</span>
                          {patient.bloodGroup}
                        </div>
                      )}
                      {patient.abhaNumber && (
                        <div className="flex items-center text-gray-600">
                          <span className="font-medium mr-2">ABHA:</span>
                          {patient.abhaNumber}
                        </div>
                      )}
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </div>
        </div>
      </main>
    </div>
  );
}
