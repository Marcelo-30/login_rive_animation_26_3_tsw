import 'package:flutter/material.dart';
import 'package:rive/rive.dart';

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
                  onChanged: (value){
                    if (_isHandsUp != null){
                      _isHandsUp!.change(false);
                    }
                    if (_isChecking== null) return;
                    _isChecking!.change(true);
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
                  onChanged: (value){
                    if (_isChecking != null){
                      _isChecking!.change(false);
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
}