import { Tabs } from 'expo-router';

export default function TabsLayout() {
  return (
    <Tabs screenOptions={{ headerTitleStyle: { fontWeight: '600' }, tabBarActiveTintColor: '#0175C2' }}>
      <Tabs.Screen name="home" options={{ title: 'Home' }} />
      <Tabs.Screen name="add" options={{ title: 'Add' }} />
      <Tabs.Screen name="doctor" options={{ title: 'For the doctor' }} />
      <Tabs.Screen name="bp" options={{ title: 'BP' }} />
      <Tabs.Screen name="meds" options={{ title: 'Medicines' }} />
    </Tabs>
  );
}
