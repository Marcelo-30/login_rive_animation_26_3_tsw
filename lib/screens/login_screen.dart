import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:rive/rive.dart';
// Firebase Auth y la pantalla de torneos.
import 'package:firebase_auth/firebase_auth.dart';
import 'tournaments_screen.dart';

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

  // Validar el formato del correo.
  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  // Mínimo 8 caracteres, una minúscula, una mayúscula,
  // un número y un carácter especial.
  bool isValidPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$',
    );

    return re.hasMatch(pass);
  }

//4.4 Dar acción al botón
//5.3 Convertir _onLogin en asíncrono
Future<void> _onLogin() async {
  if (_isLoading) return;

  //4.5 Obtener los valores de los campos
  final email = emailCtrl.text.trim();
  final pass = passCtrl.text;

  //4.6 Evaluar los errores
  final eError = isValidEmail(email) ? null : 'Correo inválido';
  final pError = isValidPassword(pass) ? null : 'Contraseña inválida';

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
  if (eError != null || pError != null) {
    _trigFail?.fire();
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
  } on FirebaseAuthException catch (e) {
    //5.8 Si Firebase rechaza las credenciales
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      passError = 'Credenciales incorrectas en Firebase';
    });

    debugPrint('Firebase Auth error: ${e.code}');
    _trigFail?.fire();
  } catch (e) {
    // Manejar otros errores inesperados
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      passError = 'Ocurrió un error al iniciar sesión';
    });

    debugPrint('Login error: $e');
    _trigFail?.fire();
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
                    errorText: emailError,
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
                    errorText: passError,
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
                  child: const Text(
                    'Forgot password?',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      decoration: TextDecoration.underline,
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
                        onPressed: () {},
                        child: const Text(
                          'Register',
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
