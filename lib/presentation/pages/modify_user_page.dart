import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/core/time_helper.dart';
import 'package:gardaloto/domain/entities/incumbent_entity.dart';
import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:go_router/go_router.dart';

class ModifyUserPage extends StatefulWidget {
  final UserEntity user;

  const ModifyUserPage({super.key, required this.user});

  @override
  State<ModifyUserPage> createState() => _ModifyUserPageState();
}

class _ModifyUserPageState extends State<ModifyUserPage> {
  late TextEditingController _nrpCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _sidCtrl;
  late TextEditingController _sectionCtrl;

  int? _selectedPosition;
  List<IncumbentEntity> _incumbents = [];
  bool _isLoadingIncumbents = true;

  @override
  void initState() {
    super.initState();
    _nrpCtrl = TextEditingController(text: widget.user.nrp);
    _nameCtrl = TextEditingController(text: widget.user.nama);
    _emailCtrl = TextEditingController(text: widget.user.email);
    _sidCtrl = TextEditingController(text: widget.user.sidCode);
    _sectionCtrl = TextEditingController(text: widget.user.section);
    _selectedPosition = widget.user.position;

    _loadIncumbents();
  }

  Future<void> _loadIncumbents() async {
    try {
      final list = await context.read<ManpowerCubit>().getIncumbents();
      setState(() {
        _incumbents = list;
        _isLoadingIncumbents = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingIncumbents = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading positions: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nrpCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _sidCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  void _onSubmit() {
    final name = _nameCtrl.text.trim().toUpperCase();
    final email = _emailCtrl.text.trim().toLowerCase();
    final sidCode = _sidCtrl.text.trim().toUpperCase();
    final section = _sectionCtrl.text.trim().toUpperCase();

    // Verification
    if (name.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and Email are required')),
      );
      return;
    }

    final bool isInactive = widget.user.active == false;
    final bool activateUser =
        isInactive; // If inactive, button implies activation

    // Create updated user
    // We create a new UserEntity with updated fields
    // NOTE: If activating, set active = true.
    final updatedUser = UserEntity(
      id: widget.user.id,
      email: email,
      nrp: widget.user.nrp,
      nama: name,
      sidCode: sidCode.isEmpty ? null : sidCode,
      section: section.isEmpty ? null : section,
      position: _selectedPosition,
      active: activateUser ? true : widget.user.active,
      registered: widget.user.registered,
      updatedAt: TimeHelper.now(), // Optimistic update
      // Preserve others
      photoUrl: widget.user.photoUrl,
      bgPhotoUrl: widget.user.bgPhotoUrl,
      positionDescription: widget.user.positionDescription,
    );

    context.read<ManpowerCubit>().updateUser(updatedUser).then((_) {
      if (mounted) context.pop(); // Return to list
    });
  }

  @override
  Widget build(BuildContext context) {
    final isInactive = widget.user.active == false;
    final buttonText = isInactive ? "Activate User" : "Submit Change";
    final buttonColor = isInactive ? Colors.green : Colors.cyanAccent.shade700;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Modify User", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              GlassPanel(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTextField(
                      "NRP",
                      _nrpCtrl,
                      enabled: false,
                    ), // Cannot edit NRP usually
                    const SizedBox(height: 16),
                    _buildTextField(
                      "Name",
                      _nameCtrl,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      "Email",
                      _emailCtrl,
                      textCapitalization: TextCapitalization.none,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      "SID Code",
                      _sidCtrl,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),

                    // Position Dropdown
                    if (_isLoadingIncumbents)
                      const Center(child: CircularProgressIndicator())
                    else
                      DropdownButtonFormField<int>(
                        value: _selectedPosition,
                        dropdownColor: Colors.grey[900],
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: "Position",
                          labelStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items:
                            _incumbents.map((e) {
                              return DropdownMenuItem<int>(
                                value: e.id,
                                child: Text(
                                  '${e.incumbent} (ID: ${e.id})',
                                ), // Show ID for clarity? Or just name
                              );
                            }).toList(),
                        onChanged:
                            (val) => setState(() => _selectedPosition = val),
                      ),

                    const SizedBox(height: 16),
                    _buildTextField(
                      "Section",
                      _sectionCtrl,
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _onSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl, {
    bool enabled = true,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      textCapitalization: textCapitalization,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.cyanAccent),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor:
            enabled
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.2),
      ),
    );
  }
}
