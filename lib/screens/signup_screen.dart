import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool _isObscure = true;
  bool _isLoading = false;
  bool _accountCreated = false;

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Escribe tu correo institucional.';
    // La parte local no admite puntos seguidos, iniciales ni finales.
    final re = RegExp(
      r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@tecdesoftware\.edu\.mx$",
    );
    if (!re.hasMatch(email) || email.split('@').first.length > 64) {
      return 'Usa un correo válido que termine en @tecdesoftware.edu.mx.';
    }
    return null;
  }

  // Mínimo 8 caracteres, una minúscula, una mayúscula,
  // un número y un carácter especial.
  bool isValidPassword(String pass) {
    final re = RegExp(
      r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9\s]).{8,}$',
    );
    return re.hasMatch(pass);
  }

  String? _validatePassword(String? value) {
    final pass = value ?? '';
    if (pass.isEmpty) return 'Escribe una contraseña.';
    if (isValidPassword(pass)) return null;
    if (pass.length < 8) return 'Usa al menos 8 caracteres.';
    if (!RegExp(r'[A-Z]').hasMatch(pass)) return 'Incluye una mayúscula.';
    if (!RegExp(r'[a-z]').hasMatch(pass)) return 'Incluye una minúscula.';
    if (!RegExp(r'\d').hasMatch(pass)) return 'Incluye un número.';
    return 'Incluye un símbolo, por ejemplo !, @ o #.';
  }

  Future<void> _onSignUp() async {
    if (_isLoading) return;
    if (!_accountCreated && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      // Si signOut falla, reintentar solo el cierre, sin crear otra cuenta.
      if (!_accountCreated) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text,
        );
        _accountCreated = true;
      }
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _accountCreated = false;
      });
      Navigator.pop(context, true);
    } on FirebaseAuthException {
      _showError();
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _accountCreated
              ? 'La cuenta se creó, pero no se pudo cerrar la sesión. Intenta de nuevo.'
              : 'No se pudo crear la cuenta. Revisa los datos o intenta más tarde.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isLoading && !_accountCreated,
    child: Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: emailCtrl,
                  enabled: !_isLoading && !_accountCreated,
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Correo institucional',
                    hintText: 'usuario@tecdesoftware.edu.mx',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: passCtrl,
                  enabled: !_isLoading && !_accountCreated,
                  validator: _validatePassword,
                  obscureText: _isObscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                      icon: Icon(
                        _isObscure ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'La contraseña debe tener al menos 8 caracteres, una mayúscula, una minúscula, un número y un símbolo.',
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: confirmCtrl,
                  enabled: !_isLoading && !_accountCreated,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirma tu contraseña.';
                    }
                    if (value != passCtrl.text) {
                      return 'Las contraseñas no coinciden.';
                    }
                    return null;
                  },
                  obscureText: _isObscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _onSignUp(),
                  decoration: InputDecoration(
                    labelText: 'Confirmar contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                MaterialButton(
                  height: 50,
                  color: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onPressed: _isLoading ? null : _onSignUp,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _accountCreated
                              ? 'Reintentar cierre de sesión'
                              : 'Crear cuenta',
                          style: const TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
