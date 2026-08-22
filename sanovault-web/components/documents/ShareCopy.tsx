'use client';

import { useCallback, useEffect, useRef, useState, type PointerEvent } from 'react';
import { getPdfPageCount, renderPdfPage } from '@/lib/pdf/inspect';
import { buildShareCopy, type CoverSpec, type ShareRedaction } from '@/lib/pdf/share';

type LoadedDocument = {
  id: string;
  label: string;
};

export function ShareCopy({
  documents,
  cover,
  defaultWatermark,
  defaultFileName,
}: {
  documents: LoadedDocument[];
  cover?: CoverSpec;
  defaultWatermark?: string;
  defaultFileName: string;
}) {
  const [open, setOpen] = useState(false);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [bytes, setBytes] = useState<Uint8Array | null>(null);
  const [pageCount, setPageCount] = useState(0);
  const [pageImages, setPageImages] = useState<string[]>([]);
  const [activePage, setActivePage] = useState(0);
  const [redactions, setRedactions] = useState<ShareRedaction[]>([]);
  const [watermark, setWatermark] = useState(defaultWatermark || '');
  const [password, setPassword] = useState('');
  const [draft, setDraft] = useState<{ x: number; y: number; width: number; height: number } | null>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const basePageRef = useRef<HTMLCanvasElement | null>(null);
  const dragOrigin = useRef<{ x: number; y: number } | null>(null);
  const draftRef = useRef(draft);
  draftRef.current = draft;
  const redactionsRef = useRef(redactions);
  redactionsRef.current = redactions;
  const activePageRef = useRef(activePage);
  activePageRef.current = activePage;

  const paint = useCallback(() => {
    const canvas = canvasRef.current;
    const base = basePageRef.current;
    if (!canvas || !base) return;
    canvas.width = base.width;
    canvas.height = base.height;
    const context = canvas.getContext('2d');
    if (!context) return;
    context.drawImage(base, 0, 0);
    context.fillStyle = 'rgba(0,0,0,0.92)';
    for (const box of redactionsRef.current) {
      if (box.pageIndex !== activePageRef.current) continue;
      context.fillRect(box.left * canvas.width, box.top * canvas.height, box.width * canvas.width, box.height * canvas.height);
    }
    const currentDraft = draftRef.current;
    if (currentDraft) {
      context.fillStyle = 'rgba(0,0,0,0.45)';
      context.fillRect(currentDraft.x * canvas.width, currentDraft.y * canvas.height, currentDraft.width * canvas.width, currentDraft.height * canvas.height);
    }
  }, []);

  const documentKey = documents.map((document) => document.id).join('|');
  const coverKey = JSON.stringify(cover ?? null);

  const load = useCallback(async () => {
    setBusy('Loading reports…');
    setError('');
    try {
      const loaded = documents.length === 0
        ? []
        : await Promise.all(documents.map(async (document) => {
          const response = await fetch(`/api/documents/${document.id}/file`);
          if (!response.ok) throw new Error('Could not open a report for sharing');
          const buffer = new Uint8Array(await response.arrayBuffer());
          const mimeType = response.headers.get('content-type') || 'application/pdf';
          return { bytes: buffer, fileName: document.label, mimeType };
        }));
      const { assembleSharePdf } = await import('@/lib/pdf/share');
      const assembled = await assembleSharePdf({ documents: loaded, cover });
      const count = await getPdfPageCount(assembled);
      const thumbs: string[] = [];
      for (let page = 1; page <= count; page += 1) {
        const canvas = await renderPdfPage(assembled, page, { scale: 0.35 });
        thumbs.push(canvas.toDataURL('image/jpeg', 0.55));
      }
      setBytes(assembled);
      setPageCount(count);
      setPageImages(thumbs);
      setActivePage(0);
      setRedactions([]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not prepare a share copy');
    } finally {
      setBusy('');
    }
  }, [coverKey, documentKey]);

  useEffect(() => {
    if (!open) return;
    void load();
  }, [load, open]);

  const pointFromEvent = (event: PointerEvent<HTMLCanvasElement>) => {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    return {
      x: Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width)),
      y: Math.min(1, Math.max(0, (event.clientY - rect.top) / rect.height)),
    };
  };

  const onPointerDown = (event: PointerEvent<HTMLCanvasElement>) => {
    event.preventDefault();
    const point = pointFromEvent(event);
    dragOrigin.current = point;
    setDraft({ x: point.x, y: point.y, width: 0, height: 0 });
    event.currentTarget.setPointerCapture(event.pointerId);
  };

  const onPointerMove = (event: PointerEvent<HTMLCanvasElement>) => {
    if (!dragOrigin.current) return;
    const point = pointFromEvent(event);
    const x = Math.min(dragOrigin.current.x, point.x);
    const y = Math.min(dragOrigin.current.y, point.y);
    setDraft({
      x,
      y,
      width: Math.abs(point.x - dragOrigin.current.x),
      height: Math.abs(point.y - dragOrigin.current.y),
    });
  };

  const onPointerUp = (event: PointerEvent<HTMLCanvasElement>) => {
    const origin = dragOrigin.current;
    dragOrigin.current = null;
    const current = draftRef.current;
    if (origin && current && current.width > 0.01 && current.height > 0.01) {
      setRedactions((items) => [
        ...items,
        { pageIndex: activePage, left: current.x, top: current.y, width: current.width, height: current.height },
      ]);
    }
    setDraft(null);
    event.currentTarget.releasePointerCapture(event.pointerId);
  };

  useEffect(() => {
    if (!bytes || !open) return;
    let cancelled = false;
    void renderPdfPage(bytes, activePage + 1, { scale: 1.1 }).then((rendered) => {
      if (cancelled) return;
      basePageRef.current = rendered;
      paint();
    });
    return () => {
      cancelled = true;
    };
  }, [activePage, bytes, open, paint]);

  useEffect(() => {
    paint();
  }, [draft, paint, redactions]);

  const exportCopy = async () => {
    if (!bytes) return;
    setBusy('Building share copy…');
    setError('');
    try {
      const file = await buildShareCopy({
        documents: [{ bytes, fileName: defaultFileName, mimeType: 'application/pdf' }],
        redactions,
        watermark: watermark.trim() || undefined,
        password: password.trim() || undefined,
        fileName: defaultFileName.endsWith('.pdf') ? defaultFileName : `${defaultFileName}.pdf`,
      });
      const shareData = { files: [file], title: file.name };
      try {
        if (typeof navigator.share === 'function' && navigator.canShare?.(shareData)) {
          await navigator.share(shareData);
          return;
        }
      } catch {
        // Fall through to a same-device download.
      }
      const url = URL.createObjectURL(file);
      const link = document.createElement('a');
      link.href = url;
      link.download = file.name;
      link.click();
      URL.revokeObjectURL(url);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not build the share copy');
    } finally {
      setBusy('');
    }
  };

  if (documents.length === 0 && !cover) return null;

  return (
    <div>
      <button
        type="button"
        onClick={() => setOpen(true)}
        className="inline-flex min-h-12 items-center justify-center rounded-xl border border-gray-300 bg-white px-4 text-base font-medium text-gray-900 hover:bg-gray-50 print:hidden"
      >
        Prepare share copy
      </button>

      {open ? (
        <div className="fixed inset-0 z-50 overflow-y-auto bg-black/40 p-4 print:hidden" role="dialog" aria-modal="true" aria-labelledby="share-copy-title">
          <div className="mx-auto max-w-3xl rounded-2xl bg-white p-5 shadow-sm">
            <h2 id="share-copy-title" className="text-xl font-semibold text-gray-950">Share copy</h2>
            <p className="mt-1 text-sm text-gray-600">
              Draw black boxes over names or IDs that should not leave the vault. The original file is unchanged.
            </p>

            {busy ? <p className="mt-4 text-sm text-gray-600" role="status">{busy}</p> : null}
            {error ? <p className="mt-4 text-sm text-red-700">{error}</p> : null}

            {pageCount > 1 ? (
              <div className="mt-4 flex gap-2 overflow-x-auto">
                {pageImages.map((src, index) => (
                  <button
                    key={src}
                    type="button"
                    onClick={() => setActivePage(index)}
                    className={`shrink-0 overflow-hidden rounded-lg border ${activePage === index ? 'border-[#0175C2]' : 'border-gray-200'}`}
                  >
                    {/* eslint-disable-next-line @next/next/no-img-element */}
                    <img src={src} alt={`Page ${index + 1}`} className="h-20 w-14 object-cover" />
                  </button>
                ))}
              </div>
            ) : null}

            <canvas
              ref={canvasRef}
              className="mt-4 w-full touch-none cursor-crosshair rounded-lg border border-gray-200 bg-gray-100"
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
            />

            <div className="mt-4 grid gap-3 sm:grid-cols-2">
              <label className="block text-sm font-medium text-gray-700">
                Watermark
                <input value={watermark} onChange={(event) => setWatermark(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" />
              </label>
              <label className="block text-sm font-medium text-gray-700">
                Password (optional)
                <input value={password} onChange={(event) => setPassword(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" autoComplete="off" />
              </label>
            </div>

            <div className="mt-4 flex flex-wrap gap-3">
              <button type="button" onClick={() => setRedactions((current) => current.filter((rect) => rect.pageIndex !== activePage))} className="rounded-lg border border-gray-300 px-3 py-2 text-sm">
                Clear boxes on this page
              </button>
              <button type="button" onClick={() => void exportCopy()} disabled={Boolean(busy) || !bytes} className="rounded-lg bg-[#0175C2] px-4 py-2 text-sm font-medium text-white hover:bg-[#015a96] disabled:opacity-50">
                Download / share
              </button>
              <button type="button" onClick={() => setOpen(false)} className="rounded-lg px-3 py-2 text-sm text-gray-700 hover:underline">
                Close
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
