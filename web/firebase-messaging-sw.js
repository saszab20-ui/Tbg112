importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.5/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBX-G5qZmy1zT3C7Y7Tpg_9dEeZZKItChw',
  authDomain: 'tarnobrzeg-112.firebaseapp.com',
  projectId: 'tarnobrzeg-112',
  storageBucket: 'tarnobrzeg-112.firebasestorage.app',
  messagingSenderId: '305918132110',
  appId: '1:305918132110:web:6bc2e412bd4a76bcf3aedf',
  measurementId: 'G-2JXZPFWX58',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};
  const title = notification.title || 'Tarnobrzeg 112';
  const options = {
    body: notification.body || 'Nowe powiadomienie',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data,
  };

  self.registration.showNotification(title, options);
});
