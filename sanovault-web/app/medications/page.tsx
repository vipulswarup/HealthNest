'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import AppNav from '@/components/layout/AppNav';
import { useSession } from '@/lib/auth/client';

type Country = 'IN' | 'US' | 'GB';
type Ingredient = { canonicalInn: string; localAlias?: string | null; strength: string; strengthUnit: string };
type CatalogueProduct = {
  id: string;
  country: Country;
  brandName: string;
  formulation: string;
  sourceName: string;
  sourceVersion: string;
  ingredients: Ingredient[];
};
type Medication = {
  id: string;
  originalBrandName: string;
  purchaseCountry: Country | null;
  indication: string;
  stoppedReason: string;
  dosage: string;
  frequency: string;
  route: string;
  startDate: string;
  endDate: string | null;
  instructions: string;
  isActive: boolean;
  composition: {
    status: 'CONFIRMED' | 'UNCONFIRMED' | 'REVIEW_NEEDED';
    formulation: string;
    ingredients: Ingredient[];
    requiresWarning: boolean;
  };
};
type Patient = { id: string; firstName: string; lastName?: string };

const countryLabels: Record<Country, string> = { IN: 'India', US: 'USA', GB: 'UK' };
const emptyIngredient = (): Ingredient => ({ canonicalInn: '', strength: '', strengthUnit: 'mg' });

function genericName(ingredients: Ingredient[]): string {
  return ingredients.map((ingredient) => `${ingredient.canonicalInn} ${ingredient.strength} ${ingredient.strengthUnit}`.trim()).join(' + ');
}

