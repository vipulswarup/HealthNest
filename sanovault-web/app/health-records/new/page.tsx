'use client';

import { useSession } from '@/lib/auth/client';
import { useRouter, useSearchParams } from 'next/navigation';
import { useState, useEffect, Suspense } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { DEFAULT_TAGS } from '@/lib/constants/tags';
import { DocumentUploader } from '@/components/documents/DocumentUploader';
import { OCRProgress } from '@/components/documents/OCRProgress';
import { HealthRecordCategory } from '@/lib/types/health-record-category.types';
import { HealthcareSource } from '@/lib/types/healthcare-source.types';
import { Doctor } from '@/lib/types/doctor.types';

function NewHealthRecordContent() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const searchParams = useSearchParams();
  const patientId = searchParams.get('patientId') || '';

  const [currentStep, setCurrentStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [patients, setPatients] = useState<Array<{ id: string; firstName: string; lastName?: string }>>([]);
  const [categories, setCategories] = useState<HealthRecordCategory[]>([]);
  const [sources, setSources] = useState<HealthcareSource[]>([]);
  const [sourcesLoading, setSourcesLoading] = useState(true);
  const [sourceInput, setSourceInput] = useState('');
  const [showSourceDropdown, setShowSourceDropdown] = useState(false);
  const [doctors, setDoctors] = useState<Doctor[]>([]);
  const [doctorsLoading, setDoctorsLoading] = useState(true);
  const [doctorInput, setDoctorInput] = useState('');
  const [showDoctorDropdown, setShowDoctorDropdown] = useState(false);
  const [uploadedDocument, setUploadedDocument] = useState<{ id: string; fileName: string } | null>(null);
  const [fileQueue, setFileQueue] = useState<Array<{
    localId: string;
    file: File;
    fileName: string;
    documentId?: string;
    status: 'queued' | 'uploading' | 'processing' | 'review' | 'saved' | 'failed';
    error?: string;
  }>>([]);
  const [currentQueueIndex, setCurrentQueueIndex] = useState(0);
  const [documentPreviewUrl, setDocumentPreviewUrl] = useState<string | null>(null);
  const [savedCount, setSavedCount] = useState(0);
  
  // Processing states
  const [ocrStatus, setOcrStatus] = useState<'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED'>('PENDING');
  const [aiStatus, setAiStatus] = useState<'PENDING' | 'PROCESSING' | 'COMPLETED' | 'FAILED'>('PENDING');
  
  // AI extraction results
  const [aiResults, setAiResults] = useState<{
    classification?: string;
    source?: string;
    doctorName?: string;
    documentDate?: string;
    tags?: string[];
  } | null>(null);

  const [formData, setFormData] = useState({
    patientId: patientId,
    recordType: '',
    source: '',
    doctorName: '',
    documentDate: '',
    tags: [] as string[],
    data: {} as Record<string, any>,
  });

  // Sync sourceInput with formData.source when it changes externally
  useEffect(() => {
    if (formData.source && formData.source !== sourceInput) {
      setSourceInput(formData.source);
    }
  }, [formData.source]);

  // Sync doctorInput with formData.doctorName when it changes externally
  useEffect(() => {
    if (formData.doctorName && formData.doctorName !== doctorInput) {
      setDoctorInput(formData.doctorName);
    }
  }, [formData.doctorName]);

  useEffect(() => {
    if (status === 'loading') return;

    if (!session) {
      router.push('/auth/signin');
      return;
    }

    fetchPatients();
    fetchCategories();
    fetchSources();
    fetchDoctors();
  }, [session?.user?.id, status, router]);

  const fetchPatients = async () => {
    try {
      const response = await fetch('/api/patients');
      if (!response.ok) {
        throw new Error('Failed to fetch patients');
      }
      const data = await response.json();
      setPatients(data);

      if (patientId && !formData.patientId) {
        setFormData({ ...formData, patientId });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    }
  };

  const fetchCategories = async () => {
    try {
      const response = await fetch('/api/health-record-categories');
      if (!response.ok) {
        const errorText = await response.text();
        console.error('Failed to fetch categories:', response.status, errorText);
        throw new Error(`Failed to fetch categories: ${response.status}`);
      }
      const data = await response.json();
      console.log('Fetched categories:', data.length, 'categories');
      if (data.length === 0) {
        console.warn('No categories found. Make sure to run: tsx scripts/init-health-record-categories.ts');
        setError('No record types found. Please initialize the database by running: tsx scripts/init-health-record-categories.ts');
      }
      setCategories(data);
      // Set default record type to first category if none selected
      if (!formData.recordType && data.length > 0) {
        setFormData(prev => ({ ...prev, recordType: data[0].code }));
      }
    } catch (err) {
      console.error('Failed to fetch categories:', err);
      setError('Failed to load record types. Please check the console for details and ensure the database is initialized.');
    }
  };

  const fetchSources = async () => {
    try {
      setSourcesLoading(true);
      const response = await fetch('/api/healthcare-sources');
      if (!response.ok) {
        throw new Error('Failed to fetch sources');
      }
      const data = await response.json();
      console.log('Fetched sources:', data.length);
      setSources(data);
    } catch (err) {
      console.error('Failed to fetch sources:', err);
      setError('Failed to load healthcare sources. Please refresh the page.');
    } finally {
      setSourcesLoading(false);
    }
  };

  const fetchDoctors = async () => {
    try {
      setDoctorsLoading(true);
      const response = await fetch('/api/doctors');
      if (!response.ok) {
        throw new Error('Failed to fetch doctors');
      }
      const data = await response.json();
      console.log('Fetched doctors:', data.length);
      setDoctors(data);
    } catch (err) {
      console.error('Failed to fetch doctors:', err);
    } finally {
      setDoctorsLoading(false);
    }
  };

  const handleSourceChange = (value: string) => {
    setSourceInput(value);
    if (!sourcesLoading && sources.length > 0) {
      setShowSourceDropdown(true);
    }
    setFormData(prev => ({ ...prev, source: value }));
  };

  const handleSourceSelect = (source: HealthcareSource) => {
    setSourceInput(source.preferredName);
    setShowSourceDropdown(false);
    setFormData(prev => ({ ...prev, source: source.preferredName }));
  };

  const handleSourceBlur = async () => {
    // Small delay to allow click events to fire first
    setTimeout(() => {
      setShowSourceDropdown(false);
      
      // If source doesn't match any existing source, save it
      if (sourceInput.trim() && !sources.some(s => s.preferredName.toLowerCase() === sourceInput.toLowerCase())) {
        fetch('/api/healthcare-sources', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: sourceInput.trim() }),
        })
          .then(res => res.json())
          .then(newSource => {
            if (newSource.preferredName) {
              setSources(prev => [...prev, newSource].sort((a, b) => 
                a.preferredName.localeCompare(b.preferredName)
              ));
            }
          })
          .catch(err => console.error('Failed to save new source:', err));
      }
    }, 200);
  };

  const filteredSources = sourceInput.trim() === ''
    ? sources
    : sources.filter(source =>
        source.preferredName.toLowerCase().includes(sourceInput.toLowerCase()) ||
        source.aliases.some(alias => alias.toLowerCase().includes(sourceInput.toLowerCase()))
      );

  const handleDoctorChange = (value: string) => {
    setDoctorInput(value);
    if (!doctorsLoading && doctors.length > 0) {
      setShowDoctorDropdown(true);
    }
    setFormData(prev => ({ ...prev, doctorName: value }));
  };

  const handleDoctorSelect = (doctor: Doctor) => {
    setDoctorInput(doctor.preferredName);
    setShowDoctorDropdown(false);
    setFormData(prev => ({ ...prev, doctorName: doctor.preferredName }));
  };

  const handleDoctorBlur = async () => {
    setTimeout(() => {
      setShowDoctorDropdown(false);
      
      if (doctorInput.trim() && !doctors.some(d => d.preferredName.toLowerCase() === doctorInput.toLowerCase())) {
        fetch('/api/doctors', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: doctorInput.trim() }),
        })
          .then(res => res.json())
          .then(newDoctor => {
            if (newDoctor.preferredName) {
              setDoctors(prev => [...prev, newDoctor].sort((a, b) => 
                a.preferredName.localeCompare(b.preferredName)
              ));
            }
          })
          .catch(err => console.error('Failed to save new doctor:', err));
      }
    }, 200);
  };

  const filteredDoctors = doctorInput.trim() === ''
    ? doctors
    : doctors.filter(doctor =>
        doctor.preferredName.toLowerCase().includes(doctorInput.toLowerCase()) ||
        doctor.aliases.some(alias => alias.toLowerCase().includes(doctorInput.toLowerCase()))
      );

  const handleTagToggle = (tag: string) => {
    setFormData({
      ...formData,
      tags: formData.tags.includes(tag)
        ? formData.tags.filter((t) => t !== tag)
        : [...formData.tags, tag],
    });
  };

  const clearPreviewUrl = () => {
    setDocumentPreviewUrl((prev) => {
      if (prev?.startsWith('blob:')) URL.revokeObjectURL(prev);
      return null;
    });
  };

  const resetExtractionState = () => {
    setUploadedDocument(null);
    clearPreviewUrl();
    setOcrStatus('PENDING');
    setAiStatus('PENDING');
    setAiResults(null);
    setSourceInput('');
    setDoctorInput('');
    setFormData((prev) => ({
      ...prev,
      recordType: categories[0]?.code || prev.recordType,
      source: '',
      doctorName: '',
      documentDate: '',
      tags: [],
      data: {},
    }));
  };

  const loadDocumentPreview = async (documentId: string, localFile?: File) => {
    if (localFile) {
      const blobUrl = URL.createObjectURL(localFile);
      setDocumentPreviewUrl((prev) => {
        if (prev?.startsWith('blob:')) URL.revokeObjectURL(prev);
        return blobUrl;
      });
    }
    try {
      const response = await fetch('/api/documents/view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ documentId }),
      });
      if (!response.ok) return;
      const data = await response.json();
      if (data.url) {
        setDocumentPreviewUrl((prev) => {
          if (prev?.startsWith('blob:')) URL.revokeObjectURL(prev);
          return data.url;
        });
      }
    } catch {
      // Local blob preview is enough to continue review.
    }
  };

  const updateQueueItem = (localId: string, patch: Partial<(typeof fileQueue)[number]>) => {
    setFileQueue((prev) => prev.map((item) => (item.localId === localId ? { ...item, ...patch } : item)));
  };

  const processQueueItem = async (index: number, items = fileQueue) => {
    const item = items[index];
    if (!item) return;

    setCurrentQueueIndex(index);
    setCurrentStep(1);
    resetExtractionState();
    setError('');

    try {
      updateQueueItem(item.localId, { status: 'uploading', error: undefined });
      const formPayload = new FormData();
      formPayload.append('file', item.file);
      const uploadRes = await fetch('/api/documents/upload', {
        method: 'POST',
        body: formPayload,
      });
      const uploadData = await uploadRes.json().catch(() => ({}));
      if (!uploadRes.ok) {
        throw new Error(uploadData.error || uploadData.message || 'Upload failed');
      }

      const documentId = uploadData.id as string;
      const fileName = uploadData.fileName || item.fileName;
      setUploadedDocument({ id: documentId, fileName });
      updateQueueItem(item.localId, { status: 'processing', documentId, fileName });
      await loadDocumentPreview(documentId, item.file);
      await processDocument(documentId);
      updateQueueItem(item.localId, { status: 'review' });
      setCurrentStep(2);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to process document';
      updateQueueItem(item.localId, { status: 'failed', error: message });
      setError(message);
    }
  };

  const handleFilesSelected = (files: File[]) => {
    const items = files.map((file) => ({
      localId: `${file.name}-${file.size}-${file.lastModified}-${Math.random().toString(36).slice(2, 8)}`,
      file,
      fileName: file.name,
      status: 'queued' as const,
    }));
    setFileQueue(items);
    setSavedCount(0);
    void processQueueItem(0, items);
  };

  const advanceQueueOrExit = async (fromIndex: number) => {
    const nextIndex = fromIndex + 1;
    if (fileQueue.length > 0 && nextIndex < fileQueue.length) {
      await processQueueItem(nextIndex);
      return;
    }
    if (formData.patientId) {
      router.push(`/health-records?patientId=${formData.patientId}`);
    } else {
      router.push('/health-records');
    }
  };

  const handleSkipCurrent = () => {
    void advanceQueueOrExit(currentQueueIndex);
  };

  const handleRetryCurrent = () => {
    void processQueueItem(currentQueueIndex);
  };

  const processDocument = async (documentId: string) => {
    try {
      // 1. Trigger OCR
      setOcrStatus('PROCESSING');
      const ocrRes = await fetch('/api/ocr/process', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ documentId }),
      });
      
      if (!ocrRes.ok) {
        setOcrStatus('FAILED');
        throw new Error('OCR failed');
      }
      
      setOcrStatus('COMPLETED');

      // 2. Trigger AI Analysis
      setAiStatus('PROCESSING');
      const analyzeRes = await fetch('/api/ai/analyze', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ documentId }),
      });

      if (analyzeRes.ok) {
        const analyzeData = await analyzeRes.json();
        setAiResults(analyzeData);
        setAiStatus('COMPLETED');
        
        // Auto-populate form data
        // Match AI classification to dropdown categories (exact displayName, then tag hints)
        let matchedCategory = (analyzeData.classification && categories.length > 0)
          ? categories.find(cat => cat.displayName.toLowerCase() === String(analyzeData.classification).toLowerCase())
          : undefined;
        if (!matchedCategory && categories.length > 0) {
          const tagBlob = (analyzeData.tags || []).join(' ').toLowerCase();
          if (/(lab|blood|cbc|haemat|hemat|diagnostic|patholog|urine)/.test(tagBlob)) {
            matchedCategory = categories.find(cat => cat.code === 'LAB_REPORT');
          } else if (/(imaging|radiolog|xray|mri|ct_scan|ultrasound)/.test(tagBlob)) {
            matchedCategory = categories.find(cat => cat.code === 'IMAGING_REPORT');
          } else if (/(prescription|medication)/.test(tagBlob)) {
            matchedCategory = categories.find(cat => cat.code === 'PRESCRIPTION');
          }
        }
        
        // Use all tags returned by AI
        const allTags = analyzeData.tags && Array.isArray(analyzeData.tags) ? analyzeData.tags : [];
        // Normalize and deduplicate tags
        const normalizedTags = allTags
          .map((tag: any) => String(tag).toLowerCase().trim().replace(/\s+/g, '_'))
          .filter((tag: string, index: number, arr: string[]) => tag && arr.indexOf(tag) === index); // Remove empty and duplicates
        
        console.log('AI Tags:', allTags);
        console.log('Normalized Tags:', normalizedTags);
        
        // Match source name if provided
        let matchedSource = analyzeData.source || '';
        if (analyzeData.source) {
          try {
            const matchRes = await fetch('/api/healthcare-sources/match', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ name: analyzeData.source }),
            });
            if (matchRes.ok) {
              const matchData = await matchRes.json();
              matchedSource = matchData.matched;
              // Update sourceInput to show the matched preferred name
              setSourceInput(matchedSource);
            } else {
              // If no match, use the AI-provided name and it will be saved on blur
              matchedSource = analyzeData.source;
              setSourceInput(matchedSource);
            }
          } catch (err) {
            console.error('Failed to match source:', err);
            matchedSource = analyzeData.source;
            setSourceInput(matchedSource);
          }
        }
        
        // Match doctor name if provided
        let matchedDoctorName = analyzeData.doctorName || '';
        if (analyzeData.doctorName) {
          try {
            const matchRes = await fetch('/api/doctors/match', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ name: analyzeData.doctorName }),
            });
            if (matchRes.ok) {
              const matchData = await matchRes.json();
              matchedDoctorName = matchData.matched;
              setDoctorInput(matchedDoctorName);
            } else {
              matchedDoctorName = analyzeData.doctorName;
              setDoctorInput(matchedDoctorName);
            }
          } catch (err) {
            console.error('Failed to match doctor:', err);
            matchedDoctorName = analyzeData.doctorName;
            setDoctorInput(matchedDoctorName);
          }
        }
        
        setFormData(prev => ({
          ...prev,
          recordType: matchedCategory?.code || prev.recordType,
          source: matchedSource,
          doctorName: matchedDoctorName,
          documentDate: analyzeData.documentDate || prev.documentDate,
          // Use all AI-suggested tags
          tags: normalizedTags.length > 0 ? normalizedTags : prev.tags,
        }));
      } else {
        setAiStatus('FAILED');
      }
    } catch (error) {
      console.error('Processing failed:', error);
      if (ocrStatus === 'PROCESSING') setOcrStatus('FAILED');
      if (aiStatus === 'PROCESSING') setAiStatus('FAILED');
    }
  };

  const handleNext = () => {
    if (ocrStatus === 'COMPLETED' || aiStatus === 'COMPLETED' || ocrStatus === 'FAILED' || aiStatus === 'FAILED') {
      setCurrentStep(2);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    if (!formData.patientId) {
      setError('Please select a patient');
      setLoading(false);
      return;
    }

    // Ensure source is saved if it's new
    let finalSource = formData.source;
    if (formData.source && !sources.some(s => s.preferredName.toLowerCase() === formData.source.toLowerCase())) {
      try {
        const sourceRes = await fetch('/api/healthcare-sources', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: formData.source.trim() }),
        });
        if (sourceRes.ok) {
          const newSource = await sourceRes.json();
          finalSource = newSource.preferredName;
          setSources(prev => [...prev, newSource].sort((a, b) => 
            a.preferredName.localeCompare(b.preferredName)
          ));
        }
      } catch (err) {
        console.error('Failed to save source:', err);
      }
    }

    try {
      const response = await fetch('/api/health-records', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ...formData,
          source: finalSource,
          data: formData.data || {},
          documentId: uploadedDocument?.id,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to create health record');
      }

      const current = fileQueue[currentQueueIndex];
      if (current) {
        updateQueueItem(current.localId, { status: 'saved' });
      }
      setSavedCount((count) => count + 1);
      await advanceQueueOrExit(currentQueueIndex);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  if (status === 'loading') {
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

  const currentQueueItem = fileQueue[currentQueueIndex];
  const hasMoreInQueue = fileQueue.length > 0 && currentQueueIndex < fileQueue.length - 1;
  const submitLabel = loading
    ? 'Saving...'
    : hasMoreInQueue
      ? 'Confirm & review next'
      : fileQueue.length > 1
        ? 'Confirm & finish'
        : 'Confirm & save';

  const renderQueuePanel = () => {
    if (fileQueue.length === 0) return null;
    return (
      <div className="mb-6 rounded-xl border border-gray-200 bg-gray-50 p-4">
        <div className="flex items-center justify-between mb-3">
          <h4 className="text-sm font-semibold text-gray-900">
            Document queue ({savedCount}/{fileQueue.length} saved)
          </h4>
          <span className="text-xs text-gray-500">
            Reviewing {Math.min(currentQueueIndex + 1, fileQueue.length)} of {fileQueue.length}
          </span>
        </div>
        <ul className="space-y-2 max-h-48 overflow-auto">
          {fileQueue.map((item, index) => (
            <li
              key={item.localId}
              className={`flex items-center justify-between rounded-lg px-3 py-2 text-sm ${
                index === currentQueueIndex ? 'bg-white border border-[#0175C2]' : 'bg-white/70 border border-transparent'
              }`}
            >
              <span className="truncate mr-3 text-gray-800">{item.fileName}</span>
              <span className="shrink-0 text-xs uppercase tracking-wide text-gray-500">{item.status}</span>
            </li>
          ))}
        </ul>
      </div>
    );
  };

  const renderDocumentPreview = (variant: 'compact' | 'large' = 'compact') => {
    if (!documentPreviewUrl) return null;
    const previewName = uploadedDocument?.fileName || currentQueueItem?.fileName || '';
    const isPdf = previewName.toLowerCase().endsWith('.pdf') || currentQueueItem?.file.type === 'application/pdf';
    const frameClass =
      variant === 'large'
        ? 'w-full h-[min(78vh,56rem)] min-h-[28rem] bg-white'
        : 'w-full h-[28rem] bg-white';
    const imageClass =
      variant === 'large'
        ? 'w-full max-h-[min(78vh,56rem)] min-h-[28rem] object-contain bg-white'
        : 'w-full max-h-[28rem] object-contain bg-white';
    return (
      <div className={`rounded-xl border border-gray-200 overflow-hidden bg-gray-100 ${variant === 'large' ? 'lg:sticky lg:top-6' : 'mb-6'}`}>
        <div className="px-4 py-2 bg-white border-b border-gray-200 flex items-center justify-between gap-3">
          <span className="text-sm font-medium text-gray-700 truncate">
            Preview{previewName ? `: ${previewName}` : ''}
          </span>
          <a
            href={documentPreviewUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="shrink-0 text-xs font-medium text-[#0175C2] hover:text-[#015a96]"
          >
            Open full size
          </a>
        </div>
        {isPdf ? (
          <iframe title="Document preview" src={documentPreviewUrl} className={frameClass} />
        ) : (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={documentPreviewUrl} alt="Document preview" className={imageClass} />
        )}
      </div>
    );
  };

  const renderStep1 = () => (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Step 1: Upload and scan documents</h3>
        <p className="text-sm text-gray-600 mb-6">
          Drop one or many files. Each document is scanned, auto-filled, then shown for your confirm/edit before the next one.
        </p>
      </div>

      {renderQueuePanel()}

      {!uploadedDocument && fileQueue.length === 0 ? (
        <DocumentUploader multiple onFilesSelected={handleFilesSelected} />
      ) : (
        <div className="space-y-4">
          {uploadedDocument && (
            <div className="flex items-center justify-between p-4 bg-gray-50 rounded-lg border border-gray-200">
              <div className="flex items-center min-w-0">
                <svg className="w-6 h-6 text-green-500 mr-2 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
                <span className="text-sm font-medium text-gray-700 truncate">{uploadedDocument.fileName}</span>
              </div>
              {fileQueue.length === 0 && (
                <button
                  type="button"
                  onClick={() => {
                    resetExtractionState();
                  }}
                  className="text-red-500 hover:text-red-700 text-sm"
                >
                  Remove
                </button>
              )}
            </div>
          )}

          {renderDocumentPreview()}

          <div className="space-y-3">
            <OCRProgress label="Text Extraction (OCR)" status={ocrStatus} />
            <OCRProgress label="AI Analysis" status={aiStatus} />
          </div>

          {ocrStatus === 'COMPLETED' && aiStatus === 'COMPLETED' && (
            <div className="p-4 bg-green-50 border border-green-200 rounded-lg">
              <p className="text-sm text-green-800 font-medium mb-2">Scan complete. Review the extracted details next.</p>
              <p className="text-xs text-green-700">
                {aiResults?.classification && `Detected: ${aiResults.classification}`}
                {aiResults?.source && ` • Source: ${aiResults.source}`}
                {aiResults?.tags && aiResults.tags.length > 0 && ` • Tags: ${aiResults.tags.join(', ')}`}
              </p>
            </div>
          )}

          {(ocrStatus === 'FAILED' || aiStatus === 'FAILED') && (
            <div className="p-4 bg-red-50 border border-red-200 rounded-lg">
              <p className="text-sm text-red-800">Automatic extraction had an issue. You can still continue and fill details manually.</p>
            </div>
          )}

          {currentQueueItem?.status === 'failed' && (
            <div className="flex flex-wrap gap-3 pt-2">
              <button
                type="button"
                onClick={handleRetryCurrent}
                className="px-4 py-2 rounded-lg font-medium bg-[#0175C2] text-white hover:bg-[#015a96]"
              >
                Retry this file
              </button>
              {hasMoreInQueue && (
                <button
                  type="button"
                  onClick={handleSkipCurrent}
                  className="px-4 py-2 rounded-lg font-medium bg-gray-100 text-gray-700 hover:bg-gray-200"
                >
                  Skip to next
                </button>
              )}
            </div>
          )}

          <div className="flex justify-end pt-4">
            <button
              type="button"
              onClick={handleNext}
              disabled={
                currentQueueItem?.status === 'failed' ||
                ocrStatus === 'PROCESSING' ||
                aiStatus === 'PROCESSING' ||
                ocrStatus === 'PENDING'
              }
              className={`px-6 py-2 rounded-lg font-medium transition-colors ${
                currentQueueItem?.status !== 'failed' &&
                ocrStatus !== 'PROCESSING' &&
                aiStatus !== 'PROCESSING' &&
                ocrStatus !== 'PENDING'
                  ? 'bg-[#0175C2] hover:bg-[#015a96] text-white'
                  : 'bg-gray-300 text-gray-500 cursor-not-allowed'
              }`}
            >
              Next: Review details
            </button>
          </div>
        </div>
      )}
    </div>
  );

  const renderStep2 = () => (
    <div className="space-y-6">
      <div>
        <h3 className="text-lg font-semibold text-gray-900 mb-2">Step 2: Confirm or edit</h3>
        <p className="text-sm text-gray-600 mb-6">
          Check the auto-extracted fields against the document preview, edit anything that looks wrong, then confirm.
        </p>
      </div>

      {renderQueuePanel()}

      <div className={`gap-8 ${documentPreviewUrl ? 'lg:grid lg:grid-cols-2 lg:items-start' : ''}`}>
        {documentPreviewUrl && (
          <div className="mb-6 lg:mb-0">
            {renderDocumentPreview('large')}
          </div>
        )}

      <form onSubmit={handleSubmit} className="space-y-6">
        <div>
          <label htmlFor="patientId" className="block text-sm font-medium text-gray-700 mb-2">
            Patient *
          </label>
          <select
            id="patientId"
            required
            value={formData.patientId}
            onChange={(e) => setFormData({ ...formData, patientId: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
          >
            <option value="">Select a patient</option>
            {patients.map((patient) => (
              <option key={patient.id} value={patient.id}>
                {patient.firstName} {patient.lastName || ''}
              </option>
            ))}
          </select>
        </div>

        <div>
          <label htmlFor="recordType" className="block text-sm font-medium text-gray-700 mb-2">
            Record Type *
          </label>
          <select
            id="recordType"
            required
            value={formData.recordType}
            onChange={(e) => setFormData({ ...formData, recordType: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
            disabled={categories.length === 0}
          >
            <option value="">{categories.length === 0 ? 'Loading categories...' : 'Select a record type'}</option>
            {categories.map((category) => (
              <option key={category.code} value={category.code}>
                {category.displayName}
              </option>
            ))}
          </select>
          {categories.length === 0 && (
            <p className="mt-1 text-sm text-gray-500">If categories don't load, make sure to run: tsx scripts/init-health-record-categories.ts</p>
          )}
        </div>

        <div>
          <label htmlFor="source" className="block text-sm font-medium text-gray-700 mb-2">
            Source (Hospital/Provider) *
          </label>
          <div className="relative">
            <input
              type="text"
              id="source"
              required
              value={sourceInput || formData.source}
              onChange={(e) => handleSourceChange(e.target.value)}
              onFocus={() => {
                if (!sourcesLoading && sources.length > 0) {
                  setShowSourceDropdown(true);
                }
              }}
              onBlur={handleSourceBlur}
              placeholder="Type to search or enter new source..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
            />
            {showSourceDropdown && !sourcesLoading && filteredSources.length > 0 && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-auto">
                {filteredSources.map((source) => (
                  <button
                    key={source.id || source._id}
                    type="button"
                    onMouseDown={(e) => {
                      e.preventDefault();
                      handleSourceSelect(source);
                    }}
                    className="w-full text-left px-4 py-2 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none transition-colors"
                  >
                    <div className="font-medium text-gray-900">{source.preferredName}</div>
                    {source.aliases && source.aliases.length > 0 && (
                      <div className="text-xs text-gray-500">
                        Also known as: {source.aliases.slice(0, 2).join(', ')}
                      </div>
                    )}
                  </button>
                ))}
              </div>
            )}
            {showSourceDropdown && !sourcesLoading && filteredSources.length === 0 && sourceInput.trim() !== '' && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg p-4 text-sm text-gray-500">
                No matching sources found. Press Enter to create a new source.
              </div>
            )}
          </div>
          <p className="mt-1 text-xs text-gray-500">
            {sourcesLoading 
              ? 'Loading sources...' 
              : sources.length === 0 
                ? 'No sources available. Start typing to create a new source.' 
                : 'Start typing to search existing sources or enter a new one'}
          </p>
        </div>

        <div>
          <label htmlFor="documentDate" className="block text-sm font-medium text-gray-700 mb-2">
            Document Date
          </label>
          <input
            type="date"
            id="documentDate"
            value={formData.documentDate}
            onChange={(e) => setFormData({ ...formData, documentDate: e.target.value })}
            className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
          />
          <p className="mt-1 text-xs text-gray-500">
            Date when the document was created, written, or reported (e.g., prescription date, test report date)
          </p>
        </div>

        <div>
          <label htmlFor="doctorName" className="block text-sm font-medium text-gray-700 mb-2">
            Doctor Name
          </label>
          <div className="relative">
            <input
              type="text"
              id="doctorName"
              value={doctorInput || formData.doctorName}
              onChange={(e) => handleDoctorChange(e.target.value)}
              onFocus={() => {
                if (!doctorsLoading && doctors.length > 0) {
                  setShowDoctorDropdown(true);
                }
              }}
              onBlur={handleDoctorBlur}
              placeholder="Type to search or enter new doctor name..."
              className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#0175C2] focus:border-transparent"
            />
            {showDoctorDropdown && !doctorsLoading && filteredDoctors.length > 0 && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg max-h-60 overflow-auto">
                {filteredDoctors.map((doctor) => (
                  <button
                    key={doctor.id || doctor._id}
                    type="button"
                    onMouseDown={(e) => {
                      e.preventDefault();
                      handleDoctorSelect(doctor);
                    }}
                    className="w-full text-left px-4 py-2 hover:bg-gray-100 focus:bg-gray-100 focus:outline-none transition-colors"
                  >
                    <div className="font-medium text-gray-900">{doctor.preferredName}</div>
                    {doctor.aliases && doctor.aliases.length > 0 && (
                      <div className="text-xs text-gray-500">
                        Also known as: {doctor.aliases.slice(0, 2).join(', ')}
                      </div>
                    )}
                  </button>
                ))}
              </div>
            )}
            {showDoctorDropdown && !doctorsLoading && filteredDoctors.length === 0 && doctorInput.trim() !== '' && (
              <div className="absolute z-50 w-full mt-1 bg-white border border-gray-300 rounded-lg shadow-lg p-4 text-sm text-gray-500">
                No matching doctors found. Press Enter to create a new doctor.
              </div>
            )}
          </div>
          <p className="mt-1 text-xs text-gray-500">
            {doctorsLoading 
              ? 'Loading doctors...' 
              : doctors.length === 0 
                ? 'No doctors available. Start typing to create a new doctor.' 
                : 'Start typing to search existing doctors or enter a new one'}
          </p>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Tags
          </label>
          {formData.tags.length > 0 ? (
            <div className="flex flex-wrap gap-2 mb-3">
              {formData.tags.map((tag) => (
                <span
                  key={tag}
                  className="inline-flex items-center px-3 py-1 rounded-lg text-sm font-medium bg-[#0175C2] text-white"
                >
                  {tag}
                  <button
                    type="button"
                    onClick={() => handleTagToggle(tag)}
                    className="ml-2 hover:text-gray-200"
                  >
                    ×
                  </button>
                </span>
              ))}
            </div>
          ) : (
            <p className="text-sm text-gray-500 mb-3">No tags added yet. Tags will be auto-populated from AI analysis.</p>
          )}
          <div className="flex flex-wrap gap-2">
            <p className="text-xs text-gray-500 w-full mb-2">Quick add common tags:</p>
            {DEFAULT_TAGS.map((tag) => (
              <button
                key={tag}
                type="button"
                onClick={() => handleTagToggle(tag)}
                className={`px-3 py-1 rounded-lg text-sm font-medium transition-colors ${formData.tags.includes(tag)
                  ? 'bg-[#0175C2] text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
                  }`}
              >
                {tag}
              </button>
            ))}
          </div>
        </div>

        <div className="flex flex-wrap gap-3 pt-4">
          <button
            type="button"
            onClick={() => setCurrentStep(1)}
            className="px-6 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg font-medium transition-colors"
          >
            Back
          </button>
          {hasMoreInQueue && (
            <button
              type="button"
              onClick={handleSkipCurrent}
              disabled={loading}
              className="px-6 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg font-medium transition-colors disabled:opacity-50"
            >
              Skip this file
            </button>
          )}
          <button
            type="submit"
            disabled={loading}
            className="flex-1 min-w-[12rem] bg-[#0175C2] hover:bg-[#015a96] text-white px-6 py-3 rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {submitLabel}
          </button>
          <Link
            href={formData.patientId ? `/health-records?patientId=${formData.patientId}` : '/health-records'}
            className="px-6 py-2 text-center bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-lg font-medium transition-colors"
          >
            Cancel
          </Link>
        </div>
      </form>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <nav className="bg-white shadow-lg">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center space-x-3">
              <Link href="/dashboard">
                <Image
                  src="/logo.png"
                  alt="SanoVault Logo"
                  width={40}
                  height={40}
                  className="rounded-full cursor-pointer"
                />
              </Link>
              <Link href="/dashboard">
                <h1 className="text-xl font-bold text-gray-900 cursor-pointer">SanoVault</h1>
              </Link>
            </div>
            <div className="flex items-center space-x-4">
              <Link
                href="/health-records"
                className="text-sm text-gray-700 hover:text-[#0175C2] transition-colors"
              >
                ← Back to Health Records
              </Link>
            </div>
          </div>
        </div>
      </nav>

      <main className={`mx-auto py-8 sm:px-6 lg:px-8 ${currentStep === 2 && documentPreviewUrl ? 'max-w-7xl' : 'max-w-3xl'}`}>
        <div className="px-4 py-6 sm:px-0">
          <div className="bg-white rounded-2xl shadow-xl p-6 sm:p-8">
            <div className="mb-6">
              <h2 className="text-2xl font-bold text-gray-900 mb-2">Add Health Record</h2>
              <div className="flex items-center space-x-2">
                <div className={`flex items-center ${currentStep >= 1 ? 'text-[#0175C2]' : 'text-gray-400'}`}>
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center ${currentStep >= 1 ? 'bg-[#0175C2] text-white' : 'bg-gray-200 text-gray-500'}`}>
                    {currentStep > 1 ? '✓' : '1'}
                  </div>
                  <span className="ml-2 text-sm font-medium">Upload & Process</span>
                </div>
                <div className="w-12 h-0.5 bg-gray-300"></div>
                <div className={`flex items-center ${currentStep >= 2 ? 'text-[#0175C2]' : 'text-gray-400'}`}>
                  <div className={`w-8 h-8 rounded-full flex items-center justify-center ${currentStep >= 2 ? 'bg-[#0175C2] text-white' : 'bg-gray-200 text-gray-500'}`}>
                    2
                  </div>
                  <span className="ml-2 text-sm font-medium">Details</span>
                </div>
              </div>
            </div>

            {error && (
              <div className="bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg mb-6">
                {error}
              </div>
            )}

            {currentStep === 1 ? renderStep1() : renderStep2()}
          </div>
        </div>
      </main>
    </div>
  );
}

export default function NewHealthRecordPage() {
  return (
    <Suspense fallback={
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-[#0175C2] mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading...</p>
        </div>
      </div>
    }>
      <NewHealthRecordContent />
    </Suspense>
  );
}
