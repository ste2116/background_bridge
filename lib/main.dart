// ======  SERVIZIO BACKGROUND  ======
library background_bridge;

import 'dart:async';
import 'dart:isolate';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry-point isolato per il servizio
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

/// Avvia il servizio di tracking
Future<void> startBgService() async {
  await initializeService();
  await FlutterBackgroundService().startService();
}

/// Ferma il servizio di tracking
Future<void> stopBgService() async {
  FlutterBackgroundService().invoke('stop');
}
// ======================================