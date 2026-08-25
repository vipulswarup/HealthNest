import * as Notifications from 'expo-notifications';
import * as Device from 'expo-device';
import { Platform } from 'react-native';
import { api } from './api';

Notifications.setNotificationHandler({
  handleNotification: async () => ({
    shouldShowBanner: true,
    shouldShowList: true,
    shouldPlaySound: true,
    shouldSetBadge: false,
  }),
});

export async function registerPushAndReminders() {
  if (!Device.isDevice) return;
  const existing = await Notifications.getPermissionsAsync();
  let status = existing.status;
  if (status !== 'granted') {
    status = (await Notifications.requestPermissionsAsync()).status;
  }
  if (status !== 'granted') return;

  const token = (await Notifications.getExpoPushTokenAsync()).data;
  await api('/api/devices', {
    method: 'POST',
    body: JSON.stringify({ token, platform: Platform.OS === 'ios' ? 'ios' : 'android' }),
  }).catch(() => undefined);

  await Notifications.cancelAllScheduledNotificationsAsync();
  const hours = [8, 14, 20];
  for (const hour of hours) {
    await Notifications.scheduleNotificationAsync({
      content: {
        title: 'Log blood pressure',
        body: 'Take a reading and save it in SanoVault.',
      },
      trigger: { type: Notifications.SchedulableTriggerInputTypes.DAILY, hour, minute: 0 },
    });
  }
}
