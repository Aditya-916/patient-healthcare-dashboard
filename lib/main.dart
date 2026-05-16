import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_screen.dart';
import 'screens/doctor_dashboard.dart';
import 'screens/family_dashboard.dart';

final supabase = Supabase.instance.client;

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

  Future<Widget> getInitialScreen() async {
    final user = supabase.auth.currentUser;

    // NOT LOGGED IN
    if (user == null) {
      return const LoginScreen();
    }

    try {
      final response = await supabase
          .from('profiles')
          .select('role')
          .eq('email', user.email!)
          .single();

      final role = response['role'];

      // DOCTOR
      if (role == 'doctor') {
        return const DoctorDashboard();
      }

      // FAMILY
      return const FamilyDashboard();
    } catch (e) {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Patient Dashboard',
      theme: ThemeData.dark(),

      home: FutureBuilder<Widget>(
        future: getInitialScreen(),

        builder: (context, snapshot) {
          // LOADING
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          return snapshot.data!;
        },
      ),
    );
  }
}