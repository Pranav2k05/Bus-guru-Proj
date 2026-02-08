// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'passenger_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool loading = false;

  Future<void> _register() async {
    setState(() => loading = true);
    final res = await ApiService.post('user/register', {
      'name': 'Demo User',
      'email': _email.text,
      'password': _password.text
    });
    setState(() => loading = false);
    if (res != null && res['status'] == 'ok') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registered — now login')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Register failed: ${res ?? 'error'}')));
    }
  }

  Future<void> _login() async {
    setState(() => loading = true);
    final res = await ApiService.post('user/login', {
      'email': _email.text,
      'password': _password.text
    });
    setState(() => loading = false);
    if (res != null && res['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', res['token']);
      await prefs.setInt('user_id', res['user']['id']);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PassengerDashboard()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Welcome to Bus-Guru', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 8),
                TextField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 16),
                loading ? const CircularProgressIndicator() : Row(children: [
                  Expanded(child: ElevatedButton(onPressed: _login, child: const Text('Login'))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton(onPressed: _register, child: const Text('Register')))
                ])
              ]),
            ),
          ),
        ),
      )),
    );
  }
}
