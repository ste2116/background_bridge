// ======  IMPORT  ======
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
// ======================

// =========  GESTIONE PERMESSI  ==========
Future<void> requestAllPerms() async {
  // Permessi base (Android 14 in debug basta “Allow all the time”)
  await Permission.location.request();
  await Permission.locationAlways.request();
  await Permission.notification.request();
}
// ========================================

// =========  SERVIZIO BACKGROUND  =========
@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  Timer? timer;

  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: 'Bike Ride – registrazione attiva',
      content: 'Tap per tornare all\'app',
    );
  }

  timer = Timer.periodic(const Duration(seconds: 3), (_) async {
    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList('bg_track') ?? <String>[];
      list.add('${p.latitude},${p.longitude},${p.timestamp?.toIso8601String()}');
      await sp.setStringList('bg_track', list);
    } catch (_) {}
  });

  service.on('stop').listen((_) {
    timer?.cancel();
    service.stopSelf();
  });
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: (i) async {
        await onStart(i);
        return true;
      },
    ),
  );
}

Future<void> startBgService() async {
  await initializeService();
  await FlutterBackgroundService().startService();
}

Future<void> stopBgService() async {
  FlutterBackgroundService().invoke('stop');
}
// ======================================

// =========  UI MINIMA  ===============
void main() => runApp(const DummyApp());

class DummyApp extends StatelessWidget {
  const DummyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Bike Ride – Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Servizio in background attivo'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await requestAllPerms();
                  await startBgService();
                },
                child: const Text('AVVIA TRACKING'),
              ),
              ElevatedButton(
                onPressed: stopBgService,
                child: const Text('FERMA TRACKING'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}