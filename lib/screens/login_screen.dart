import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Control para mostrar u ocultar la contraseña
  bool _isObscure = true;

//1.1 Crear el cerebro de la aniación
  StateMachineController? _controller;

  //1.2 SMI: StateMachineInput
  SMIBool? _isChecking;
  SMIBool? _isHandsUp;
  SMITrigger? _trigSucces;
  SMITrigger? _trigFail;
  SMINumber? _numLook;

  //3.2 timer para detener la mirada al dejar de escribir
  Timer? _typingDebounce;

  //2.1 Crear variables para focusNode
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  //4.1 Controlers para manipular el texto escrito por el usuario
  final emailCtrl= TextEditingController();
  final passCtrl= TextEditingController();

  //4.2 Errores para mostrar UI
  String? emailError;
  String? passError;

   // 4.3 Validadores
  bool isValidEmail(String email) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(email);
  }

  bool isValidPassword(String pass) {
    // mínimo 8, una mayúscula, una minúscula, un dígito y un especial
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');
    return re.hasMatch(pass);
  }

  //4.4 Accion del boton
  void _onLogin(){
    final email= emailCtrl.text.trim();
    final pass= passCtrl.text;

    //Recalcular errores
    final emailTypedError=isValidEmail(email) ? null : 'Email invalido';
    final passwordTypedError=isValidPassword(pass) ? null : 'Contraseña invalido';

    //4.5 Avisar que hubo un cambio
    setState((){
      emailError=emailTypedError;
      passError=passwordTypedError;
    });

    //4.6 Cerrar el teclado
    FocusScope.of(context).unfocus();
    _typingDebounce?.cancel();
    _isChecking?.change(false);
    _isHandsUp?.change(false);
    _numLook?.value=50.0;

    //4.7 Activar triggers
    if(emailTypedError== null && passwordTypedError== null){
      _trigSucces?.fire();
    } else {
      _trigFail?.fire();
    }
  }

  //2.2 Crear los listeners 
@override
  void initState(){
    super.initState();
    _emailFocusNode.addListener((){
if (_emailFocusNode.hasFocus){
  //Verificar que no sea nulo
  if (_isHandsUp != null){
    //Ojos sin cerrar en el eamil
    _isHandsUp?.change(false);
    _numLook?.value=50;
  }
}
    });
    _passwordFocusNode.addListener((){
      //Manos arriba en password
      _isHandsUp?.change(_passwordFocusNode.hasFocus);
    });
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
                    stateMachines: ['Login Machine'],
                    //1.3 Vincular animacion
                    onInit: (artboard) {
                      _controller = StateMachineController.fromArtboard(
                        artboard,
                        'Login Machine',
                      );
                      //1.4 Verificar que inicio bien
                      if (_controller == null) return;

                      //Agregar el controlador al tablero
                      artboard.addController(_controller!);
                      //Vinculamos las variables
                      _isChecking=_controller!.findSMI('isChecking');
                      _isHandsUp=_controller!.findSMI('isHandsUp');
                      _trigSucces=_controller!.findSMI('trigSucces');
                      _trigFail=_controller!.findSMI('trigFail');
                      _numLook=_controller!.findSMI('numLook');
                    },
                  ),
                ),
                const SizedBox(height: 10),
        
                // Email
                TextField(
                  //4.8 Vincular controller
                  controller: emailCtrl,
                  focusNode: _emailFocusNode,
                  onChanged: (value){
                    if (_isHandsUp != null){
                      //_isHandsUp!.change(false);
                    }
                    if (_isChecking== null) return;
                    _isChecking!.change(true);
                    //3.4 Implementar numLook
                    final look=(value.length / 80.0 *100).clamp(0.0, 100.0);
                    _numLook?.value = look;

                    //3.5 Si vuelve a teclear reinicia el contador
                    _typingDebounce = Timer(const Duration(seconds:3),(){
                      //si se cierra la pantalla (!mounted)
                      if (!mounted)return;
                      _isChecking?.change(false);
                    });
                  },
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    //4.9 Mostrar texto de error
                    errorText: emailError,
                    hintText: "Email",
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
        
                // Password
                TextField(
                    //4.8 Vincular controller
                  controller: passCtrl,
                  focusNode: _passwordFocusNode,
                  onChanged: (value){
                    if (_isChecking != null){
                     // _isChecking!.change(false);
                    }
                    if (_isHandsUp== null) return;
                    _isHandsUp!.change(true);
                  },
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    //4.9 Mostrar texto de error
                    errorText: passError,
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock),
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
               SizedBox(height: 10),
               SizedBox(
                width: size.width,
                child: const Text(
                  "Forgot password?",
                  textAlign: TextAlign.right,
                  style: TextStyle(decoration: TextDecoration.underline)),
               ),
               const SizedBox(height: 10),
               MaterialButton(
                minWidth:size.width,
                height: 50,
                color: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                  borderRadius:BorderRadius.circular(12),
                ),
                onPressed: _onLogin,
                child: Text("Login", style: TextStyle(color: Colors.white)),
               ),
               const SizedBox(height: 20),
               SizedBox(
                width: size.width,
                child:Row(children:[
                  const Text("Don't have an accunt?"),
                  TextButton(
                    onPressed:(){},
                    child: const Text(
                      "Register",
                      style: TextStyle(
                        color: Colors.black,
                        decoration:TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ]),
               ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  @override
  void dispose(){
    //4.10 Liberar Controllers
    emailCtrl.dispose();
    passCtrl.dispose();
    //2.4 Liberar recursos
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    _typingDebounce?.cancel;
    super.dispose();
  }
}