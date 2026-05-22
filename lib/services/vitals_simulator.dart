import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class VitalsSimulator {
  Timer? _timer;
  final Random _random = Random();

  int patientId;

  VitalsSimulator({
    required this.patientId,
  });

  void start() {
    _timer = Timer.periodic(
      const Duration(seconds: 8),
      (_) {
        insertRandomVitals();
      },
    );
  }

  void stop() {
    _timer?.cancel();
  }

  Future<void> insertRandomVitals() async {
    final oxygen = 90 + _random.nextInt(10); // 90–99
    final bp = 105 + _random.nextInt(55); // 105–159
    final sugar = 90 + _random.nextInt(210); // 90–299

    try {
      await supabase.from('vitals').insert({
        'patient_id': patientId,
        'oxygen': oxygen,
        'bp': bp,
        'sugar': sugar,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print(
        "Inserted vitals: O2=$oxygen BP=$bp Sugar=$sugar",
      );
    } catch (e) {
      print("Vitals simulator error: $e");
    }
  }
}