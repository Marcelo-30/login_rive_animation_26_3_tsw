import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:rive/rive.dart';
// Firebase Auth y la pantalla de torneos.
import 'package:firebase_auth/firebase_auth.dart';
import 'tournaments_screen.dart';
import 'signup_screen.dart';
import 'password_reset_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Mostrar u ocultar la contraseña.
  bool _isObscure = true;

  // Controlador de la animación.
  StateMachineController? _controller;

  // Inputs de Rive.
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSuccess;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  // Temporizador para detener la mirada al dejar de escribir.
  Timer? _typingDebounce;

  // Control del foco.
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  // Controladores de texto.
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  // Mensajes de error.
  String? emailError;
  String? passError;

   //5.2 Variable para mostrar el CircularProgressIndicator mientras carga
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) {
        _isHandsUp?.change(false);
        _numLook?.value = 50.0;
      } else {
        _typingDebounce?.cancel();
        _isChecking?.change(false);
      }
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        _typingDebounce?.cancel();
        _isChecking?.change(false);
      }

      _isHandsUp?.change(_passwordFocusNode.hasFocus);
    });
  }

  // Vincular los inputs del archivo Rive.
  void _onRiveInit(Artboard artboard) {
    final controller = StateMachineController.fromArtboard(
      artboard,
      'Login Machine',
    );

    if (controller == null) {
      debugPrint('No se encontró la máquina "Login Machine".');
      return;
    }

    _controller = controller;
    artboard.addController(controller);

    _isChecking = controller.findSMI<SMIBool>('isChecking');
    _isHandsUp = controller.findSMI<SMIBool>('isHandsUp');
    _trigSuccess = controller.findSMI<SMITrigger>('trigSuccess');
    _trigFail = controller.findSMI<SMITrigger>('trigFail');
    _numLook = controller.findSMI<SMINumber>('numLook');

    if (_trigSuccess == null) {
      debugPrint('No se encontró el trigger "trigSuccess".');

      for (final input in controller.inputs) {
        debugPrint('Input disponible: ${input.name}');
      }
    }
  }

//4.4 Dar acción al botón
//5.3 Convertir _onLogin en asíncrono
Future<void> _onLogin() async {
  if (_isLoading) return;

  //4.5 Obtener los valores de los campos
  final email = emailCtrl.text.trim();
  final pass = passCtrl.text;

  //4.6 Evaluar los errores
  final eError = email.isEmpty ? 'Escribe tu correo.' : null;
  final pError = pass.isEmpty ? 'Escribe tu contraseña.' : null;

  //4.7 Actualizar los mensajes de error
  setState(() {
    emailError = eError;
    passError = pError;
  });

  //4.8 Cerrar el teclado y bajar las manos del osito
  FocusScope.of(context).unfocus();
  _typingDebounce?.cancel();
  _isChecking?.change(false);
  _isHandsUp?.change(false);
  _numLook?.value = 50.0;

  //4.9 Si algún campo es inválido, activar fallo y detener
  if (emailError != null || passError != null) {
    _trigFail?.fire();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Escribe tu correo y contraseña.')),
    );
    return;
  }

  //5.4 Activar el CircularProgressIndicator
  setState(() {
    _isLoading = true;
  });

  try {
    //5.5 Autenticar usuario en Firebase
    await Future.delayed(const Duration(seconds: 2));

    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: pass,
    );

    if (!mounted) return;

    //5.6 Apagar loading, celebrar y esperar la animación
    setState(() {
      _isLoading = false;
    });

    _trigSuccess?.fire();

    await Future.delayed(const Duration(seconds: 2));

    // Navegar a los torneos después de autenticar y celebrar con Rive.
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const TournamentsScreen(),
      ),
    );
  } on FirebaseAuthException {
    //5.8 Si Firebase rechaza las credenciales
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    _trigFail?.fire();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credenciales inválidas')),
    );
  } catch (_) {
    // Manejar otros errores inesperados
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    _trigFail?.fire();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Credenciales inválidas')),
    );
  }
}

  // Seguir con la mirada el texto del correo.
  void _onEmailChanged(String value) {
    _typingDebounce?.cancel();

    _isHandsUp?.change(false);
    _isChecking?.change(true);

    final look = (value.length / 80.0 * 100)
        .clamp(0.0, 100.0)
        .toDouble();

    _numLook?.value = look;

    _typingDebounce = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        _isChecking?.change(false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: SingleChildScrollView(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                SizedBox(
                  width: size.width,
                  height: 200,
                  child: RiveAnimation.asset(
                    'assets/login-bear-animation.riv',
                    onInit: _onRiveInit,
                  ),
                ),
                const SizedBox(height: 10),

                // Email.
                TextField(
                  controller: emailCtrl,
                  focusNode: _emailFocusNode,
                  onChanged: _onEmailChanged,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) {
                    _passwordFocusNode.requestFocus();
                  },
                  decoration: InputDecoration(
                    hintText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Password.
                TextField(
                  controller: passCtrl,
                  focusNode: _passwordFocusNode,
                  onChanged: (_) {
                    _typingDebounce?.cancel();
                    _isChecking?.change(false);
                    _isHandsUp?.change(true);
                  },
                  obscureText: _isObscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onLogin(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscure
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscure = !_isObscure;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: size.width,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerRight,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _isLoading
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => PasswordResetDialog(
                              initialEmail: emailCtrl.text.trim(),
                            ),
                          ),
                    child: const Text(
                      'Forgot password?',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                MaterialButton(
                  minWidth: size.width,
                  height: 50,
                  color: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _onLogin,
                  //5.9 Mostrar CircularProgressIndicator si está cargando, o el texto Login
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Login',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: size.width,
                  child: Row(
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final registered = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignUpScreen(),
                                  ),
                                );
                                if (!context.mounted || registered != true) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text(
                                    'Cuenta creada. Ya puedes iniciar sesión.',
                                  )),
                                );
                              },
                        child: const Text(
                          'Sign up',
                          style: TextStyle(
                            color: Colors.black,
                            decoration: TextDecoration.underline,
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
    _typingDebounce?.cancel();

    emailCtrl.dispose();
    passCtrl.dispose();

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    _controller?.dispose();

    super.dispose();
  }
}
