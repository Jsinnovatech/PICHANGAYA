import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    // 1. Crear canal Android
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // 2. Inicializar plugin local
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotif.initialize(initSettings);

    // 3. Pedir permiso al usuario
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    // 4. Registrar handler de background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 5. Mostrar notificación cuando la app está en FOREGROUND
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

  Future<void> _syncToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _enviarTokenAlBackend(token);
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
