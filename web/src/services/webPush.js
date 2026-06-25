import api from './api';

function base64UrlToUint8Array(base64UrlString) {
  const padding = '='.repeat((4 - (base64UrlString.length % 4)) % 4);
  const base64 = (base64UrlString + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = window.atob(base64);
  return Uint8Array.from(raw, (char) => char.charCodeAt(0));
}

export async function enableWebPushNotifications() {
  if (!('serviceWorker' in navigator)) {
    throw new Error('Browser ini tidak mendukung service worker');
  }
  if (!('PushManager' in window)) {
    throw new Error('Browser ini tidak mendukung Web Push');
  }
  if (!('Notification' in window)) {
    throw new Error('Browser ini tidak mendukung notifikasi');
  }

  const permission = await window.Notification.requestPermission();
  if (permission !== 'granted') {
    throw new Error('Izin notifikasi tidak diberikan');
  }

  const registration = await navigator.serviceWorker.register('/push-sw.js', {
    scope: '/',
  });

  const { public_key: publicKey } = await api.getPushPublicKey();
  if (!publicKey) {
    throw new Error('Public key push belum tersedia');
  }

  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    subscription = await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: base64UrlToUint8Array(publicKey),
    });
  }

  await api.subscribePush(subscription.toJSON());
  return subscription;
}

export async function disableWebPushNotifications() {
  if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
    return false;
  }

  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    return false;
  }

  try {
    await api.unsubscribePush(subscription.endpoint);
  } catch (_) {
    // Ignore API failures during local cleanup.
  }

  return subscription.unsubscribe();
}
