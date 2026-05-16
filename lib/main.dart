import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/doctor_dashboard.dart';
import 'screens/family_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zchtgfszevfdnmypfqzq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpjaHRnZnN6ZXZmZG5teXBmcXpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMDk4NzYsImV4cCI6MjA5Mzg4NTg3Nn0.-HGEijLMER7SxTKgQlPbqS8vTxrdC_ZKaxTvhE5TP9g',
  );

  runApp(const PatientApp());
}

class PatientApp extends StatelessWidget {
  const PatientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const RoleSelectionScreen(),
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Dashboard"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const DoctorDashboard(),
                    ),
                  );
                },

                child: const Text(
                  "Doctor Dashboard",
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const FamilyDashboard(),
                    ),
                  );
                },

                child: const Text(
                  "Family Dashboard",
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}