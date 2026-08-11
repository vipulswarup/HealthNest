'use client';

import { useState, useRef } from 'react';
import { useRouter } from 'next/navigation';

const ACCEPTED = '.pdf,.jpg,.jpeg,.png,.heic,.heif';
const MAX_FILE_SIZE = 50 * 1024 * 1024;

interface DocumentUploaderProps {
  onUploadSuccess?: (document: { id: string; fileName: string }) => void;
  /** When set, selected files are handed to the parent (multi-file queue). */
  onFilesSelected?: (files: File[]) => void;
  multiple?: boolean;
  disabled?: boolean;
}

export function DocumentUploader({
  onUploadSuccess,
  onFilesSelected,
  multiple = false,
  disabled = false,
}: DocumentUploaderProps) {
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const router = useRouter();

  const validateFiles = (files: File[]) => {
    const allowed = new Set([
      'application/pdf',
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/heic',
      'image/heif',
    ]);
    for (const file of files) {
      if (!allowed.has(file.type) && !/\.(pdf|jpe?g|png|heic|heif)$/i.test(file.name)) {
        throw new Error(`Unsupported file type: ${file.name}`);
      }
      if (file.size > MAX_FILE_SIZE) {
        throw new Error(`${file.name} exceeds the 50MB limit`);
      }
    }
  };

  const takeFiles = (list: FileList | null) => {
    if (!list?.length) return;
    const files = Array.from(list);
    setError(null);
    try {
      validateFiles(files);
      if (onFilesSelected) {
        onFilesSelected(multiple ? files : [files[0]]);
        return;
      }
      void uploadSequentially(multiple ? files : [files[0]]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Invalid file');
    }
  };

  const uploadOne = async (file: File) => {
    const formData = new FormData();
    formData.append('file', file);
    const response = await fetch('/api/documents/upload', {
      method: 'POST',
      body: formData,
    });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.error || data.message || 'Upload failed');
    }
    return data as { id: string; fileName: string };
  };

  const uploadSequentially = async (files: File[]) => {
    setIsUploading(true);
    setError(null);
    try {
      for (const file of files) {
        const document = await uploadOne(file);
        if (onUploadSuccess) {
          onUploadSuccess(document);
        } else {
          router.push(`/documents/${document.id}/review`);
          return;
        }
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred during upload');
    } finally {
      setIsUploading(false);
      if (fileInputRef.current) fileInputRef.current.value = '';
    }
  };

  return (
    <div className="w-full">
      <div
        className={`border-2 border-dashed rounded-lg p-10 text-center cursor-pointer transition-colors ${
          isDragging
            ? 'border-[#0175C2] bg-blue-50'
            : 'border-gray-300 hover:border-gray-400 bg-gray-50'
        } ${disabled || isUploading ? 'opacity-60 pointer-events-none' : ''}`}
        onDragOver={(e) => {
          e.preventDefault();
          setIsDragging(true);
        }}
        onDragLeave={() => setIsDragging(false)}
        onDrop={(e) => {
          e.preventDefault();
          setIsDragging(false);
          takeFiles(e.dataTransfer.files);
        }}
        onClick={() => fileInputRef.current?.click()}
      >
        <input
          type="file"
          ref={fileInputRef}
          className="hidden"
          accept={ACCEPTED}
          multiple={multiple}
          onChange={(e) => takeFiles(e.target.files)}
          disabled={disabled || isUploading}
        />

        {isUploading ? (
          <div className="flex flex-col items-center">
            <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-[#0175C2] mb-2" />
            <p className="text-gray-600">Uploading...</p>
          </div>
        ) : (
          <div>
            <svg
              className="mx-auto h-12 w-12 text-gray-400"
              stroke="currentColor"
              fill="none"
              viewBox="0 0 48 48"
              aria-hidden="true"
            >
              <path
                d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                strokeWidth={2}
                strokeLinecap="round"
                strokeLinejoin="round"
              />
            </svg>
            <p className="mt-2 text-sm text-gray-600">
              {multiple
                ? 'Drag and drop files here, or click to select multiple'
                : 'Drag and drop your file here, or click to select'}
            </p>
            <p className="mt-1 text-xs text-gray-500">PDF, JPG, PNG, HEIC up to 50MB each</p>
          </div>
        )}
      </div>

      {error && (
        <div className="mt-4 p-3 bg-red-100 text-red-700 rounded-md text-sm">{error}</div>
      )}
    </div>
  );
}
