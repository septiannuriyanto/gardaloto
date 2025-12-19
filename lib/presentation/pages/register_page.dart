import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:go_router/go_router.dart';

class RegisterPage extends StatefulWidget {
  final String? initialNrp;
  const RegisterPage({super.key, this.initialNrp});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _nrpCtrl = TextEditingController();
  final TextEditingController _sidCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialNrp != null) {
      _nrpCtrl.text = widget.initialNrp!;
    }
  }

  @override
  void dispose() {
    _nrpCtrl.dispose();
    _sidCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _onRegister() {
    final nrp = _nrpCtrl.text.trim();
    final sidCode = _sidCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim().toUpperCase();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;
    final confirmPassword = _confirmPasswordCtrl.text;

    if (nrp.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields (SID Code is optional)')),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    context.read<AuthCubit>().register(
          nrp: nrp,
          name: name,
          email: email,
          password: password,
          sidCode: sidCode.isEmpty ? null : sidCode,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => context.go('/'), // Back to Login
          ),
          title: const Text("Register Account", style: TextStyle(color: Colors.white)),
        ),
        body: AppBackground(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 400,
                child: BlocConsumer<AuthCubit, AuthState>(
                  listener: (context, state) {
                    if (state is AuthRegistered) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Registration successful. Please wait for activation.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                       context.go('/');
                    }
                    if (state is AuthAuthenticated) {
                       // Should not happen for new registration ideally, but keeping as fallback if flow changes
                       context.go('/dashboard');
                    }
                    if (state is AuthError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is AuthLoading) {
                      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                    }
                    return GlassPanel(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTextField("NRP", _nrpCtrl, icon: Icons.badge),
                            const SizedBox(height: 16),
                            _buildTextField("SID Code", _sidCtrl, icon: Icons.qr_code, textCapitalization: TextCapitalization.characters),
                            const SizedBox(height: 16),
                            _buildTextField("Full Name (Uppercase)", _nameCtrl, icon: Icons.person, textCapitalization: TextCapitalization.characters),
                            const SizedBox(height: 16),
                            _buildTextField("Email", _emailCtrl, icon: Icons.email),
                            const SizedBox(height: 16),
                            _buildTextField("Password", _passwordCtrl, icon: Icons.lock, obscureText: true),
                            const SizedBox(height: 16),
                            _buildTextField("Confirm Password", _confirmPasswordCtrl, icon: Icons.lock_outline, obscureText: true),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _onRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text("SUBMIT", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            )
                          ],
                        ));
                  },
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildTextField(String label, TextEditingController ctrl,
      {IconData? icon, bool obscureText = false, TextCapitalization textCapitalization = TextCapitalization.none}) {
    return TextField(
      controller: ctrl,
      obscureText: obscureText,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: icon != null ? Icon(icon, color: Colors.white70) : null,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.cyanAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}
