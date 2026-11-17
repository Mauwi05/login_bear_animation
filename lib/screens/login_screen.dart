import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  //Control para mostrar u ocultar la contraseña
  bool _obscure = true;

  //1.1 Crear el cerebro de la animacion
  StateMachineController? _controller;
  //SMT: State Machine Input / Entrada de maquina de estado
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;

  //3.2 Variable del reccorido de la mirada
  SMINumber? _numLook;

  //3.3 Timer para detener la mirada al dejar de escribir
  Timer? _typingDebounce;

  //2.1 Crear las variables para FocusNode
  final _emailFocus =
      FocusNode(); //Se llama node por un foco de cosas que puede hacer
  final _passWordFocus = FocusNode();

  //4.1 Controllers que manipulan lo que el ussuario escribe
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  //4.2 Errores para mostrarlo en la UI
  String? emailError;
  String? passError;

  //Toggle / checkbox para "Recordarme"
  bool _rememberMe = false;

  //4.16 Anti-spam: bloquea el boton mientras la animacion se reproduce
  bool _isBusy = false;
  //4.16.1 Ya entramos a la animacion de resultado (exito/fallo)
  bool _animationStarted = false;
  //4.17 Timer de seguridad: libera el bloqueo si Rive nunca reporta el fin
  Timer? _busySafetyTimer;

  // Estados de la "Login Machine" que reproducen el resultado del login
  static const Set<String> _resultStateNames = {'success', 'fail', 'success9', 'fail9'};
  // Reducimos el tiempo máximo de bloqueo de 5s a 2s para que sea fluido
  static const Duration _maxBusyLock = Duration(seconds: 2);

  //4.3 Validadores
  bool isValidEmail(String email) {
    //Expresion regular para validar el correo
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  bool isValidPassword(String pass) {
    //Expresion regular para validar la contraseña
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );
    return re.hasMatch(pass);
  }

  // Función auxiliar que garantiza que Rive reciba el trigger ya sea que esté en idle o bajando las manos
  Future<void> _fireTriggerSafely(SMITrigger? trigger) async {
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    // Primer disparo rápido (por si ya tenía las manos abajo)
    await Future.delayed(const Duration(milliseconds: 250));
    trigger?.fire();
    // Segundo disparo cuando termina la animación de bajar las manos (hands_down dura ~800ms)
    await Future.delayed(const Duration(milliseconds: 700));
    trigger?.fire();
  }

  //4.4 Dar accion al boton con Firebase Auth (Fase 2)
  Future<void> _onLogin() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      emailError = null;
      passError = null;
    });
    _busySafetyTimer?.cancel();
    _busySafetyTimer = Timer(_maxBusyLock, _releaseBusy);

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    final eError = isValidEmail(email) ? null : "Formato de correo inválido";
    final pError = isValidPassword(pass)
        ? null
        : "Mín. 8 caracteres, 1 mayúscula, 1 número y 1 símbolo";

    // Quitar foco y forzar manos abajo inmediatamente
    FocusManager.instance.primaryFocus?.unfocus();
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value = 50.0;

    if (eError != null || pError != null) {
      setState(() {
        emailError = eError;
        passError = pError;
      });
      await _fireTriggerSafely(_trigFail);
      return;
    }

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pass,
      );

      // Éxito: dispara celebración garantizada
      await _fireTriggerSafely(_trigSuccess);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Autenticación exitosa!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al iniciar sesión';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        msg = 'Correo o contraseña incorrectos';
      } else if (e.code == 'wrong-password') {
        msg = 'Contraseña incorrecta';
      } else if (e.code == 'too-many-requests') {
        msg = 'Demasiados intentos. Intenta más tarde';
      }
      setState(() {
        passError = msg;
      });
      await _fireTriggerSafely(_trigFail);
    } catch (e) {
      setState(() {
        passError = 'Ocurrió un error inesperado';
      });
      await _fireTriggerSafely(_trigFail);
    }
  }

  //4.4.4 Rive avisa cuando la maquina de estados cambia de animacion
  void _onRiveStateChange(String stateMachineName, String stateName) {
    //Si entro a la animacion de resultado, seguimos bloqueados
    if (_resultStateNames.contains(stateName)) {
      _animationStarted = true;
      return;
    }
    //La animacion de resultado empezo y ya salio => terminamos
    if (_animationStarted) {
      _releaseBusy();
    }
  }

  //4.4.5 Quitar el bloqueo y rehabilitar el boton
  void _releaseBusy() {
    _busySafetyTimer?.cancel();
    _busySafetyTimer = null;
    _animationStarted = false;
    if (!mounted) return;
    if (!_isBusy) return;
    setState(() {
      _isBusy = false;
    });
  }

  //2.2 Listeners (Oyentes/chismosos) para saber cuando el usuario esta escribiendo en el campo de texto
  @override
  void initState() {
    super.initState();
    super.initState();
    _emailFocus.addListener(() {
      if (_emailFocus.hasFocus) {
        //Verificar que no sea nulo
        if (_isHandsUp != null) {
          //Manos abajo en el email
          _isHandsUp!.change(false);
          //3.4 Mirada neutra
          _numLook?.value = 50.0;
        }
      }
    });
    _passWordFocus.addListener(() {
      //Manos arriba en el password
      _isHandsUp!.change(_passWordFocus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    //Para obtener el tamaño de la pantalla
    final Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: size.width,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear.riv',
                    stateMachines: ['Login Machine'],
                    //1.2 Vincular Animacion
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                        //4.4.6 Avisar cuando la maquina de estados cambia
                        onStateChange: _onRiveStateChange,
                      );

                      //1.3 Verificar que el controlador no sea nulo
                      if (_controller == null) return;
                      //Agrega el controlador al escenario/tablero
                      artboard.addController(_controller!);
                      //Vinculamos variables
                      _isChecking = _controller?.findSMI('isChecking');
                      _isHandsUp = _controller?.findSMI('isHandsUp');
                      _trigSuccess = _controller?.findSMI('trigSuccess');
                      _trigFail = _controller?.findSMI('trigFail');
                      //3.5 Vincular numLook
                      _numLook = _controller?.findSMI('numLook');
                    },
                  ),
                ),
                //Sizedbox para separar espacios
                SizedBox(height: 10),
                //Campo de texto para el correo
                TextField(
                  //4.10 Enlazar controller
                  controller: _emailCtrl,
                  //2.3 Asigna el foco al campo de texto
                  focusNode: _emailFocus,
                  onChanged: (value) {
                    if (_isHandsUp != null) {
                      //No tapes los ojos al ver email
                      //_isHandsUp!.change(false);
                    }
                    //Si isChecking no es nulo, cambiar el valor de la variable
                    if (_isChecking != null) {
                      //Activar modo chismoso
                      _isChecking!.change(true);

                      //3.6 Implementar numLook
                      //Ajustes de límites del 0 al 100
                      //80 es la medida de calibración para mirar al email
                      final look = (value.length / 80.0 * 100.0).clamp(
                        0.0,
                        100.0,
                      );
                      //clamp es el rango (abrazadera) para que no se pase de 0 a 100
                      _numLook?.value = look;

                      //3.7 Debouce: si vuelve a teclear, reinicia el contador
                      //Cancelar cualquier timer existente
                      _typingDebounce?.cancel();
                      //crear un nuevo timer
                      _typingDebounce = Timer(const Duration(seconds: 3), () {
                        //Si se cierra la pantalla, quita el contador
                        if (!mounted) return;
                        //Mirada neutra
                        _isChecking?.change(false);
                      });
                    }
                  },
                  //para mostrar el tipo de teclado
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    //4.11 Mostrar errores
                    errorText: emailError,
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      //Redondeo de bordes
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                //Campo de texto para la contraseña
                TextField(
                  //4.10 Enlazar controller
                  controller: _passCtrl,
                  //2.3 Asigna el foco al campo de texto
                  focusNode: _passWordFocus,
                  onChanged: (value) {
                    if (_isChecking != null) {
                      //No tapes los ojos al ver email
                      _isChecking!.change(false);
                    }
                    //Si isChecking no es nulo, cambiar el valor de la variable
                    if (_isHandsUp != null) {
                      //Activar modo chismoso
                      _isHandsUp!.change(true);
                    }
                  },
                  obscureText: _obscure,
                  //para mostrar el tipo de teclado
                  decoration: InputDecoration(
                    //4.11 Mostrar errores
                    errorText: passError,
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    //Operador ternario
                    suffixIcon: IconButton(
                      //If ternario
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        //Refrescar el estado del widget
                        setState(() {
                          _obscure = !_obscure;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      //Redondeo de bordes
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                //4.12 "Recordarme" a la izquierda y "Olvide mi contraseña" a la derecha
                SizedBox(
                  width: size.width,
                  child: Row(
                    children: [
                      //Recordarme: checkbox
                      InkWell(
                        onTap: () {
                          setState(() {
                            _rememberMe = !_rememberMe;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                //Compensa el margen interno del checkbox
                                //para alinearlo opticamente con el texto
                                offset: const Offset(-6, 0),
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (value) {
                                      setState(() {
                                        _rememberMe = value ?? false;
                                      });
                                    },
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Recordarme',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Olvide mi contraseña',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                //4.13 Boton de login (bloqueado mientras hay animacion)
                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.deepPurple,
                  disabledColor: Colors.deepPurple.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  //4.13.1 null = sin interaccion mientras esta ocupado
                  onPressed: _isBusy ? null : _onLogin,
                  child: Text(
                    _isBusy ? 'Procesando...' : 'Login',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 10),
                //4.14 Boton de registro
                SizedBox(
                  width: size.width,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.black,
                            //subrayado
                            decoration: TextDecoration.underline,
                            //Negritas
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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
    //4.15 Liberar los controladores
    _emailCtrl.dispose();
    _passCtrl.dispose();
    //2.4 Liberar memoria al salir de la pantalla para liberar el foco
    _emailFocus.dispose();
    _passWordFocus.dispose();
    _typingDebounce?.cancel(); //3.8  Cancelar el timer al salir de la pantalla
    _busySafetyTimer?.cancel(); //4.17 Cancelar el timer de bloqueo
    super.dispose();
  }
}
