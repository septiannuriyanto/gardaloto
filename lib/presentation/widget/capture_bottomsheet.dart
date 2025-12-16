import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/core/image_utils.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/presentation/widget/photo_overlay.dart';
import 'package:geolocator/geolocator.dart';

class CaptureBottomSheet extends StatefulWidget {
  const CaptureBottomSheet({super.key});

  @override
  State<CaptureBottomSheet> createState() => _CaptureBottomSheetState();
}

class _CaptureBottomSheetState extends State<CaptureBottomSheet> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _textCtrl = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  String? selectedCode;
  bool _isDuplicate = false;

  // Dummy unit data for chips (Synced with CaptureFormPage)
  final List<String> _dummyUnits = [
    'UNIT-001',
    'UNIT-002', 
    'DT-01',
    'EX-02', 
    'DZ-03'
  ];

  // watermark editors
  final TextEditingController _wm1Ctrl = TextEditingController(); // NRP
  final TextEditingController _wm2Ctrl = TextEditingController(); // UNIT
  final TextEditingController _wm3Ctrl = TextEditingController(); // GPS
  final TextEditingController _wm4Ctrl = TextEditingController(); // TIME
  bool _wmInitialized = false;

  @override
  void initState() {
    super.initState();
    // Auto focus on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocus.requestFocus();

        // Trigger auto-location if needed
        final state = context.read<LotoCubit>().state;
        if (state is LotoCapturing && state.lat == 0 && state.lng == 0 && !state.hasAttemptedGpsFetch) {
          _fetchLocation();
        }
      }
    });

    // Listen to text changes for duplicate check and watermark update
    _textCtrl.addListener(() {
      setState(() {
        final val = _textCtrl.text.trim();
        final state = context.read<LotoCubit>().state;
        if (state is LotoCapturing) {
           _isDuplicate = state.records.any((r) => r.codeNumber == val);
        }
        _wm2Ctrl.text = 'UNIT: ${val.isEmpty ? '-' : val}';
        selectedCode = val.isEmpty ? null : val;
      });
    });
  }

  Future<void> _fetchLocation() async {
    final cubit = context.read<LotoCubit>();
    cubit.updateLocationStatus(isLoading: true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        cubit.updateLocationStatus(isLoading: false, error: 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          cubit.updateLocationStatus(isLoading: false, error: 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        cubit.updateLocationStatus(isLoading: false, error: 'Location permission denied forever');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        cubit.updateLocation(position.latitude, position.longitude);
        // Also update watermark control for GPS
        _wm3Ctrl.text = 'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }
    } catch (e) {
      if (mounted) {
        cubit.updateLocationStatus(isLoading: false, error: e.toString());
      }
    }
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

    // Auto update GPS watermark if state updates (e.g. from auto-fetch)
    _wm3Ctrl.text = 'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';

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
                   // Header Row
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const SizedBox(width: 48), // Spacer for centering
                       Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      IconButton(
                        icon: state.isLocationLoading 
                          ? const SizedBox(
                              width: 16, 
                              height: 16, 
                              child: CircularProgressIndicator(strokeWidth: 2)
                            )
                          : const Icon(Icons.gps_fixed, size: 20),
                        tooltip: 'Refresh Location',
                        onPressed: state.isLocationLoading ? null : _fetchLocation,
                      ),
                     ],
                   ),
                  const SizedBox(height: 8),

                   // Location Error Indicator
                   if (state.locationError != null) ...[
                     Text("Location Error: ${state.locationError}", style: const TextStyle(fontSize: 12, color: Colors.red)),
                     const SizedBox(height: 8),
                   ],

                   // Getting location indicator
                   if (state.isLocationLoading) ...[
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 4),
                      const Text("Getting location...", style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 12),
                   ],


                  /// photo preview
                  PhotoOverlay(
                    photoPath: state.photoPath,
                    nrp: "NRP123456",
                    code: _textCtrl.text.isEmpty ? "-" : _textCtrl.text, // Live update
                    lat: state.lat,
                    lng: state.lng,
                    timestamp: state.timestamp,
                  ),

                  const SizedBox(height: 24),

                  // Chip suggestions (Moved to Top)
                  if (_textCtrl.text.isNotEmpty) ...[
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        alignment: WrapAlignment.start,
                        children: _dummyUnits
                            .where((unit) => unit
                                .toLowerCase()
                                .contains(_textCtrl.text.toLowerCase()))
                            .map((unit) {
                          return ActionChip(
                            label: Text(unit),
                            onPressed: () {
                              _textCtrl.text = unit; // Updates logic via listener
                              _textFocus.unfocus();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  /// Unit Code Input (Simplified, matching CaptureFormPage style)
                  TextFormField(
                    controller: _textCtrl,
                    focusNode: _textFocus,
                    decoration: InputDecoration(
                      labelText: 'Unit Code',
                      border: const OutlineInputBorder(),
                      hintText: 'e.g. UNIT-A01',
                      errorText: _isDuplicate ? 'Duplicate Unit Code' : null,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                         onPressed: () {
                          _textCtrl.clear();
                          _textFocus.requestFocus();
                        }
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  /// SUBMIT
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _textCtrl.text.trim().isEmpty || state is LotoSubmitting || _isDuplicate
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

                                String finalPath;
                                try {
                                  print('🖼️ Adding watermark to image...');
                                  finalPath = await addWatermarkToImage(
                                    inputPath: state.photoPath,
                                    unitCode: _textCtrl.text.trim(),
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
                                      codeNumber: _textCtrl.text.trim(),
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
    _textCtrl.dispose();
    _textFocus.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
}
