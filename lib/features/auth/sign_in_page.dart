import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({required this.client, super.key});

  final SupabaseClient client;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _message;
  bool _isSuccessMessage = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_isRegistering) {
        final response = await widget.client.auth.signUp(
          email: email,
          password: password,
        );

        if (response.session == null && mounted) {
          setState(() {
            _message =
                'Revisa tu correo para confirmar la cuenta y luego inicia sesión.';
            _isSuccessMessage = true;
          });
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _isSuccessMessage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message =
              'No se pudo conectar. Comprueba tu conexión e inténtalo de nuevo.';
          _isSuccessMessage = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegistering ? 'Crea tu cuenta' : 'Vuelve al desastre';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: DecoratedBox(
                decoration: AppTheme.heroCardDecoration,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          color: AppColors.lime,
                          size: 42,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Jota Parasite',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tu productividad no se va a vigilar sola.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Correo electrónico',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (value) {
                            final email = value?.trim() ?? '';
                            if (!email.contains('@') || email.endsWith('@')) {
                              return 'Escribe un correo válido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: _isRegistering
                              ? const [AutofillHints.newPassword]
                              : const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final password = value ?? '';
                            if (password.length < 8) {
                              return 'Usa al menos 8 caracteres.';
                            }
                            return null;
                          },
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _message!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _isSuccessMessage
                                  ? AppColors.lime
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isRegistering
                                      ? 'Crear cuenta'
                                      : 'Iniciar sesión',
                                ),
                        ),
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => setState(() {
                                  _isRegistering = !_isRegistering;
                                  _message = null;
                                }),
                          child: Text(
                            _isRegistering
                                ? 'Ya tengo cuenta · Iniciar sesión'
                                : '¿Primera vez aquí? Crear cuenta',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
