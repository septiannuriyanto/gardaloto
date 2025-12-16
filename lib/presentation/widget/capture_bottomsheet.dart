import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/core/image_utils.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/presentation/widget/photo_overlay.dart';
import 'package:go_router/go_router.dart';

class CaptureBottomSheet extends StatefulWidget {
  const CaptureBottomSheet({super.key});

  @override
  State<CaptureBottomSheet> createState() => _CaptureBottomSheetState();
}

class _CaptureBottomSheetState extends State<CaptureBottomSheet> {
  final ScrollController _scrollCtrl = ScrollController();
  final LayerLink _fieldLink = LayerLink();

  String? selectedCode;
  bool _focusHandled = false;
  // watermark editors
  final TextEditingController _wm1Ctrl = TextEditingController();
  final TextEditingController _wm2Ctrl = TextEditingController();
  final TextEditingController _wm3Ctrl = TextEditingController();
  final TextEditingController _wm4Ctrl = TextEditingController();
  bool _wmInitialized = false;
  bool _wm2Edited = false;

  @override
  void initState() {
    super.initState();
    _wm2Ctrl.addListener(() {
      // mark user-edited when user changes the unit watermark field
      _wm2Edited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LotoCubit>().state;
    if (state is! LotoCapturing) return const SizedBox();

    // initialize watermark controllers when entering capturing state
    if (!_wmInitialized) {
      _wm1Ctrl.text = 'NRP: NRP123456';
      _wm2Ctrl.text = 'UNIT: ${selectedCode ?? '-'}';
      _wm3Ctrl.text =
          'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';
      _wm4Ctrl.text = 'TIME: ${state.timestamp.toIso8601String()}';
      _wmInitialized = true;
    }

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Material(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  /// photo preview
                  PhotoOverlay(
                    photoPath: state.photoPath,
                    nrp: "NRP123456",
                    code: selectedCode,
                    lat: state.lat,
                    lng: state.lng,
                    timestamp: state.timestamp,
                  ),

                  const SizedBox(height: 16),

                  /// AUTOCOMPLETE
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue text) {
                      final all = ["UNIT-A01", "UNIT-B02", "UNIT-C03"];
                      if (text.text.isEmpty) return all;
                      return all.where(
                        (e) =>
                            e.toLowerCase().contains(text.text.toLowerCase()),
                      );
                    },

                    fieldViewBuilder: (
                      context,
                      controller,
                      focusNode,
                      onSubmit,
                    ) {
                      if (!_focusHandled) {
                        focusNode.addListener(() {
                          if (focusNode.hasFocus) {
                            Future.delayed(
                              const Duration(milliseconds: 200),
                              () {
                                if (_scrollCtrl.hasClients) {
                                  _scrollCtrl.animateTo(
                                    _scrollCtrl.position.maxScrollExtent,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                            );
                          }
                        });
                        _focusHandled = true;
                      }

                      return CompositedTransformTarget(
                        link: _fieldLink,
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            labelText: 'Unit Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      );
                    },

                    optionsViewBuilder: (context, onSelected, options) {
                      final opts = options.toList();
                      const itemWidth = 140.0;

                      final screenWidth = MediaQuery.of(context).size.width;
                      final width = min(
                        opts.length * itemWidth,
                        screenWidth - 32,
                      );

                      return CompositedTransformFollower(
                        link: _fieldLink,
                        offset: const Offset(0, -64),
                        showWhenUnlinked: false,
                        child: Material(
                          elevation: 4,
                          child: Container(
                            width: width,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children:
                                    opts.map((opt) {
                                      final isSelected = selectedCode == opt;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6.0,
                                        ),
                                        child: ChoiceChip(
                                          label: Text(opt),
                                          selected: isSelected,
                                          onSelected: (v) {
                                            setState(() {
                                              selectedCode = v ? opt : null;
                                              if (!_wm2Edited) {
                                                _wm2Ctrl.text =
                                                    'UNIT: ${selectedCode ?? '-'}';
                                              }
                                            });
                                            onSelected(opt);
                                          },
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },

                    onSelected: (v) => setState(() => selectedCode = v),
                  ),

                  const SizedBox(height: 24),

                  /// WATERMARK CUSTOMIZATION
                  ExpansionTile(
                    title: const Text('Watermark (customize lines)'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _wm1Ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Line 1',
                                helperText: 'e.g. NRP: 12345',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _wm2Ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Line 2',
                                helperText: 'e.g. UNIT: A01',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _wm3Ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Line 3',
                                helperText: 'e.g. GPS: lat, lng',
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _wm4Ctrl,
                              decoration: const InputDecoration(
                                labelText: 'Line 4',
                                helperText: 'e.g. TIME: ISO',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _wm1Ctrl.text = 'NRP: NRP123456';
                                      _wm2Ctrl.text =
                                          'UNIT: ${selectedCode ?? '-'}';
                                      _wm3Ctrl.text =
                                          'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';
                                      _wm4Ctrl.text =
                                          'TIME: ${state.timestamp.toIso8601String()}';
                                    });
                                  },
                                  child: const Text('Reset to defaults'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  /// SUBMIT
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          selectedCode == null || state is LotoSubmitting
                              ? null
                              : () async {
                                print('🚀 BottomSheet submit button pressed');
                                final file = File(state.photoPath);
                                if (!file.existsSync()) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Photo file not found'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // NOTE: We now use specific params for watermark
                                
                                String finalPath;
                                try {
                                  print('🖼️ Adding watermark to image...');
                                  finalPath = await addWatermarkToImage(
                                    inputPath: state.photoPath,
                                    unitCode: selectedCode!,
                                    nrp: 'NRP123456',
                                    gps: '${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}',
                                    timestamp: state.timestamp,
                                  );
                                  print(
                                    '✅ Watermark added successfully: $finalPath',
                                  );
                                } catch (e) {
                                  print('❌ Failed to add watermark: $e');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to watermark image: $e',
                                        ),
                                      ),
                                    );
                                  }
                                  return;
                                }

                                // Get sessionId from current capturing state
                                final sessionId =
                                    state.session?.nomor ?? "default_session";
                                print('📝 Session ID: $sessionId');

                                if (!context.mounted) {
                                  print(
                                    '⚠️ Context not mounted, aborting submit',
                                  );
                                  return;
                                }

                                try {
                                  print('💾 Starting submit to cubit...');
                                  await context.read<LotoCubit>().submit(
                                    LotoEntity(
                                      codeNumber: selectedCode!,
                                      photoPath: finalPath,
                                      timestamp: state.timestamp,
                                      latitude: state.lat,
                                      longitude: state.lng,
                                      sessionId: sessionId,
                                    ),
                                  );
                                  print('✅ Submit completed successfully');

                                  // Wait a bit to ensure state is processed
                                  await Future.delayed(
                                    const Duration(milliseconds: 300),
                                  );

                                  if (context.mounted) {
                                    print(
                                      '📤 Showing success message and navigating back...',
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Saved with watermark: ${finalPath.split('/').last}',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );

                                    // Close bottom sheet after successful submit
                                    print(
                                      '✅ Closing bottom sheet after successful submit...',
                                    );
                                    Navigator.pop(context);
                                  }
                                } catch (submitError) {
                                  print('❌ Submit error: $submitError');
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to save record: $submitError',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            state is LotoSubmitting
                                ? Colors.grey.shade400
                                : Theme.of(context).colorScheme.primary,
                      ),
                      child:
                          state is LotoSubmitting
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Saving...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                              : const Text(
                                'Submit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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

  @override
  void dispose() {
    _wm1Ctrl.dispose();
    _wm2Ctrl.dispose();
    _wm3Ctrl.dispose();
    _wm4Ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
