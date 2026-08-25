import { Redirect } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { getToken } from '../lib/session';

export default function Index() {
  const [token, setHasToken] = useState<string | null | undefined>(undefined);

  useEffect(() => {
    void getToken().then(setHasToken);
  }, []);

  if (token === undefined) {
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', backgroundColor: '#f8fafc' }}>
        <ActivityIndicator color="#0175C2" />
      </View>
    );
  }
  return <Redirect href={token ? '/home' : '/sign-in'} />;
}
