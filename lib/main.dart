import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Stack(
        children: [
          const LoginScreen(),
          // Indicador visual discreto que pide el Criterio de Éxito de la Fase 1
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
