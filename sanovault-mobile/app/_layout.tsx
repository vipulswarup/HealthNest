import { Slot, useRouter } from 'expo-router';
import { ShareIntentProvider, useShareIntentContext } from 'expo-share-intent';
import { useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';

function ShareGate() {
  const router = useRouter();
  const { hasShareIntent } = useShareIntentContext();
  useEffect(() => {
    if (hasShareIntent) router.replace('/share');
  }, [hasShareIntent, router]);
  return <Slot />;
}

export default function RootLayout() {
  return (
    <ShareIntentProvider>
      <StatusBar style="dark" />
      <ShareGate />
    </ShareIntentProvider>
  );
}
