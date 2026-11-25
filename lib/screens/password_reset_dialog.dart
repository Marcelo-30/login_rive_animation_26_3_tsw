import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({super.key, required this.initialEmail});

  final String initialEmail;

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final emailCtrl = TextEditingController(text: widget.initialEmail);
  bool _isLoading = false;

  // Validar el formato del correo.
  bool isValidEmail(String email) {
    final re = RegExp(
      r"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$",
    );
    return re.hasMatch(email) &&
        email.split('@').first.length <= 64 &&
        email.length <= 254;
  }

  Future<void> _sendResetEmail() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailCtrl.text.trim(),
      );
    } on FirebaseAuthException {
      // La misma respuesta evita revelar si hay una cuenta asociada.
    } catch (_) {
      // No mostrar excepciones internas ni confirmar que el correo existe.
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Si existe una cuenta con ese correo, recibirás instrucciones para restablecer tu contraseña.',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_isLoading,
    child: AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: emailCtrl,
          enabled: !_isLoading,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          validator: (value) => isValidEmail((value ?? '').trim())
              ? null
              : 'Escribe un correo válido.',
          onFieldSubmitted: (_) => _sendResetEmail(),
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: const Icon(Icons.email),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _isLoading ? null : _sendResetEmail,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar instrucciones'),
        ),
      ],
    ),
  );
}
