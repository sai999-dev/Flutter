importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCu_A28oTprIh7cdibGpmTRjrbmXbKsYbY",
  authDomain: "leadsmarketplace-21a96.firebaseapp.com",
  projectId: "leadsmarketplace-21a96",
  storageBucket: "leadsmarketplace-21a96.appspot.com",
  messagingSenderId: "695100379940",
  appId: "1:695100379940:web:934baffa63561956c3d9b1",
  measurementId: "G-VEQCV6EJ5T"
});

const messaging = firebase.messaging();

// ✅ FIX: Proper function syntax for service workers
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || "New Notification";
  const notificationOptions = {
    body: payload.notification?.body || "",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    tag: "lead-notification",
    requireInteraction: true
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
