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
                ), // Aquí faltaba cerrar el TextField
              ],
            ),
          ),
        ),
      ),
    );
  }
  @override
  void dispose(){
    //2.4 Liberar recursos
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    _typingDebounce?.cancel;
    super.dispose();
  }
}