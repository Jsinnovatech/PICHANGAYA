// Service Worker para FCM en Flutter Web
// Este archivo DEBE estar en /web/ y usa la versión compat de Firebase

importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey:            "AIzaSyBIBDKwugvWYH9s7A2KYZdq7lboyxNAK_k",
  authDomain:        "pichangaya-6d300.firebaseapp.com",
  projectId:         "pichangaya-6d300",
  storageBucket:     "pichangaya-6d300.firebasestorage.app",
  messagingSenderId: "83990636031",
  appId:             "1:83990636031:web:da3dec3a2653e9de1473ca",
});

const messaging = firebase.messaging();

// Notificaciones cuando el navegador está en BACKGROUND o la pestaña cerrada
messaging.onBackgroundMessage((payload) => {
  console.log("[SW PichangaYa] Mensaje en background:", payload);

  const title = payload.notification?.title ?? "PichangaYa";
  const body  = payload.notification?.body  ?? "";

  self.registration.showNotification(title, {
    body,
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data ?? {},
  });
});
