import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:login_bear_animation/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool isFirebaseConnected = false;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseConnected = true;
    debugPrint('✅ [PHASE 1]: Firebase connection initialized successfully');
  } catch (e) {
    debugPrint('❌ [PHASE 1]: Error initializing Firebase: $e');
  }

  runApp(MyApp(isConnected: isFirebaseConnected));
}

class MyApp extends StatelessWidget {
  final bool isConnected;
  const MyApp({super.key, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login Bear Auth',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Stack(
        children: [
          // Fase 2: Escucha reactiva con delay en login para lucir la animación de Rive
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges().asyncMap((user) async {
              if (user != null) {
                await Future.delayed(const Duration(milliseconds: 2600));
              }
              return user;
            }),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
          // Indicador discreto de Fase 1
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: Chip(
                avatar: Icon(
                  isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: Colors.white,
                  size: 16,
                ),
                label: Text(
                  isConnected ? 'Firebase Ready' : 'Offline',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
                backgroundColor: isConnected ? Colors.green : Colors.red,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home - Rive Auth'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              const Text(
                '¡Sesión Activa!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Conectado como: ${user?.email ?? ""}',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  // Cierre de sesión limpiando estados residuales (Fase 4)
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Cerrar Sesión (Sign Out)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
