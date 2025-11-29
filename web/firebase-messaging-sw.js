// Import Firebase scripts
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
// Note: Firebase config is automatically provided by FlutterFire
// The messaging instance will use the config from the main app
firebase.initializeApp({
  apiKey: 'AIzaSyClcHX90Pbwd_JLH_x_z3VU3Ls8-xUN1Yo',
  appId: '1:201166763483:web:73e93f3e12bbc99341e3fe',
  messagingSenderId: '201166763483',
  projectId: 'fleximart-system',
  authDomain: 'fleximart-system.firebaseapp.com',
  storageBucket: 'fleximart-system.firebasestorage.app',
  measurementId: 'G-G3CFDKWNW7',
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  
  const notificationTitle = payload.notification?.title || payload.data?.title || 'FlexiMart';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

