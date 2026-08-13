'use client';

import { useSession } from '@/lib/auth/client';
import { useRouter, useSearchParams } from 'next/navigation';
import { Suspense, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import AppNav from '@/components/layout/AppNav';
import ConfirmDialog from '@/components/ui/ConfirmDialog';
import { useToast } from '@/components/ui/ToastProvider';
import { HealthRecordCategory } from '@/lib/types/health-record-category.types';
import { HealthcareSource } from '@/lib/types/healthcare-source.types';

interface HealthRecord {
  id: string;
  patientId: string;
  recordType: string;
  source: string;
  doctorName?: string;
  documentDate?: string;
  createdAt: string;
  tags: string[];
  documentId?: string;
}

interface Patient {
  id: string;
  firstName: string;
  lastName?: string;
}

function HealthRecordsContent() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const searchParams = useSearchParams();
  const { notify } = useToast();
  const requestedPatientId = searchParams.get('patientId') || '';
  const [records, setRecords] = useState<HealthRecord[]>([]);
  const [patients, setPatients] = useState<Record<string, Patient>>({});
  const [categories, setCategories] = useState<HealthRecordCategory[]>([]);
  const [sources, setSources] = useState<HealthcareSource[]>([]);
  const [selectedPatientId, setSelectedPatientId] = useState<string>(requestedPatientId);
  const [loading, setLoading] = useState(true);
  const [recordsLoading, setRecordsLoading] = useState(false);
  const [error, setError] = useState('');
  
  // Search and filter state
  const [keyword, setKeyword] = useState(searchParams.get('keyword') || '');
  const [filterSource, setFilterSource] = useState(searchParams.get('source') || '');
  const [filterRecordType, setFilterRecordType] = useState(searchParams.get('recordType') || '');
  const [filterTag, setFilterTag] = useState(searchParams.get('tag') || '');
  const [startDate, setStartDate] = useState(searchParams.get('startDate') || '');
  const [endDate, setEndDate] = useState(searchParams.get('endDate') || '');
  const [showFilters, setShowFilters] = useState(
    ['source', 'recordType', 'tag', 'startDate', 'endDate'].some((key) => searchParams.has(key)),
  );
  const [recordPendingDelete, setRecordPendingDelete] = useState<string | null>(null);

  const updateQuery = useCallback((updates: Record<string, string>) => {
    const params = new URLSearchParams(window.location.search);
    Object.entries(updates).forEach(([key, value]) => {
      if (value) params.set(key, value);
      else params.delete(key);
    });
    const query = params.toString();
    router.replace(query ? `/health-records?${query}` : '/health-records', { scroll: false });
  }, [router]);

  const getRecordTypeLabel = (code: string): string => {
    const category = categories.find(cat => cat.code === code);
    return category?.displayName || code;
  };

  const fetchCategories = useCallback(async () => {
    try {
      const response = await fetch('/api/health-record-categories');
      if (response.ok) {
        const data = await response.json();
        setCategories(data);
      }
    } catch (err) {
      console.error('Failed to fetch categories:', err);
    }
  }, []);

  const fetchSources = useCallback(async () => {
    try {
      const response = await fetch('/api/healthcare-sources');
      if (response.ok) {
        const data = await response.json();
        setSources(data);
      }
    } catch (err) {
      console.error('Failed to fetch sources:', err);
    }
  }, []);

  useEffect(() => {
    const timeoutId = window.setTimeout(() => updateQuery({ keyword }), 300);
    return () => window.clearTimeout(timeoutId);
  }, [keyword, updateQuery]);

  const fetchPatients = useCallback(async () => {
    try {
      const response = await fetch('/api/patients');
      if (!response.ok) {
        throw new Error('Failed to fetch patients');
      }
      const data = await response.json();
      const patientsMap: Record<string, Patient> = {};
      data.forEach((p: Patient) => {
        patientsMap[p.id] = p;
      });
      setPatients(patientsMap);
      
      if (data.length > 0) {
        const nextPatientId = requestedPatientId && data.some((patient: Patient) => patient.id === requestedPatientId)
          ? requestedPatientId
          : data[0].id;
        setSelectedPatientId(nextPatientId);
        if (nextPatientId !== requestedPatientId) updateQuery({ patientId: nextPatientId });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  }, [requestedPatientId, updateQuery]);

  const fetchRecords = useCallback(async () => {
    try {
      setRecordsLoading(true);
      const params = new URLSearchParams();
      
      if (selectedPatientId) {
        params.append('patientId', selectedPatientId);
      }
      if (keyword) {
        params.append('keyword', keyword);
      }
      if (filterSource) {
        params.append('source', filterSource);
      }
      if (filterRecordType) {
        params.append('recordType', filterRecordType);
      }
      if (filterTag) {
        params.append('tag', filterTag);
      }
      if (startDate) {
        params.append('startDate', startDate);
      }
      if (endDate) {
        params.append('endDate', endDate);
      }

      const response = await fetch(`/api/health-records?${params.toString()}`);
      if (!response.ok) {
        throw new Error('Failed to fetch health records');
      }
      const data = await response.json();
      setRecords(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setRecordsLoading(false);
    }
  }, [endDate, filterRecordType, filterSource, filterTag, keyword, selectedPatientId, startDate]);

  useEffect(() => {
    if (status === 'loading') return;
    if (!session?.user?.id) {
      router.push('/auth/signin');
      return;
    }
    void fetchPatients();
    void fetchCategories();
    void fetchSources();
  }, [fetchCategories, fetchPatients, fetchSources, router, session?.user?.id, status]);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      void fetchRecords();
    }, keyword ? 300 : 0);
    return () => clearTimeout(timeoutId);
  }, [fetchRecords, keyword]);

  const handleDelete = async (id: string) => {
    try {
      const response = await fetch(`/api/health-records/${id}`, {
        method: 'DELETE',
      });

      if (!response.ok) {
        throw new Error('Failed to delete health record');
      }

      await fetchRecords();
      notify('Health record deleted.', 'success');
    } catch (err) {
      notify(err instanceof Error ? err.message : 'Failed to delete health record', 'error');
    } finally {
      setRecordPendingDelete(null);
    }
  };

  const handleTagClick = (tag: string) => {
    setFilterTag(tag);
    setShowFilters(true);
    updateQuery({ tag });
  };

  const clearFilters = () => {
    setKeyword('');
    setFilterSource('');
    setFilterRecordType('');
    setFilterTag('');
    setStartDate('');
    setEndDate('');
    updateQuery({ keyword: '', source: '', recordType: '', tag: '', startDate: '', endDate: '' });
  };

  const hasActiveFilters = keyword || filterSource || filterRecordType || filterTag || startDate || endDate;

  // Get all unique tags from records for filter dropdown
  const allTags = Array.from(new Set(records.flatMap(r => r.tags))).sort();

  if (status === 'loading' || (loading && Object.keys(patients).length === 0)) {
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

  const formatDate = (dateString: string) => {
    try {
      return new Date(dateString).toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
      });
    } catch {
      return dateString;
    }
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <AppNav />

      <main className="max-w-7xl mx-auto py-8 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0">
          <div className="flex justify-between items-center mb-6 gap-3 flex-wrap">
            <h1 className="text-3xl font-bold text-gray-900">Health Records</h1>
            <Link
              href={selectedPatientId ? `/reports/blood-summary?patientId=${selectedPatientId}` : '/reports/blood-summary'}
              className="text-sm text-[#0175C2] hover:underline"
            >
              Blood Summary
            </Link>
            {selectedPatientId && (
              <Link
                href={`/health-records/new?patientId=${selectedPatientId}`}
                className="bg-[#0175C2] hover:bg-[#015a96] text-white px-4 py-2 rounded-lg font-medium transition-colors"
              >
                + Add Record
              </Link>
            )}
          </div>

          {Object.keys(patients).length === 0 ? (
            <div className="rounded-xl border border-slate-200 bg-white p-12 text-center shadow-sm">
              <div className="text-6xl mb-4">👥</div>
              <h3 className="text-xl font-semibold text-gray-900 mb-2">
                No patients found
              </h3>
              <p className="text-gray-600 mb-6">
                You need to add a patient first before creating health records.
              </p>
              <Link
                href="/patients/new"
                className="inline-block bg-[#0175C2] hover:bg-[#015a96] text-white px-6 py-3 rounded-lg font-medium transition-colors"
              >
                Add Patient
              </Link>
            </div>
          ) : (
            <>
              <div className="bg-white rounded-xl shadow-md p-6 mb-6">
                <div className="mb-4">
                  <label htmlFor="patient" className="block text-sm font-medium text-gray-700 mb-2">
                    Patient
                  </label>
                  <select
                    id="patient"
                    value={selectedPatientId}
                    onChange={(e) => {
                      setSelectedPatientId(e.target.value);
                      updateQuery({ patientId: e.target.value });
                    }}
                    className="w-full md:w-64 px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                  >
                    <option value="">All Patients</option>
                    {Object.values(patients).map((patient) => (
                      <option key={patient.id} value={patient.id}>
                        {patient.firstName} {patient.lastName || ''}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="mb-4">
                  <div className="flex items-center gap-2">
                    <div className="flex-1 relative">
                      <input
                        type="text"
                        placeholder="Search records..."
                        value={keyword}
                        onChange={(e) => setKeyword(e.target.value)}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                      />
                      {recordsLoading && (
                        <div className="absolute right-3 top-1/2 transform -translate-y-1/2">
                          <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-[#0175C2]"></div>
                        </div>
                      )}
                    </div>
                    <button
                      onClick={() => setShowFilters(!showFilters)}
                      className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                        showFilters || hasActiveFilters
                          ? 'bg-[#0175C2] text-white'
                          : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                      }`}
                    >
                      Filters {hasActiveFilters && `(${[keyword, filterSource, filterRecordType, filterTag, startDate, endDate].filter(Boolean).length})`}
                    </button>
                    {hasActiveFilters && (
                      <button
                        onClick={clearFilters}
                        className="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg font-medium transition-colors"
                      >
                        Clear
                      </button>
                    )}
                  </div>
                </div>

                {showFilters && (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 pt-4 border-t border-gray-200">
                    <div>
                      <label htmlFor="filterSource" className="block text-sm font-medium text-gray-700 mb-2">
                        Source
                      </label>
                      <select
                        id="filterSource"
                        value={filterSource}
                        onChange={(e) => {
                          setFilterSource(e.target.value);
                          updateQuery({ source: e.target.value });
                        }}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                      >
                        <option value="">All Sources</option>
                        {sources.map((source) => (
                          <option key={source.id || source._id} value={source.preferredName}>
                            {source.preferredName}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label htmlFor="filterRecordType" className="block text-sm font-medium text-gray-700 mb-2">
                        Record Type
                      </label>
                      <select
                        id="filterRecordType"
                        value={filterRecordType}
                        onChange={(e) => {
                          setFilterRecordType(e.target.value);
                          updateQuery({ recordType: e.target.value });
                        }}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                      >
                        <option value="">All Types</option>
                        {categories.map((category) => (
                          <option key={category.code} value={category.code}>
                            {category.displayName}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label htmlFor="filterTag" className="block text-sm font-medium text-gray-700 mb-2">
                        Tag
                      </label>
                      <select
                        id="filterTag"
                        value={filterTag}
                        onChange={(e) => {
                          setFilterTag(e.target.value);
                          updateQuery({ tag: e.target.value });
                        }}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                      >
                        <option value="">All Tags</option>
                        {allTags.map((tag) => (
                          <option key={tag} value={tag}>
                            {tag}
                          </option>
                        ))}
                      </select>
                    </div>

                    <div>
                      <label htmlFor="startDate" className="block text-sm font-medium text-gray-700 mb-2">
                        Start Date
                      </label>
                      <input
                        type="date"
                        id="startDate"
                        value={startDate}
                        onChange={(e) => {
                          setStartDate(e.target.value);
                          updateQuery({ startDate: e.target.value });
                        }}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                      />
                    </div>

                    <div>
                      <label htmlFor="endDate" className="block text-sm font-medium text-gray-700 mb-2">
                        End Date
                      </label>
                      <input
                        type="date"
                        id="endDate"
                        value={endDate}
                        onChange={(e) => {
                          setEndDate(e.target.value);
                          updateQuery({ endDate: e.target.value });
                        }}
                        className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
                      />
                    </div>
                  </div>
                )}

                {hasActiveFilters && (
                  <div className="mt-4 pt-4 border-t border-gray-200">
                    <div className="flex flex-wrap gap-2">
                      {keyword && (
                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-blue-100 text-blue-800">
                          Keyword: {keyword}
                          <button
                            onClick={() => {
                              setKeyword('');
                              updateQuery({ keyword: '' });
                            }}
                            aria-label="Remove keyword filter"
                            className="ml-2 hover:text-blue-600"
                          >
                            ×
                          </button>
                        </span>
                      )}
                      {filterSource && (
                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-green-100 text-green-800">
                          Source: {filterSource}
                          <button
                            onClick={() => {
                              setFilterSource('');
                              updateQuery({ source: '' });
                            }}
                            aria-label="Remove source filter"
                            className="ml-2 hover:text-green-600"
                          >
                            ×
                          </button>
                        </span>
                      )}
                      {filterRecordType && (
                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-purple-100 text-purple-800">
                          Type: {getRecordTypeLabel(filterRecordType)}
                          <button
                            onClick={() => {
                              setFilterRecordType('');
                              updateQuery({ recordType: '' });
                            }}
                            aria-label="Remove record type filter"
                            className="ml-2 hover:text-purple-600"
                          >
                            ×
                          </button>
                        </span>
                      )}
                      {filterTag && (
                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-yellow-100 text-yellow-800">
                          Tag: {filterTag}
                          <button
                            onClick={() => {
                              setFilterTag('');
                              updateQuery({ tag: '' });
                            }}
                            aria-label="Remove tag filter"
                            className="ml-2 hover:text-yellow-600"
                          >
                            ×
                          </button>
                        </span>
                      )}
                      {startDate && (
                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-gray-100 text-gray-800">
                          From: {startDate}
                          <button
                            onClick={() => {
                              setStartDate('');
                              updateQuery({ startDate: '' });
                            }}
                            aria-label="Remove start date filter"
                            className="ml-2 hover:text-gray-600"
                          >
                            ×
                          </button>
                        </span>
                      )}
                      {endDate && (
                        <span className="inline-flex items-center px-3 py-1 rounded-full text-sm bg-gray-100 text-gray-800">
                          To: {endDate}
                          <button
                            onClick={() => {
                              setEndDate('');
                              updateQuery({ endDate: '' });
                            }}
                            aria-label="Remove end date filter"
                            className="ml-2 hover:text-gray-600"
                          >
                            ×
                          </button>
                        </span>
                      )}
                    </div>
                  </div>
                )}
              </div>

              {error && (
                <div className="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg mb-4">
                  {error}
                </div>
              )}

              {records.length === 0 ? (
                <div className="rounded-xl border border-slate-200 bg-white p-12 text-center shadow-sm">
                  <div className="text-6xl mb-4">📋</div>
                  <h3 className="text-xl font-semibold text-gray-900 mb-2">
                    {hasActiveFilters ? 'No records match your filters' : 'No health records yet'}
                  </h3>
                  <p className="text-gray-600 mb-6">
                    {hasActiveFilters 
                      ? 'Try adjusting your search criteria or clear filters to see all records.'
                      : 'Start by adding a health record.'}
                  </p>
                  {selectedPatientId && !hasActiveFilters && (
                    <Link
                      href={`/health-records/new?patientId=${selectedPatientId}`}
                      className="inline-block bg-[#0175C2] hover:bg-[#015a96] text-white px-6 py-3 rounded-lg font-medium transition-colors"
                    >
                      Add Health Record
                    </Link>
                  )}
                  {hasActiveFilters && (
                    <button
                      onClick={clearFilters}
                      className="inline-block bg-gray-100 hover:bg-gray-200 text-gray-700 px-6 py-3 rounded-lg font-medium transition-colors"
                    >
                      Clear Filters
                    </button>
                  )}
                </div>
              ) : (
                <div className="space-y-4">
                  <div className="text-sm text-gray-600 mb-2">
                    Found {records.length} record{records.length !== 1 ? 's' : ''}
                  </div>
                  {records.map((record) => (
                    <div
                      key={record.id}
                      className="bg-white rounded-xl shadow-md hover:shadow-lg transition-shadow p-6"
                    >
                      <div className="flex justify-between items-start">
                        <div className="flex-1">
                          <div className="flex items-center space-x-3 mb-2">
                            <h3 className="text-lg font-semibold text-gray-900">
                              {getRecordTypeLabel(record.recordType)}
                            </h3>
                            {record.documentId && (
                              <span className="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                                Has Document
                              </span>
                            )}
                          </div>
                          <p className="text-sm text-gray-600 mb-2">
                            Source: {record.source}
                            {record.doctorName && (
                              <span className="ml-2">• {record.doctorName}</span>
                            )}
                          </p>
                          <p className="text-sm text-gray-500 mb-2">
                            {record.documentDate ? (
                              <>
                                Document Date: {formatDate(record.documentDate)}
                                <span className="ml-2">• Created: {formatDate(record.createdAt)}</span>
                              </>
                            ) : (
                              formatDate(record.createdAt)
                            )}
                            {patients[record.patientId] && (
                              <span className="ml-2">
                                • {patients[record.patientId].firstName} {patients[record.patientId].lastName || ''}
                              </span>
                            )}
                          </p>
                          {record.tags.length > 0 && (
                            <div className="flex flex-wrap gap-2 mt-3">
                              {record.tags.map((tag, idx) => (
                                <button
                                  key={idx}
                                  onClick={() => handleTagClick(tag)}
                                  className="text-xs bg-gray-100 hover:bg-[#0175C2] hover:text-white text-gray-700 px-2 py-1 rounded transition-colors cursor-pointer"
                                >
                                  {tag}
                                </button>
                              ))}
                            </div>
                          )}
                        </div>
                        <div className="flex space-x-2 ml-4">
                          <Link
                            href={`/health-records/${record.id}`}
                            className="bg-blue-50 hover:bg-blue-100 text-[#0175C2] px-4 py-2 rounded-lg font-medium transition-colors text-sm"
                          >
                            View
                          </Link>
                          <button
                            onClick={() => setRecordPendingDelete(record.id)}
                            className="bg-red-50 hover:bg-red-100 text-red-600 px-4 py-2 rounded-lg font-medium transition-colors text-sm"
                          >
                            Delete
                          </button>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>
      </main>
      <ConfirmDialog
        open={Boolean(recordPendingDelete)}
        title="Delete this health record?"
        description="This permanently removes the record and its extracted health information. The action cannot be undone."
        confirmLabel="Delete record"
        onCancel={() => setRecordPendingDelete(null)}
        onConfirm={() => {
          if (recordPendingDelete) void handleDelete(recordPendingDelete);
        }}
      />
    </div>
  );
}

export default function HealthRecordsPage() {
  return (
    <Suspense fallback={<div className="min-h-screen grid place-items-center text-gray-600" role="status">Loading health records…</div>}>
      <HealthRecordsContent />
    </Suspense>
  );
}
