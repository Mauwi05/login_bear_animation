import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  StateMachineController? _controller;
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  Timer? _typingDebounce;

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmPassFocus = FocusNode();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String? nameError;
  String? emailError;
  String? passError;
  String? confirmPassError;

  bool _isBusy = false;

  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  bool isValidPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );
    return re.hasMatch(pass);
  }

  Future<void> _fireTriggerSafely(SMITrigger? trigger) async {
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    await Future.delayed(const Duration(milliseconds: 250));
    trigger?.fire();
    await Future.delayed(const Duration(milliseconds: 700));
    trigger?.fire();
  }

  Future<void> _onRegister() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      nameError = null;
      emailError = null;
      passError = null;
      confirmPassError = null;
    });

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    final nError = name.isNotEmpty ? null : "Ingresa tu nombre completo";
    final eError = isValidEmail(email) ? null : "Formato de correo inválido";
    final pError = isValidPassword(pass)
        ? null
        : "Mín. 8 caracteres, 1 mayúscula, 1 minúscula, 1 número y 1 símbolo";
    final cError = (pass == confirmPass && confirmPass.isNotEmpty)
        ? null
        : "Las contraseñas no coinciden";

    FocusManager.instance.primaryFocus?.unfocus();
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    if (nError != null || eError != null || pError != null || cError != null) {
      setState(() {
        nameError = nError;
        emailError = eError;
        passError = pError;
        confirmPassError = cError;
        _isBusy = false;
      });
      await _fireTriggerSafely(_trigFail);
      return;
    }

    try {
      // Crear el usuario en Firebase Authentication (Requisito Fase 3)
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      // Guardar el nombre en el perfil del usuario de Firebase
      await credential.user?.updateDisplayName(name);

      await _fireTriggerSafely(_trigSuccess);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Cuenta creada exitosamente! Redirigiendo...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Esperar a que luzca la animación de éxito y cerrar esta pantalla
      // El StreamBuilder de main.dart mostrará automáticamente el HomeScreen
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al registrar usuario';
      if (e.code == 'email-already-in-use') {
        msg = 'Este correo ya está registrado';
      } else if (e.code == 'weak-password') {
        msg = 'La contraseña es muy débil';
      } else if (e.code == 'invalid-email') {
        msg = 'El correo no es válido';
      }
      setState(() {
        emailError = msg;
        _isBusy = false;
      });
      await _fireTriggerSafely(_trigFail);
    } catch (e) {
      setState(() {
        emailError = 'Ocurrió un error inesperado';
        _isBusy = false;
      });
      await _fireTriggerSafely(_trigFail);
    }
  }

  @override
  void initState() {
    super.initState();
    void onTextFieldFocus() {
      if (_nameFocus.hasFocus || _emailFocus.hasFocus) {
        _isHandsUp?.change(false);
        _numLook?.value = 50.0;
      }
    }

    _nameFocus.addListener(onTextFieldFocus);
    _emailFocus.addListener(onTextFieldFocus);

    void onPasswordFocus() {
      _isHandsUp?.change(_passFocus.hasFocus || _confirmPassFocus.hasFocus);
    }

    _passFocus.addListener(onPasswordFocus);
    _confirmPassFocus.addListener(onPasswordFocus);
  }

  void _onLookTyping(String value) {
    if (_isChecking != null) {
      _isChecking!.change(true);
      final look = (value.length / 80.0 * 100.0).clamp(0.0, 100.0);
      _numLook?.value = look;
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _isChecking?.change(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta (Sign Up)'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: size.width,
                  height: 180,
                  child: RiveAnimation.asset(
                    'assets/login-bear.riv',
                    stateMachines: const ['Login Machine'],
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );
                      if (_controller == null) return;
                      artboard.addController(_controller!);
                      _isChecking = _controller?.findSMI('isChecking');
                      _isHandsUp = _controller?.findSMI('isHandsUp');
                      _trigSuccess = _controller?.findSMI('trigSuccess');
                      _trigFail = _controller?.findSMI('trigFail');
                      _numLook = _controller?.findSMI('numLook');
                    },
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameCtrl,
                  focusNode: _nameFocus,
                  onChanged: _onLookTyping,
                  decoration: InputDecoration(
                    errorText: nameError,
                    hintText: 'Nombre completo',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailCtrl,
                  focusNode: _emailFocus,
                  onChanged: _onLookTyping,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    errorText: emailError,
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _passCtrl,
                  focusNode: _passFocus,
                  obscureText: _obscurePass,
                  onChanged: (_) {
                    _isChecking?.change(false);
                    _isHandsUp?.change(true);
                  },
                  decoration: InputDecoration(
                    errorText: passError,
                    hintText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePass = !_obscurePass;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPassCtrl,
                  focusNode: _confirmPassFocus,
                  obscureText: _obscureConfirm,
                  onChanged: (_) {
                    _isChecking?.change(false);
                    _isHandsUp?.change(true);
                  },
                  decoration: InputDecoration(
                    errorText: confirmPassError,
                    hintText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.deepPurple,
                  disabledColor: Colors.deepPurple.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _isBusy ? null : _onRegister,
                  child: Text(
                    _isBusy ? 'Registrando...' : 'Sign Up',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Already have an account?"),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Log In',
                        style: TextStyle(
                          color: Colors.black,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmPassFocus.dispose();
    _typingDebounce?.cancel();
    super.dispose();
  }
}
