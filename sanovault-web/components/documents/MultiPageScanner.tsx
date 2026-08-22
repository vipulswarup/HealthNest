'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { detectDocumentQuad, drawQuadOverlay } from '@/lib/scan/detect';
import { rescanWithFilter, scanCanvas, scanPhoto, type ScanFilter } from '@/lib/scan/process';

type ScanPage = {
  id: string;
  file: File;
  url: string;
  originalBlob: Blob;
  warpedBlob: Blob;
  detected: boolean;
  cropped: boolean;
};

const FILTERS: Array<{ id: ScanFilter; label: string }> = [
  { id: 'enhance', label: 'Clearer text' },
  { id: 'photo', label: 'Photo' },
  { id: 'bw', label: 'Black and white' },
];

export function MultiPageScanner({
  onCancel,
  onComplete,
}: {
  onCancel: () => void;
  onComplete: (files: File[]) => void;
}) {
  const cameraInputId = useId();
  const libraryInputId = useId();
  const cameraInputRef = useRef<HTMLInputElement>(null);
  const libraryInputRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const overlayRef = useRef<HTMLCanvasElement>(null);
  const scratchRef = useRef<HTMLCanvasElement | null>(null);
  const pagesRef = useRef<ScanPage[]>([]);
  const filterRef = useRef<ScanFilter>('enhance');

  const [pages, setPages] = useState<ScanPage[]>([]);
  const [filter, setFilter] = useState<ScanFilter>('enhance');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState('');
  const [cameraMode, setCameraMode] = useState<'pending' | 'live' | 'file'>('pending');

  pagesRef.current = pages;
  filterRef.current = filter;

  useEffect(() => {
    let stream: MediaStream | null = null;
    let cancelled = false;

    const start = async () => {
      if (!navigator.mediaDevices?.getUserMedia) {
        if (!cancelled) setCameraMode('file');
        return;
      }
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          audio: false,
          video: { facingMode: { ideal: 'environment' }, width: { ideal: 1920 }, height: { ideal: 1080 } },
        });
        if (cancelled) {
          stream.getTracks().forEach((track) => track.stop());
          return;
        }
        const video = videoRef.current;
        if (!video) {
          stream.getTracks().forEach((track) => track.stop());
          setCameraMode('file');
          return;
        }
        video.srcObject = stream;
        await video.play();
        if (!cancelled) setCameraMode('live');
      } catch {
        if (!cancelled) setCameraMode('file');
      }
    };

    void start();
    return () => {
      cancelled = true;
      stream?.getTracks().forEach((track) => track.stop());
      const video = videoRef.current;
      if (video) video.srcObject = null;
    };
  }, []);

  useEffect(() => {
    return () => {
      pagesRef.current.forEach((page) => URL.revokeObjectURL(page.url));
    };
  }, []);

  useEffect(() => {
    if (cameraMode !== 'live') return;
    const tick = () => {
      const video = videoRef.current;
      const overlay = overlayRef.current;
      if (!video || !overlay || video.readyState < 2 || !video.videoWidth || overlay.clientWidth < 8) return;
      if (!scratchRef.current) scratchRef.current = document.createElement('canvas');
      const scratch = scratchRef.current;
      const detectWidth = 320;
      const detectHeight = Math.max(1, Math.round((320 * video.videoHeight) / video.videoWidth));
      scratch.width = detectWidth;
      scratch.height = detectHeight;
      const scratchContext = scratch.getContext('2d', { willReadFrequently: true });
      if (!scratchContext) return;
      scratchContext.drawImage(video, 0, 0, detectWidth, detectHeight);
      const quad = detectDocumentQuad(scratchContext.getImageData(0, 0, detectWidth, detectHeight));
      const ratio = window.devicePixelRatio || 1;
      overlay.width = Math.max(1, Math.round(overlay.clientWidth * ratio));
      overlay.height = Math.max(1, Math.round(overlay.clientHeight * ratio));
      drawQuadOverlay(overlay, quad, detectWidth, detectHeight);
    };
    const timer = window.setInterval(tick, 180);
    return () => window.clearInterval(timer);
  }, [cameraMode]);

  const addResult = (result: Awaited<ReturnType<typeof scanPhoto>>, id: string, originalBlob: Blob) => {
    setPages((current) => [
      ...current,
      {
        id,
        file: result.file,
        url: result.previewUrl,
        originalBlob,
        warpedBlob: result.warpedBlob,
        detected: result.detected,
        cropped: result.detected,
      },
    ]);
  };

  const processBlob = async (blob: Blob, name: string) => {
    setBusy('Straightening the page…');
    setError('');
    try {
      const result = await scanPhoto(blob, filterRef.current, name.replace(/\.[^.]+$/, '') + '.jpg');
      addResult(result, `${name}-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`, blob);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not scan this photo');
    } finally {
      setBusy('');
    }
  };

  const captureLive = async () => {
    const video = videoRef.current;
    if (!video || !video.videoWidth) return;
    setBusy('Straightening the page…');
    setError('');
    try {
      const frame = document.createElement('canvas');
      frame.width = video.videoWidth;
      frame.height = video.videoHeight;
      const context = frame.getContext('2d');
      if (!context) throw new Error('Could not capture this page');
      context.drawImage(video, 0, 0);
      const originalBlob = await new Promise<Blob>((resolve, reject) => {
        frame.toBlob((blob) => (blob ? resolve(blob) : reject(new Error('Could not capture this page'))), 'image/jpeg', 0.95);
      });
      const result = await scanCanvas(frame, filterRef.current, `scan-${pagesRef.current.length + 1}.jpg`);
      addResult(result, `live-${Date.now()}`, originalBlob);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not capture this page');
    } finally {
      setBusy('');
    }
  };

  const addFiles = async (list: FileList | null) => {
    if (!list?.length) return;
    for (const file of Array.from(list)) {
      if (!file.type.startsWith('image/') && !/\.(jpe?g|png|webp|heic|heif|gif|bmp)$/i.test(file.name)) {
        setError('Use the camera or a photo of the page.');
        continue;
      }
      await processBlob(file, file.name);
    }
    if (cameraInputRef.current) cameraInputRef.current.value = '';
    if (libraryInputRef.current) libraryInputRef.current.value = '';
  };

  const removePage = (id: string) => {
    setPages((current) => {
      const target = current.find((page) => page.id === id);
      if (target) URL.revokeObjectURL(target.url);
      return current.filter((page) => page.id !== id);
    });
  };

  const recropPage = async (id: string, crop: boolean) => {
    const page = pagesRef.current.find((item) => item.id === id);
    if (!page) return;
    setBusy(crop ? 'Straightening the page…' : 'Using the original photo…');
    setError('');
    try {
      const result = await scanPhoto(page.originalBlob, filterRef.current, page.file.name, { crop });
      URL.revokeObjectURL(page.url);
      setPages((current) =>
        current.map((item) =>
          item.id === id
            ? {
                ...item,
                file: result.file,
                url: result.previewUrl,
                warpedBlob: result.warpedBlob,
                detected: crop ? result.detected : false,
                cropped: crop && result.detected,
              }
            : item,
        ),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not update this page');
    } finally {
      setBusy('');
    }
  };

  const changeFilter = async (next: ScanFilter) => {
    setFilter(next);
    if (pagesRef.current.length === 0) return;
    setBusy('Applying filter…');
    try {
      const updated: ScanPage[] = [];
      for (const page of pagesRef.current) {
        const file = await rescanWithFilter(page.warpedBlob, next, page.file.name);
        URL.revokeObjectURL(page.url);
        updated.push({ ...page, file, url: URL.createObjectURL(file) });
      }
      setPages(updated);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not apply that filter');
    } finally {
      setBusy('');
    }
  };

  const finish = () => {
    if (pages.length === 0) {
      setError('Scan at least one page.');
      return;
    }
    onComplete(pages.map((page) => page.file));
  };

  return (
    <div className="space-y-4">
      <div>
        <h3 className="text-lg font-semibold text-gray-900">Scan pages</h3>
        <p className="mt-1 text-sm text-gray-600">
          Line the page up in the frame. We crop the edges, straighten it, and sharpen the text.
        </p>
      </div>

      <input
        id={cameraInputId}
        ref={cameraInputRef}
        type="file"
        accept="image/*"
        capture="environment"
        className="sr-only"
        onChange={(event) => void addFiles(event.target.files)}
      />
      <input
        id={libraryInputId}
        ref={libraryInputRef}
        type="file"
        accept="image/*"
        className="sr-only"
        onChange={(event) => void addFiles(event.target.files)}
      />

      {cameraMode !== 'file' ? (
        <div className="relative overflow-hidden rounded-xl bg-black">
          <video
            ref={videoRef}
            className="h-auto w-full max-h-[55vh] object-contain"
            playsInline
            muted
            autoPlay
            aria-label="Document camera"
          />
          <canvas ref={overlayRef} className="pointer-events-none absolute inset-0 h-full w-full" />
          {cameraMode === 'pending' ? (
            <p className="absolute inset-0 flex items-center justify-center text-sm text-white">Opening camera…</p>
          ) : null}
        </div>
      ) : null}

      {pages.length > 0 ? (
        <ul className="grid grid-cols-2 gap-3 sm:grid-cols-3">
          {pages.map((page, index) => (
            <li key={page.id} className="overflow-hidden rounded-xl border border-gray-200 bg-white">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img src={page.url} alt={`Page ${index + 1}`} className="h-36 w-full object-contain bg-gray-100" />
              <div className="flex items-center justify-between gap-2 px-3 py-2">
                <span className="text-xs font-medium text-gray-600">Page {index + 1}</span>
                <div className="flex items-center gap-2">
                  {page.cropped ? (
                    <button type="button" onClick={() => void recropPage(page.id, false)} className="text-xs font-medium text-gray-700 hover:underline">
                      Undo crop
                    </button>
                  ) : (
                    <button type="button" onClick={() => void recropPage(page.id, true)} className="text-xs font-medium text-gray-700 hover:underline">
                      Crop
                    </button>
                  )}
                  <button type="button" onClick={() => removePage(page.id)} className="text-xs font-medium text-red-700 hover:underline">
                    Remove
                  </button>
                </div>
              </div>
            </li>
          ))}
        </ul>
      ) : cameraMode === 'file' ? (
        <div className="rounded-xl border border-dashed border-gray-300 bg-gray-50 px-4 py-10 text-center text-sm text-gray-600">
          No pages yet.
        </div>
      ) : null}

      <fieldset className="space-y-2">
        <legend className="text-sm font-medium text-gray-700">Look</legend>
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((item) => (
            <button
              key={item.id}
              type="button"
              disabled={Boolean(busy)}
              onClick={() => void changeFilter(item.id)}
              className={`min-h-10 rounded-full border px-3 text-sm font-medium ${
                filter === item.id
                  ? 'border-[#0175C2] bg-blue-50 text-[#0175C2]'
                  : 'border-gray-300 bg-white text-gray-800'
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>
      </fieldset>

      {busy ? <p className="text-sm text-gray-600" role="status">{busy}</p> : null}
      {error ? <p className="text-sm text-red-700">{error}</p> : null}

      <div className="flex flex-wrap gap-3">
        {cameraMode === 'live' ? (
          <button
            type="button"
            onClick={() => void captureLive()}
            disabled={Boolean(busy)}
            className="min-h-12 rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96] disabled:opacity-50"
          >
            {pages.length === 0 ? 'Capture page' : 'Capture another page'}
          </button>
        ) : (
          <button
            type="button"
            onClick={() => cameraInputRef.current?.click()}
            disabled={Boolean(busy) || cameraMode === 'pending'}
            className="min-h-12 rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96] disabled:opacity-50"
          >
            {pages.length === 0 ? 'Take photo' : 'Add another page'}
          </button>
        )}
        <button
          type="button"
          onClick={() => libraryInputRef.current?.click()}
          disabled={Boolean(busy)}
          className="min-h-12 rounded-xl border border-gray-300 bg-white px-4 text-base font-medium text-gray-900 hover:bg-gray-50 disabled:opacity-50"
        >
          Choose photo
        </button>
        <button
          type="button"
          onClick={finish}
          disabled={pages.length === 0 || Boolean(busy)}
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
