import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'doctor_dashboard.dart';
import 'family_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final authService = AuthService();

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  bool isLogin = true;

  String selectedRole = "family";

  bool loading = false;

  Future<void> handleAuth() async {
    setState(() {
      loading = true;
    });

    final email =
        emailController.text.trim();

    final password =
        passwordController.text.trim();

    String? error;

    // LOGIN
    if (isLogin) {
      error = await authService.login(
        email: email,
        password: password,
      );

      setState(() {
        loading = false;
      });

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );

        return;
      }

      final role =
          await authService.getUserRole();

      if (!mounted) return;

      // ROLE ROUTING
      if (role == "doctor") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const DoctorDashboard(),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const FamilyDashboard(),
          ),
        );
      }
    }

    // SIGNUP
    else {
      error = await authService.signUp(
        email: email,
        password: password,
        role: selectedRole,
      );

      setState(() {
        loading = false;
      });

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );

        return;
      }

      // FORCE LOGIN AFTER SIGNUP
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Signup successful. Please login.",
          ),
        ),
      );

      setState(() {
        isLogin = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isLogin ? "Login" : "Signup",
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            TextField(
              controller: emailController,

              decoration: const InputDecoration(
                labelText: "Email",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: passwordController,
              obscureText: true,

              decoration: const InputDecoration(
                labelText: "Password",
              ),
            ),

            const SizedBox(height: 20),

            // ROLE DROPDOWN
            if (!isLogin)
              DropdownButton<String>(
                value: selectedRole,

                items: const [
                  DropdownMenuItem(
                    value: "doctor",
                    child: Text("Doctor"),
                  ),

                  DropdownMenuItem(
                    value: "family",
                    child: Text("Family"),
                  ),
                ],

                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed:
                    loading ? null : handleAuth,

                child: loading
                    ? const CircularProgressIndicator()
                    : Text(
                        isLogin
                            ? "Login"
                            : "Signup",
                      ),
              ),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () {
                setState(() {
                  isLogin = !isLogin;
                });
              },

              child: Text(
                isLogin
                    ? "Create Account"
                    : "Already have account?",
              ),
            ),
          ],
        ),
      ),
    );
  }
}