import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pichangaya/shared/api/api_client.dart';

/// Handler para mensajes recibidos con la app en BACKGROUND / TERMINADA.
/// DEBE ser una función top-level (fuera de cualquier clase).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // El sistema ya muestra la notificación automáticamente.
  // Aquí solo procesamos data si necesitamos hacer algo en background.
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  // VAPID key leída de dart-define (--dart-define=VAPID_KEY=xxx).
  // El defaultValue solo actúa como fallback en desarrollo local.
  static const String _vapidKey = String.fromEnvironment(
    'VAPID_KEY',
    defaultValue: 'BO-zL00Gw34QLvk5Zh45wQYdjqLFpusN0l2Z3mUX_to-wIUvhGYW6rY9kgEzWy3sdTKKz5zs8T8dR5gd8GxPrWI',
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // Canal Android para notificaciones de alta prioridad
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'pichangaya_alta_prioridad',
    'PichangaYa Notificaciones',
    description: 'Reservas, pagos y suscripciones',
    importance: Importance.high,
  );

  Future<void> init() async {
    // 1. Pedir permiso (funciona en Android, iOS y Web)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    if (kIsWeb) {
      // Web: solo escuchar mensajes en foreground (background lo maneja el SW)
      FirebaseMessaging.onMessage.listen(_mostrarNotifWeb);
      await _syncToken();
      _messaging.onTokenRefresh.listen(_enviarTokenAlBackend);
      return;
    }

    // 2. Crear canal Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 3. Inicializar plugin local
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(initSettings);

    // 4. Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 5. Mostrar notificación cuando la app está en FOREGROUND (Android)
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotif.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Obtener token y enviarlo al backend
    await _syncToken();

    // 7. Actualizar token cuando FCM lo rota
    _messaging.onTokenRefresh.listen(_enviarTokenAlBackend);
  }

  void _mostrarNotifWeb(RemoteMessage message) {
    // En web foreground el navegador no muestra notificaciones automáticamente.
    // El Service Worker las muestra en background.
    // Aquí solo logueamos — puedes mostrar un SnackBar si quieres.
    final n = message.notification;
    if (n != null) {
      // ignore: avoid_print
      print('[FCM Web] ${n.title}: ${n.body}');
    }
  }

  Future<void> _syncToken() async {
    final token = await _messaging.getToken(
      vapidKey: kIsWeb ? _vapidKey : null,
    );
    if (token != null) await _enviarTokenAlBackend(token);
  }

  /// Llama después del login para registrar el token FCM en el backend.
  Future<void> syncToken() async {
    await _syncToken();
  }

  Future<void> _enviarTokenAlBackend(String token) async {
    try {
      await ApiClient().dio.patch(
        '/auth/fcm-token',
        data: {'fcm_token': token},
      );
    } catch (_) {
      // No es crítico — se reintenta en el próximo login o token refresh
    }
  }

  /// Llamar en logout para limpiar el token del backend
  Future<void> limpiarToken() async {
    try {
      await ApiClient().dio.patch(
        '/auth/fcm-token',
        data: {'fcm_token': null},
      );
      await _messaging.deleteToken();
    } catch (_) {}
  }
}
