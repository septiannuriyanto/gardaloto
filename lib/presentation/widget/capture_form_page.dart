import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/core/image_utils.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/presentation/cubit/unit_cubit.dart';
import 'package:gardaloto/presentation/cubit/unit_state.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/widget/photo_overlay.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';
import 'package:geolocator/geolocator.dart';
import 'package:gardaloto/presentation/widget/custom_action_chip.dart'; // Import CustomActionChip

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

  // Duplicate check flag
  bool _isDuplicate = false;

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
        if (state is LotoCapturing &&
            state.lat == 0 &&
            state.lng == 0 &&
            !state.hasAttemptedGpsFetch) {
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
        // Fallback to last known location if service disabled
        await _tryFallbackLocation(cubit, 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
           // Fallback to last known location if permission denied
           await _tryFallbackLocation(cubit, 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
         // Fallback to last known location if permission denied forever
         await _tryFallbackLocation(cubit, 'Location permission denied forever');
        return;
      }

      LocationSettings locationSettings;

      if (Platform.isAndroid) {
        locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 10),
        );
      } else {
        locationSettings = const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
      );
      
      if (mounted) {
        // Save successful location to persistence
        // Access repo via cubit if possible or SL. Cubit.repo is public final.
        cubit.repo.saveLastKnownLocation(position.latitude, position.longitude);

        cubit.updateLocation(position.latitude, position.longitude);
        _wm3Ctrl.text =
            'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      }
    } catch (e) {
      if (mounted) {
        // Fallback on error (timeout, etc)
        await _tryFallbackLocation(cubit, e.toString());
      }
    }
  }

  Future<void> _tryFallbackLocation(LotoCubit cubit, String originalError) async {
    print('⚠️ GPS failed: $originalError. Attempting fallback...');
    final lastKnown = await cubit.repo.getLastKnownLocation();
    
    if (mounted) {
      if (lastKnown != null) {
        final (lat, lng) = lastKnown;
        print('✅ Using last known location: $lat, $lng');
        
        cubit.updateLocation(lat, lng);
        _wm3Ctrl.text = 'GPS (Last Known): ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
        
        // Show snackbar to inform user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GPS unavailable ($originalError). Using last known location.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        // No fallback available, show error
        cubit.updateLocationStatus(isLoading: false, error: originalError);
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
    // Provide UnitCubit here locally
    return BlocProvider(
      create: (context) => sl<UnitCubit>()..loadUnits(),
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) async {
          if (didPop) {
            final cubit = context.read<LotoCubit>();
            cubit.cancelCapture();
          }
        },
        child: Builder(
          builder: (context) {
            final state = context.watch<LotoCubit>().state;
            // initialize watermark controllers when entering capturing state
            if (state is LotoCapturing && !_wmInitialized) {
              // Get current user NRP
              final authState = context.read<AuthCubit>().state;
              final nrp =
                  (authState is AuthAuthenticated)
                      ? (authState.user.nrp ?? '-')
                      : '-';

              _wm1Ctrl.text = 'NRP: $nrp';
              _wm2Ctrl.text = 'UNIT: ${selectedCode ?? '-'}';
              _wm3Ctrl.text =
                  'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';
              _wm4Ctrl.text = 'TIME: ${state.timestamp.toIso8601String()}';
              _wmInitialized = true;
            }

            // Auto update GPS watermark if state updates (e.g. from auto-fetch)
            if (state is LotoCapturing) {
              _wm3Ctrl.text =
                  'GPS: ${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}';
            }

            // If state is lost (e.g. app restart on some devices), redirect to entry
            // BUT, allow valid post-capture states (Submitting, Loaded, Uploading, etc.)
            if (state is! LotoCapturing &&
                state is! LotoSubmitting &&
                state is! LotoLoaded &&
                state is! LotoUploadSuccess &&
                state is! LotoUploadError &&
                state is! LotoUploading) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  print(
                    '⚠️ CaptureFormPage - State lost (is ${state.runtimeType}), redirecting to /loto/entry',
                  );
                  context.go('/loto/entry');
                }
              });
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle non-capturing states (Loading, Success, etc.)
            if (state is LotoSubmitting) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        "Submitting...",
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is LotoLoaded || state is LotoUploadSuccess) {
              return const Scaffold(
                body: AppBackground(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 64),
                        SizedBox(height: 16),
                        Text(
                          "Saved!",
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (state is LotoUploadError || state is LotoError) {
              // If we errored out, we might have lost the photo path if we transitioned state completely.
              // Ideally we should have kept the state.
              // For now, allow the user to go back or entry.
              return Scaffold(
                appBar: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        state is LotoUploadError
                            ? state.message
                            : (state as LotoError).message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/loto/entry'),
                        child: const Text('Back to Home'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // At this point, if it's not Capturing, we should have returned or redirected.
            // But to be type-safe for the code below, we cast or return.
            if (state is! LotoCapturing) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                title: const Text(
                  'Capture Form',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: Colors.blue.shade900.withOpacity(0.2),
                    ),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.read<LotoCubit>().cancelCapture();
                      context.go('/loto/entry');
                    }
                  },
                ),
                actions: [
                  IconButton(
                    icon:
                        state.isLocationLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.cyanAccent,
                                strokeWidth: 2,
                              ),
                            )
                            : const Icon(
                              Icons.gps_fixed,
                              color: Colors.cyanAccent,
                            ),
                    tooltip: 'Refresh Location',
                    onPressed: state.isLocationLoading ? null : _fetchLocation,
                  ),
                ],
              ),
              body: AppBackground(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    100,
                    16,
                    16,
                  ), // Top padding for AppBar
                  child: Column(
                    children: [
                      // Location Loading Indicator
                      if (state.isLocationLoading) ...[
                        const LinearProgressIndicator(color: Colors.cyanAccent),
                        const SizedBox(height: 8),
                        const Text(
                          "Getting location...",
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 16),
                      ] else if (state.locationError != null) ...[
                        Text(
                          "Location Error: ${state.locationError}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Photo preview
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Builder(
                          builder: (context) {
                            final authState = context.watch<AuthCubit>().state;
                            final nrp =
                                (authState is AuthAuthenticated)
                                    ? (authState.user.nrp ?? '-')
                                    : '-';

                            return PhotoOverlay(
                              photoPath: state.photoPath,
                              nrp: nrp,
                              code:
                                  _textCtrl.text.isEmpty ? "-" : _textCtrl.text,
                              lat: state.lat,
                              lng: state.lng,
                              timestamp: state.timestamp,
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      GlassPanel(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chip suggestions (Dynamic from UnitCubit)
                              if (_textCtrl.text.isNotEmpty) ...[
                                BlocBuilder<UnitCubit, UnitState>(
                                  builder: (context, unitState) {
                                    List<String> suggestions = [];
                                    if (unitState is UnitLoaded) {
                                      suggestions =
                                          unitState.units
                                              .where(
                                                (unit) =>
                                                    unit.toLowerCase().contains(
                                                      _textCtrl.text
                                                          .toLowerCase(),
                                                    ),
                                              )
                                              .toList();
                                    }

                                    if (suggestions.isEmpty)
                                      return const SizedBox.shrink();

                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16.0,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'SUGGESTIONS',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            height:
                                                140, // Height for approx 3 rows
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Wrap(
                                                direction: Axis.vertical,
                                                spacing: 8.0,
                                                runSpacing: 8.0,
                                                children:
                                                    suggestions.map((unit) {
                                                      return CustomActionChip(
                                                        label: unit,
                                                        onPressed: () {
                                                          setState(() {
                                                            _textCtrl.text =
                                                                unit;
                                                            // Check duplicate after chip selection
                                                            _isDuplicate = state
                                                                .records
                                                                .any(
                                                                  (r) =>
                                                                      r.codeNumber ==
                                                                      unit,
                                                                );

                                                            // Always update watermark unit line
                                                            _wm2Ctrl.text =
                                                                'UNIT: $unit';

                                                            _textFocus
                                                                .unfocus();
                                                          });
                                                        },
                                                      );
                                                    }).toList(),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],

                              // Unit code autocomplete
                              TextFormField(
                                controller: _textCtrl,
                                focusNode: _textFocus,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Unit Code',
                                  labelStyle: const TextStyle(
                                    color: Colors.white70,
                                  ),
                                  enabledBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.white30,
                                    ),
                                  ),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                  hintText: 'e.g. UNITA01',
                                  hintStyle: const TextStyle(
                                    color: Colors.white30,
                                  ),
                                  errorText:
                                      _isDuplicate
                                          ? 'Duplicate Unit Code'
                                          : null,
                                  errorStyle: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white54,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _textCtrl.clear();
                                        _isDuplicate = false;
                                        _wm2Ctrl.text = 'UNIT: -';
                                        _textFocus.requestFocus();
                                      });
                                    },
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    // Check for duplicate
                                    _isDuplicate = state.records.any(
                                      (r) => r.codeNumber == value.trim(),
                                    );

                                    // Always update watermark unit line
                                    _wm2Ctrl.text =
                                        'UNIT: ${value.isEmpty ? '-' : value}';
                                  });

                                  // Scroll to bottom to keep input visible as suggestions expand "upwards"
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (_scrollController.hasClients) {
                                      _scrollController.animateTo(
                                        _scrollController
                                            .position
                                            .maxScrollExtent,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _textCtrl.text.trim().isEmpty ||
                                      state is LotoSubmitting ||
                                      _isDuplicate
                                  ? null
                                  : () async {
                                    final rawText = _textCtrl.text.trim();
                                    final upperText = rawText.toUpperCase();

                                    // Validation 1: Must contain at least one letter
                                    if (!upperText.contains(RegExp(r'[A-Z]'))) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Code Number Invalid: Must contain at least one letter',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    // Validation 2: No special characters (only Alphanumeric)
                                    // User requested "selain alfabet dan angka" -> strictly [A-Z0-9]
                                    if (upperText.contains(
                                      RegExp(r'[^A-Z0-9]'),
                                    )) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Code Number Invalid: Special characters not allowed',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    print('🚀 Page submit button pressed');
                                    final file = File(state.photoPath);
                                    if (!file.existsSync()) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Photo file not found',
                                            ),
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
                                        unitCode:
                                            upperText, // Use validated Uppercase text
                                        nrp: _wm1Ctrl.text.replaceFirst(
                                          'NRP: ',
                                          '',
                                        ), // Use initialized NRP from ctrl
                                        gps:
                                            '${state.lat.toStringAsFixed(5)}, ${state.lng.toStringAsFixed(5)}',
                                        timestamp: state.timestamp,
                                      );
                                      print(
                                        '✅ Watermark added successfully: $finalPath',
                                      );
                                    } catch (e) {
                                      print('❌ Failed to add watermark: $e');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Failed to watermark image: $e',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    // Get sessionId from current capturing state
                                    final sessionId =
                                        state.session?.nomor ??
                                        "default_session";
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
                                          codeNumber:
                                              upperText, // Use validated Uppercase text
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Saved successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );

                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/loto/entry');
                                        }
                                      }
                                    } catch (submitError) {
                                      print('❌ Submit error: $submitError');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
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
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor:
                                state is LotoSubmitting
                                    ? Colors.grey.shade400
                                    : Colors.cyanAccent.shade700,
                            foregroundColor:
                                Colors.white, // Ensure text is white
                            disabledBackgroundColor: Colors.white24,
                          ),
                          child:
                              state is LotoSubmitting
                                  ? const Text(
                                    'Saving...',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                  : const Text(
                                    'Submit',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
