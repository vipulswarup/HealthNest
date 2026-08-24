'use client';

import Link from 'next/link';
import { ageFromDateOfBirth } from '@/lib/reports/doctor-packet';

type TrackLink = {
  href: string;
  label: string;
};

function trackLinks(patientId: string, dateOfBirth?: string | Date | null): TrackLink[] {
  const age = ageFromDateOfBirth(dateOfBirth);
  const isChild = age !== null && age < 18;

  const bp: TrackLink = { href: `/bp?patientId=${patientId}`, label: 'Log BP' };
  const growth: TrackLink = { href: `/growth?patientId=${patientId}`, label: 'Height & weight' };
  const vaccinations: TrackLink = { href: `/vaccinations?patientId=${patientId}`, label: 'Vaccinations' };
  const medicines: TrackLink = { href: `/medications?patientId=${patientId}`, label: 'Medicines' };
  const visitNotes: TrackLink = { href: `/visit-notes?patientId=${patientId}`, label: 'Visit notes' };

  if (isChild) {
    return [growth, vaccinations, bp, medicines, visitNotes];
  }
  return [bp, growth, vaccinations, medicines, visitNotes];
}

export function PersonCardActions({
  patientId,
  dateOfBirth,
  onAddReport,
  onNavigate,
}: {
  patientId: string;
  dateOfBirth?: string | Date | null;
  onAddReport: () => void;
  onNavigate: () => void;
}) {
  const links = trackLinks(patientId, dateOfBirth);
  const linkClass =
    'flex min-h-12 items-center justify-center rounded-xl border border-gray-300 px-4 text-base font-medium text-gray-800 hover:bg-gray-50';

  return (
    <div className="mt-4 space-y-3">
      <div className="grid gap-3 sm:grid-cols-2">
        <button
          type="button"
          onClick={onAddReport}
          className="flex min-h-14 items-center justify-center rounded-xl bg-[#0175C2] px-4 text-base font-medium text-white hover:bg-[#015a96] sm:col-span-2"
        >
          Add a report
        </button>
        <Link
          href={`/for-the-doctor?patientId=${patientId}`}
          onClick={onNavigate}
          className="flex min-h-14 items-center justify-center rounded-xl border-2 border-[#0175C2] px-4 text-base font-medium text-[#0175C2] hover:bg-blue-50 sm:col-span-2"
        >
          For the doctor
        </Link>
      </div>

      <details className="group rounded-xl border border-gray-200 bg-gray-50 open:bg-white">
        <summary className="flex min-h-12 cursor-pointer list-none items-center justify-between px-4 py-3 text-base font-medium text-gray-800 marker:content-none [&::-webkit-details-marker]:hidden">
          <span>Track health</span>
          <span className="text-sm font-normal text-gray-500 group-open:hidden">BP, growth, vaccines…</span>
          <span aria-hidden className="text-gray-400 group-open:rotate-180">▾</span>
        </summary>
        <div className="grid gap-2 border-t border-gray-200 px-3 pb-3 pt-2">
          {links.map((link) => (
            <Link key={link.href} href={link.href} onClick={onNavigate} className={linkClass}>
              {link.label}
            </Link>
          ))}
        </div>
      </details>
    </div>
  );
}
