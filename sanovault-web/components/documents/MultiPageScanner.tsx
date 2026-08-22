'use client';

import { useId, useRef, useState } from 'react';

type ScanPage = { id: string; file: File; url: string };

export function MultiPageScanner({
  onCancel,
  onComplete,
}: {
  onCancel: () => void;
  onComplete: (files: File[]) => void;
}) {
  const inputId = useId();
  const inputRef = useRef<HTMLInputElement>(null);
  const [pages, setPages] = useState<ScanPage[]>([]);
  const [error, setError] = useState('');

  const addFiles = (list: FileList | null) => {
    if (!list?.length) return;
    const next: ScanPage[] = [];
    for (const file of Array.from(list)) {
      if (!file.type.startsWith('image/') && !/\.(jpe?g|png|webp|heic|heif|gif|bmp)$/i.test(file.name)) {
        setError('Use the camera or a photo of the page.');
        continue;
      }
      next.push({ id: `${file.name}-${file.lastModified}-${Math.random().toString(36).slice(2, 7)}`, file, url: URL.createObjectURL(file) });
    }
    if (next.length === 0) return;
    setError('');
    setPages((current) => [...current, ...next]);
    if (inputRef.current) inputRef.current.value = '';
  };

  const removePage = (id: string) => {
    setPages((current) => {
      const target = current.find((page) => page.id === id);
      if (target) URL.revokeObjectURL(target.url);
      return current.filter((page) => page.id !== id);
    });
  };

  const finish = () => {
    if (pages.length === 0) {
      setError('Take at least one photo.');
      return;
    }
    onComplete(pages.map((page) => page.file));
  };

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-gray-900">Scan pages</h3>
        <p className="mt-1 text-sm text-gray-600">Take one photo per page, then done. They will be combined into one PDF.</p>
      </div>

      <input
        id={inputId}
        ref={inputRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="sr-only"
        onChange={(event) => addFiles(event.target.files)}
      />

      {pages.length > 0 ? (
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {pages.map((page, index) => (
            <li key={page.id} className="overflow-hidden rounded-xl border border-gray-200 bg-white">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={page.url} alt={`Page ${index + 1}`} className="h-36 w-full object-cover" />
              <div className="flex items-center justify-between px-3 py-2">
                <span className="text-xs font-medium text-gray-600">Page {index + 1}</span>
                <button type="button" onClick={() => removePage(page.id)} className="text-xs font-medium text-red-700 hover:underline">
                  Remove
                </button>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <div className="rounded-xl border border-dashed border-gray-300 bg-gray-50 px-4 py-10 text-center text-sm text-gray-600">
          No pages yet.
        </div>
      )}

      {error ? <p className="text-sm text-red-700">{error}</p> : null}

      <div className="flex flex-wrap gap-3">
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          className="min-h-12 rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96]"
        >
          {pages.length === 0 ? 'Take photo' : 'Add another page'}
        </button>
        <button
          type="button"
          onClick={finish}
          disabled={pages.length === 0}
          className="min-h-12 rounded-xl border border-gray-300 bg-white px-4 text-base font-medium text-gray-900 hover:bg-gray-50 disabled:opacity-50"
        >
          Done
        </button>
        <button type="button" onClick={onCancel} className="min-h-12 rounded-xl px-4 text-base font-medium text-gray-700 hover:underline">
          Cancel
        </button>
      </div>
    </div>
  );
}
