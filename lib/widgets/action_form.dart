import 'package:material_ui/material_ui.dart';

class FormInput {
  const FormInput(
    this.name,
    this.label, {
    this.initialValue = '',
    this.maxLength = 255,
    this.optional = false,
    this.numeric = false,
    this.choices,
    this.validate,
    this.hint,
  });

  final String name;
  final String label;
  final String initialValue;
  final int maxLength;
  final bool optional;
  final bool numeric;
  final Map<String, String>? choices;
  final String? Function(String)? validate;
  final String? hint;
}

Future<bool> showActionForm(
  BuildContext context, {
  required String title,
  required Future<void> Function(Map<String, String>) submit,
  List<FormInput> inputs = const [],
  String? description,
  String submitLabel = 'Guardar',
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ActionForm(
        title: title,
        submit: submit,
        inputs: inputs,
        description: description,
        submitLabel: submitLabel,
      ),
    ) ??
    false;

class _ActionForm extends StatefulWidget {
  const _ActionForm({
    required this.title,
    required this.submit,
    required this.inputs,
    required this.description,
    required this.submitLabel,
  });

  final String title;
  final Future<void> Function(Map<String, String>) submit;
  final List<FormInput> inputs;
  final String? description;
  final String submitLabel;

  @override
  State<_ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<_ActionForm> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _values = {};
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_values);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  String? _validate(FormInput input, String? text) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) {
      return input.optional ? null : 'Este campo es obligatorio.';
    }
    if (input.numeric && int.tryParse(value) == null) {
      return 'Introduce un número entero.';
    }
    return input.validate?.call(value);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.description != null) Text(widget.description!),
                for (final input in widget.inputs)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: input.choices != null
                        ? DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(labelText: input.label),
                            items: input.choices!.entries
                                .map(
                                  (entry) => DropdownMenuItem(
                                    value: entry.key,
                                    child: Text(entry.value),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy ? null : (_) {},
                            validator: (value) => _validate(input, value),
                            onSaved: (value) =>
                                _values[input.name] = value ?? '',
                          )
                        : TextFormField(
                            initialValue: input.initialValue,
                            enabled: !_busy,
                            maxLength: input.maxLength,
                            keyboardType: input.numeric
                                ? TextInputType.number
                                : TextInputType.text,
                            decoration: InputDecoration(
                              labelText: input.label,
                              hintText: input.hint,
                            ),
                            validator: (value) => _validate(input, value),
                            onSaved: (value) =>
                                _values[input.name] = value?.trim() ?? '',
                          ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: _busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.submitLabel),
        ),
      ],
    ),
  );
}
