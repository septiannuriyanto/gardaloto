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
import 'package:geolocator/geolocator.dart'; // Import Geolocator

class CaptureFormPage extends StatefulWidget {
  const CaptureFormPage({super.key});

  @override
  State<CaptureFormPage> createState() => _CaptureFormPageState();
}

class _CaptureFormPageState extends State<CaptureFormPage> {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFocus = FocusNode();

  String? selectedCode;
  bool _focusHandled = false;
  
  // Duplicate check flag
  bool _isDuplicate = false;

  // Dummy unit data for chips
  final List<String> _dummyUnits = [
    'UNIT-001',
    'UNIT-002', 
    'DT-01',
    'EX-02', 
    'DZ-03'
  ];

  // watermark editors (kept for logic, mostly hidden from user now)
  final TextEditingController _wm1Ctrl = TextEditingController();
  final TextEditingController _wm2Ctrl = TextEditingController();
  final TextEditingController _wm3Ctrl = TextEditingController();
  final TextEditingController _wm4Ctrl = TextEditingController();
  bool _wmInitialized = false;
  // bool _wm2Edited = false; // No longer user-editable, so we always auto-update

  @override
  void initState() {
    super.initState();
    // No listener needed for _wm2Ctrl anymore since it's read-only/hidden

    // Auto focus and scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _textFocus.requestFocus();
        // Small delay to ensure keyboard opens before scrolling
        Future.delayed(const Duration(milliseconds: 300), () {
           if (mounted) {
             _scrollController.animateTo(
               _scrollController.position.maxScrollExtent,
               duration: const Duration(milliseconds: 300),
               curve: Curves.easeOut,
             );
           }
        });

        // Trigger auto-location if needed
        final state = context.read<LotoCubit>().state;
        if (state is LotoCapturing && state.lat == 0 && state.lng == 0 && !state.hasAttemptedGpsFetch) {
          _fetchLocation();
        }
      }
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
  void dispose() {
    _wm1Ctrl.dispose();
    _wm2Ctrl.dispose();
    _wm3Ctrl.dispose();
    _wm4Ctrl.dispose();
    _textCtrl.dispose();
    _scrollController.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LotoCubit>().state;
    // initialize watermark controllers when entering capturing state
    if (state is LotoCapturing && !_wmInitialized) {
      _wm1Ctrl.text = 'NRP: NRP123456';
      _wm2Ctrl.text = 'UNIT: ${selectedCode ?? '-'}';
      _wm3Ctrl.text =
          'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';
      _wm4Ctrl.text = 'TIME: ${state.timestamp.toIso8601String()}';
      _wmInitialized = true;
    }

    // Auto update GPS watermark if state updates (e.g. from auto-fetch)
    if (state is LotoCapturing) {
       _wm3Ctrl.text = 'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';
    }

    if (state is! LotoCapturing) {
      // If state is lost (e.g. app restart), redirect back to entry to recover
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
           print('⚠️ CaptureFormPage - State lost, redirecting to /loto/entry');
           context.go('/loto/entry');
        }
      });
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Form'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/loto/entry'),
        ),
        actions: [
          IconButton(
            icon: state.isLocationLoading 
              ? const SizedBox(
                  width: 20, 
                  height: 20, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : const Icon(Icons.gps_fixed),
            tooltip: 'Refresh Location',
            onPressed: state.isLocationLoading ? null : _fetchLocation,
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             // Location Loading Indicator
            if (state.isLocationLoading) ...[
               const LinearProgressIndicator(),
               const SizedBox(height: 8),
               const Text("Getting location...", style: TextStyle(fontSize: 12, color: Colors.grey)),
               const SizedBox(height: 16),
            ] else if (state.locationError != null) ...[
               Text("Location Error: ${state.locationError}", style: const TextStyle(fontSize: 12, color: Colors.red)),
               const SizedBox(height: 16),
            ],

            // Photo preview
            PhotoOverlay(
              photoPath: state.photoPath,
              nrp: "NRP123456",
              code: _textCtrl.text.isEmpty ? "-" : _textCtrl.text,
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
                        setState(() {
                          _textCtrl.text = unit;
                          // Check duplicate after chip selection
                          _isDuplicate = state.records.any((r) => r.codeNumber == unit);
                          
                          // Always update watermark unit line
                          _wm2Ctrl.text = 'UNIT: $unit';
                          
                          _textFocus.unfocus();
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Unit code autocomplete
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
                  setState(() {
                    _textCtrl.clear();
                    _isDuplicate = false;
                    _wm2Ctrl.text = 'UNIT: -';
                    _textFocus.requestFocus();
                  });
                }
                ),
              ),
              onChanged: (value) {
                setState(() {
                   // Check for duplicate
                   _isDuplicate = state.records.any((r) => r.codeNumber == value.trim());

                   // Always update watermark unit line
                   _wm2Ctrl.text = 'UNIT: ${value.isEmpty ? '-' : value}';
                });
              },
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _textCtrl.text.trim().isEmpty || state is LotoSubmitting || _isDuplicate
                        ? null
                        : () async {
                          print('🚀 Page submit button pressed');
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
                              nrp: 'NRP123456', // Hardcoded for now, as per prev implementation
                              gps: '${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}',
                              timestamp: state.timestamp,
                            );
                            print('✅ Watermark added successfully: $finalPath');
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
                            print('⚠️ Context not mounted, aborting submit');
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

                              // Navigate back to loto page after successful submit
                              print(
                                '✅ Navigating back to loto page after successful submit...',
                              );
                              context.go('/loto/entry');
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
                  foregroundColor: Colors.white, // Ensure text is white
                ),
                child:
                    state is LotoSubmitting
                        ? const Text('Saving...', style: TextStyle(fontWeight: FontWeight.bold))
                        : const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