export default function MedicationsPage() {
  const { data: session, status } = useSession();
  const router = useRouter();
  const [patients, setPatients] = useState<Patient[]>([]);
  const [patientId, setPatientId] = useState('');
  const [medications, setMedications] = useState<Medication[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [brandName, setBrandName] = useState('');
  const [country, setCountry] = useState<Country>('IN');
  const [candidates, setCandidates] = useState<CatalogueProduct[]>([]);
  const [selectedProduct, setSelectedProduct] = useState<CatalogueProduct | null>(null);
  const [formulation, setFormulation] = useState('');
  const [ingredients, setIngredients] = useState<Ingredient[]>([emptyIngredient()]);
  const [dosage, setDosage] = useState('');
  const [frequency, setFrequency] = useState('');
  const [route, setRoute] = useState('Oral');
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10));
  const [instructions, setInstructions] = useState('');
  const [indication, setIndication] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [stoppedReason, setStoppedReason] = useState('');

  const activeCount = useMemo(() => medications.filter((medication) => medication.isActive).length, [medications]);

  useEffect(() => {
    if (status === 'loading') return;
    if (!session?.user?.id) {
      router.push('/auth/signin');
      return;
    }
    void loadPatients();
  }, [router, session?.user?.id, status]);

  useEffect(() => {
    if (!patientId) {
      setMedications([]);
      return;
    }
    void loadMedications(patientId);
  }, [patientId]);

  useEffect(() => {
    setSelectedProduct(null);
    if (brandName.trim().length < 2) {
      setCandidates([]);
      return;
    }
    const timer = window.setTimeout(async () => {
      try {
        const response = await fetch(`/api/medication-catalog/search?country=${country}&q=${encodeURIComponent(brandName.trim())}`);
        setCandidates(response.ok ? await response.json() : []);
      } catch {
        setCandidates([]);
      }
    }, 300);
    return () => window.clearTimeout(timer);
  }, [brandName, country]);

  async function loadPatients() {
    try {
      const response = await fetch('/api/patients');
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not load patients');
      setPatients(data);
      setPatientId((current) => current || data[0]?.id || '');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load patients');
    } finally {
      setLoading(false);
    }
  }

  async function loadMedications(id: string) {
    try {
      setLoading(true);
      const response = await fetch(`/api/medications?patientId=${id}`);
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not load medications');
      setMedications(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not load medications');
    } finally {
      setLoading(false);
    }
  }

  function chooseCandidate(candidate: CatalogueProduct) {
    setSelectedProduct(candidate);
    setBrandName(candidate.brandName);
    setFormulation(candidate.formulation);
    setIngredients(candidate.ingredients);
    setCandidates([]);
  }

  function resetForm() {
    setBrandName('');
    setCountry('IN');
    setCandidates([]);
    setSelectedProduct(null);
    setFormulation('');
    setIngredients([emptyIngredient()]);
    setDosage('');
    setFrequency('');
    setRoute('Oral');
    setStartDate(new Date().toISOString().slice(0, 10));
    setInstructions('');
    setIndication('');
    setIsActive(true);
    setStoppedReason('');
  }

  function updateIngredient(index: number, field: keyof Ingredient, value: string) {
    setIngredients((current) => current.map((ingredient, ingredientIndex) => (
      ingredientIndex === index ? { ...ingredient, [field]: value } : ingredient
    )));
  }

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!patientId) return;
    try {
      setSaving(true);
      setError('');
      const manualIngredients = ingredients.filter((ingredient) => ingredient.canonicalInn.trim() && ingredient.strength.trim() && ingredient.strengthUnit.trim());
      const response = await fetch('/api/medications', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          patientId,
          name: brandName,
          purchaseCountry: country,
          dosage,
          frequency,
          route,
          startDate,
          instructions,
          indication,
          isActive,
          stoppedReason: isActive ? undefined : stoppedReason,
          composition: selectedProduct
            ? { status: 'CONFIRMED', catalogProductId: selectedProduct.id }
            : { status: 'UNCONFIRMED', formulation, ingredients: manualIngredients },
        }),
      });
      const data = await response.json();
      if (!response.ok) throw new Error(data.error || 'Could not save medication');
      resetForm();
      await loadMedications(patientId);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Could not save medication');
    } finally {
      setSaving(false);
    }
  }

  if (status === 'loading' || loading) {
    return <div className="min-h-screen flex items-center justify-center bg-gray-50"><p className="text-gray-600">Loading medications…</p></div>;
  }
  if (!session) return null;

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100">
      <AppNav />
      <main className="max-w-7xl mx-auto py-8 sm:px-6 lg:px-8">
        <div className="px-4 py-6 sm:px-0 space-y-6">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-bold text-gray-900">Medications</h1>
              <p className="mt-1 text-gray-600">Keep the original brand name and a portable generic composition.</p>
            </div>
            {patientId && <Link href={`/medications/report?patientId=${patientId}`} className="rounded-lg border border-[#0175C2] px-4 py-2 text-sm font-medium text-[#0175C2] hover:bg-blue-50">Doctor-facing list</Link>}
          </div>

          {error && <div className="rounded-lg border border-red-200 bg-red-50 p-4 text-sm text-red-800">{error}</div>}
          {patients.length === 0 ? (
            <div className="rounded-2xl bg-white p-8 text-center shadow-xl"><p className="text-gray-600">Add a patient before recording medications.</p><Link href="/patients/new" className="mt-4 inline-block text-[#0175C2] hover:underline">Add patient</Link></div>
          ) : <>
            <section className="rounded-2xl bg-white p-6 shadow-xl">
              <label htmlFor="medication-patient" className="block text-sm font-medium text-gray-700">Patient</label>
              <select id="medication-patient" value={patientId} onChange={(event) => setPatientId(event.target.value)} className="mt-2 w-full max-w-md rounded-lg border border-gray-300 px-3 py-2">
                {patients.map((patient) => <option key={patient.id} value={patient.id}>{patient.firstName} {patient.lastName || ''}</option>)}
              </select>
              <p className="mt-3 text-sm text-gray-600">{activeCount} active medication{activeCount === 1 ? '' : 's'} recorded.</p>
            </section>

            <section className="rounded-2xl bg-white p-6 shadow-xl">
              <h2 className="text-xl font-semibold text-gray-900">Add medication</h2>
              <p className="mt-1 text-sm text-gray-600">A catalogue match is required to mark a composition confirmed. You can still save an unconfirmed entry.</p>
              <form onSubmit={submit} className="mt-6 space-y-5">
                <div className="grid gap-4 md:grid-cols-2">
                  <label className="text-sm font-medium text-gray-700">Brand name<input required value={brandName} onChange={(event) => setBrandName(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" placeholder="As written on the medicine" /></label>
                  <label className="text-sm font-medium text-gray-700">Country obtained<select value={country} onChange={(event) => setCountry(event.target.value as Country)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2">{Object.entries(countryLabels).map(([code, label]) => <option key={code} value={code}>{label}</option>)}</select></label>
                </div>
                {candidates.length > 0 && <div className="rounded-lg border border-blue-200 bg-blue-50 p-3"><p className="text-sm font-medium text-blue-950">Verified catalogue matches</p><div className="mt-2 space-y-2">{candidates.map((candidate) => <button type="button" key={candidate.id} onClick={() => chooseCandidate(candidate)} className="block w-full rounded-md bg-white p-3 text-left text-sm hover:bg-blue-100"><strong>{candidate.brandName}</strong> · {genericName(candidate.ingredients)} · {candidate.formulation}</button>)}</div></div>}
                {selectedProduct ? <div className="rounded-lg border border-green-200 bg-green-50 p-4 text-sm text-green-950"><strong>Confirmed composition selected:</strong> {genericName(ingredients)} · {formulation}<button type="button" onClick={() => setSelectedProduct(null)} className="ml-3 font-medium text-[#0175C2] hover:underline">Use unconfirmed entry instead</button></div> : <div className="rounded-lg border border-amber-200 bg-amber-50 p-4"><p className="text-sm font-medium text-amber-950">Unconfirmed composition</p><p className="mt-1 text-sm text-amber-900">Add what you know. This record will be visibly marked for review until a verified catalogue match is selected.</p><label className="mt-3 block text-sm font-medium text-gray-700">Formulation<input value={formulation} onChange={(event) => setFormulation(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" placeholder="Tablet, suspension, injection…" /></label><div className="mt-3 space-y-2">{ingredients.map((ingredient, index) => <div className="grid gap-2 md:grid-cols-[1fr_8rem_7rem_auto]" key={index}><input value={ingredient.canonicalInn} onChange={(event) => updateIngredient(index, 'canonicalInn', event.target.value)} className="rounded-lg border border-gray-300 px-3 py-2 text-sm" placeholder="INN / active ingredient" /><input value={ingredient.strength} onChange={(event) => updateIngredient(index, 'strength', event.target.value)} className="rounded-lg border border-gray-300 px-3 py-2 text-sm" placeholder="Strength" /><input value={ingredient.strengthUnit} onChange={(event) => updateIngredient(index, 'strengthUnit', event.target.value)} className="rounded-lg border border-gray-300 px-3 py-2 text-sm" placeholder="Unit" /><button type="button" onClick={() => setIngredients((current) => current.length === 1 ? [emptyIngredient()] : current.filter((_, itemIndex) => itemIndex !== index))} className="text-sm text-red-700 hover:underline">Remove</button></div>)}</div><button type="button" onClick={() => setIngredients((current) => [...current, emptyIngredient()])} className="mt-3 text-sm font-medium text-[#0175C2] hover:underline">+ Add ingredient</button></div>}
                <div className="grid gap-4 md:grid-cols-3"><label className="text-sm font-medium text-gray-700">Prescribed dose<input required value={dosage} onChange={(event) => setDosage(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" placeholder="1 tablet" /></label><label className="text-sm font-medium text-gray-700">Frequency<input required value={frequency} onChange={(event) => setFrequency(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" placeholder="Twice daily" /></label><label className="text-sm font-medium text-gray-700">Route<input required value={route} onChange={(event) => setRoute(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" /></label></div>
                <div className="grid gap-4 md:grid-cols-2"><label className="text-sm font-medium text-gray-700">Start date<input type="date" required value={startDate} onChange={(event) => setStartDate(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" /></label><label className="text-sm font-medium text-gray-700">Reason for use (optional)<input value={indication} onChange={(event) => setIndication(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" placeholder="e.g. hypertension" /></label></div>
                <label className="block text-sm font-medium text-gray-700">Original prescription instructions<textarea value={instructions} onChange={(event) => setInstructions(event.target.value)} className="mt-1 w-full rounded-lg border border-gray-300 px-3 py-2" rows={3} placeholder="Keep wording from the prescription where possible" /></label>
                <div className="flex flex-wrap items-center gap-4"><label className="flex items-center gap-2 text-sm text-gray-700"><input type="checkbox" checked={isActive} onChange={(event) => setIsActive(event.target.checked)} /> Active medication</label>{!isActive && <input value={stoppedReason} onChange={(event) => setStoppedReason(event.target.value)} className="rounded-lg border border-gray-300 px-3 py-2 text-sm" placeholder="Reason stopped (optional)" />}</div>
                <button disabled={saving} className="rounded-lg bg-[#0175C2] px-5 py-2.5 font-medium text-white hover:bg-[#015a96] disabled:opacity-60">{saving ? 'Saving…' : 'Save medication'}</button>
              </form>
            </section>

            <section className="rounded-2xl bg-white p-6 shadow-xl"><h2 className="text-xl font-semibold text-gray-900">Medication list</h2><div className="mt-5 space-y-3">{medications.length === 0 ? <p className="py-6 text-center text-gray-500">No medications recorded for this patient.</p> : medications.map((medication) => <article key={medication.id} className={`rounded-xl border p-4 ${medication.composition.requiresWarning ? 'border-amber-300 bg-amber-50' : 'border-gray-200'}`}><div className="flex flex-wrap items-start justify-between gap-3"><div><h3 className="font-semibold text-gray-900">{medication.originalBrandName} <span className="text-sm font-normal text-gray-500">({medication.purchaseCountry ? countryLabels[medication.purchaseCountry] : 'Country not recorded'})</span></h3><p className="mt-1 text-sm text-gray-700">{medication.composition.ingredients.length ? genericName(medication.composition.ingredients) : 'Generic composition not recorded'}{medication.composition.formulation ? ` · ${medication.composition.formulation}` : ''}</p>{medication.indication && <p className="mt-1 text-sm text-gray-600">For: {medication.indication}</p>}</div><span className={`rounded-full px-2.5 py-1 text-xs font-medium ${medication.isActive ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-700'}`}>{medication.isActive ? 'Active' : 'Past medication'}</span></div>{medication.composition.requiresWarning && <p className="mt-3 text-sm font-medium text-amber-900">Warning: this composition is unconfirmed or requires review. Confirm it from a verified catalogue match before relying on it.</p>}<p className="mt-3 text-sm text-gray-600">{medication.dosage} · {medication.frequency} · {medication.route}</p>{medication.instructions && <p className="mt-1 text-sm text-gray-600">Original instructions: {medication.instructions}</p>}{!medication.isActive && medication.stoppedReason && <p className="mt-1 text-sm text-gray-600">Stopped because: {medication.stoppedReason}</p>}</article>)}</div></section>
          </>}
        </div>
      </main>
    </div>
  );
}
