import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/presentation/widget/loto_card.dart';
import 'package:gardaloto/presentation/widget/loading_dialog.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/domain/entities/loto_master_record.dart';
import 'package:gardaloto/presentation/widget/empty_list_session_dialog.dart';
import 'package:gardaloto/data/repositories/loto_master_repository.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/presentation/widget/sidebar.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';
import 'package:gardaloto/presentation/widget/full_screen_gallery.dart';
import 'package:gardaloto/presentation/widget/app_background.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';
import 'package:gardaloto/presentation/widget/generic_error_view.dart';
import 'package:gardaloto/presentation/widget/glass_fab.dart';
import 'dart:ui';

class LotoPage extends StatefulWidget {
  const LotoPage({super.key});

  @override
  State<LotoPage> createState() => _LotoPageState();
}

class _LotoPageState extends State<LotoPage> {
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cubit = context.read<LotoCubit>();

    // Only load if we don't have a valid session in memory
    // This optimization is crucial for Singleton LotoCubit to persist state across navigation
    if (cubit.state is LotoLoaded &&
        (cubit.state as LotoLoaded).session != null) {
      print('✨ Session already loaded in memory, skipping disk reload');
    } else {
      // Load active session first to ensure we have the session context
      await cubit.loadActiveSession();
    }

    // Check for lost data (e.g. from camera) after session is loaded
    await _retrieveLostData();
  }

  Future<void> _retrieveLostData() async {
    final ImagePicker picker = ImagePicker();
    final LostDataResponse response = await picker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }

    final file = response.file;
    if (file != null) {
      print('♻️ Recovered lost image data: ${file.path}');
      if (mounted) {
        final cubit = context.read<LotoCubit>();
        // Start capture with recovered image
        cubit.startCapture(photoPath: file.path);
        // Navigate to capture page using push to preserve stack
        context.push('/loto/capture');
      }
    } else {
      print('⚠️ Recovered data error: ${response.exception}');
    }
  }

  Future<void> _sendReport(BuildContext context) async {
    final state = context.read<LotoCubit>().state;
    if (state is! LotoLoaded ||
        state.session == null ||
        state.records.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No data to send')));
      return;
    }

    // Trigger upload through cubit - loading dialog will be handled by BlocListener
    await context.read<LotoCubit>().uploadData();
  }

  Future<void> _showSessionDialog(BuildContext context) async {
    final masterRepo = sl<LotoMasterRepository>();
    // Get current master data to pre-fill the session dialog
    LotoMasterRecord? master = masterRepo.getMaster();

    final manpowerCubit = context.read<ManpowerCubit>();
    final storageCubit = context.read<StorageCubit>();

    // Trigger sync here as requested
    manpowerCubit.syncAndLoad();
    storageCubit.syncAndLoad();

    // Get current user for auto-fill
    final authState = context.read<AuthCubit>().state;
    final currentUser = authState is AuthAuthenticated ? authState.user : null;

    setState(() {
      _isDialogOpen = true;
    });

    final session = await showDialog<LotoSession?>(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => EmptyListSessionDialog(
            initialMaster: master,
            manpowerCubit: manpowerCubit,
            storageCubit: storageCubit,
            currentUser: currentUser,
          ),
    );

    if (mounted) {
      setState(() {
        _isDialogOpen = false;
      });
    }

    if (session != null) {
      if (context.mounted) {
        await context.read<LotoCubit>().setSession(session);
      }

      // Force rebuild to show updated session info
      setState(() {});
    }
  }

  Future<void> _confirmAndDeleteSession(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Session'),
            content: const Text(
              'Menghapus session ini akan menghapus seluruh LOTO Record anda? yakin untuk menghapus session?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<LotoCubit>().clearSession();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ManpowerCubit, ManpowerState>(
          listener: (context, state) {
            if (state is ManpowerSyncing) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing manpower data...'),
                  duration: Duration(seconds: 1),
                ),
              );
            } else if (state is ManpowerSynced) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is ManpowerError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Manpower sync error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
        BlocListener<StorageCubit, StorageState>(
          listener: (context, state) {
            if (state is StorageSyncing) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing storage data...'),
                  duration: Duration(seconds: 1),
                ),
              );
            } else if (state is StorageSynced) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.green,
                ),
              );
            } else if (state is StorageError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Storage sync error: ${state.message}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),

        // Listens for Uploading Start
        BlocListener<LotoCubit, LotoState>(
          listenWhen:
              (previous, current) =>
                  previous is! LotoUploading && current is LotoUploading,
          listener: (context, state) {
            // Show dialog with BlocBuilder inside to handle updates
            showDialog(
              context: context,
              barrierDismissible: false,
              useRootNavigator: true,
              builder: (dialogContext) {
                // Use the cubit from the parent context
                return BlocProvider.value(
                  value: context.read<LotoCubit>(),
                  child: BlocBuilder<LotoCubit, LotoState>(
                    builder: (context, state) {
                      int uploaded = 0;
                      int total = 0;
                      if (state is LotoUploading) {
                        uploaded = state.uploadedCount;
                        total = state.totalCount;
                      }
                      return LoadingDialog(
                        message: 'Uploading LOTO records...',
                        uploadedCount: uploaded,
                        totalCount: total,
                      );
                    },
                  ),
                );
              },
            );
          },
        ),

        // Listens for Uploading End (Success/Error/Loaded)
        BlocListener<LotoCubit, LotoState>(
          listenWhen: (previous, current) {
            final wasUploading = previous is LotoUploading;
            final isNotUploading = current is! LotoUploading;
            return wasUploading && isNotUploading;
          },
          listener: (context, state) {
            // Close upload dialog
            final navigator = Navigator.of(context, rootNavigator: true);
            if (navigator.canPop()) {
              navigator.pop();
            }

            if (state is LotoUploadSuccess) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is LotoUploadError) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.message)));
            } else if (state is LotoError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),

        // Listens for General Errors (not from upload flow)
        BlocListener<LotoCubit, LotoState>(
          listenWhen:
              (previous, current) =>
                  previous is! LotoUploading && current is LotoError,
          listener: (context, state) {
            if (state is LotoError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ],
      child: Scaffold(
        extendBodyBehindAppBar: true,
        drawer: const Sidebar(),
        appBar: AppBar(
          title: const Text(
            "LOTO Draft",
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.blue.shade900.withOpacity(0.2)),
            ),
          ),
          actions: [
            BlocBuilder<LotoCubit, LotoState>(
              builder: (context, state) {
                final isSessionActive =
                    state is LotoLoaded && state.session != null;
                final hasRecords =
                    state is LotoLoaded && state.records.isNotEmpty;

                if (isSessionActive && hasRecords) {
                  return IconButton(
                    icon: const Icon(Icons.send, color: Colors.cyanAccent),
                    onPressed: () => _sendReport(context),
                    tooltip: 'Send Report',
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: AppBackground(
          child: BlocBuilder<LotoCubit, LotoState>(
            builder: (context, state) {
              if (state is LotoLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                );
              }
              if (state is LotoError) {
                return GenericErrorView(
                  message: state.message,
                  onRefresh: () {
                    context.read<LotoCubit>().loadActiveSession();
                  },
                );
              }

              LotoSession? session;
              List<LotoEntity> records = [];

              if (state is LotoLoaded) {
                session = state.session;
                records = state.records;
              } else if (state is LotoCapturing) {
                session = state.session;
                records = state.records;
              } else if (state is LotoUploading) {
                session = state.session;
                records = state.records;
              }

              if (session != null) {
                // Lookup names from ManpowerCubit

                // Lookup names from ManpowerCubit
                String fuelmanDisplay = session?.fuelman ?? '-';
                String operatorDisplay = session?.operatorName ?? '-';

                final manpowerState = context.read<ManpowerCubit>().state;
                if (manpowerState is ManpowerSynced) {
                  final fuelmanEntity =
                      manpowerState.fuelmen
                          .where((e) => e.nrp == session?.fuelman)
                          .firstOrNull;
                  if (fuelmanEntity != null) {
                    fuelmanDisplay = fuelmanEntity.nama ?? session!.fuelman;
                  }

                  final operatorEntity =
                      manpowerState.operators
                          .where((e) => e.nrp == session?.operatorName)
                          .firstOrNull;
                  if (operatorEntity != null) {
                    operatorDisplay =
                        operatorEntity.nama ?? session!.operatorName;
                  }
                }

                return Column(
                  children: [
                    if (session != null)
                      Flexible(
                        flex: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: GlassPanel(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Session Info',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed:
                                            () => _confirmAndDeleteSession(
                                              context,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Fuelman: $fuelmanDisplay',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Operator: $operatorDisplay',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Warehouse: ${session.warehouseCode}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nomor: ${session.nomor} • Shift: ${session.shift}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tanggal: ${session.dateTime.toLocal().toString().split('.').first}',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child:
                            records.isEmpty
                                ? const Center(
                                  child: Text(
                                    'No records yet',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 88,
                                  ),
                                  itemCount: records.length,
                                  itemBuilder:
                                      (_, i) => LotoCard(
                                        entity: records[i],
                                        isProcessing: context
                                            .read<LotoCubit>()
                                            .isProcessing(
                                              records[i].timestamp
                                                  .toIso8601String(),
                                            ),
                                        onImageTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      FullScreenGallery(
                                                        records: records,
                                                        initialIndex: i,
                                                      ),
                                            ),
                                          );
                                        },
                                      ),
                                ),
                      ),
                    ),
                  ],
                );
              }

              return Stack(
                children: [
                  const Center(
                    child: Text(
                      "Tidak ada draft,\ntekan tombol di bawah\nuntuk menambah draft baru",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ),
                  if (!_isDialogOpen)
                    Positioned(
                      bottom: 3,
                      right: 80,
                      child: Opacity(
                        opacity: 0.8,
                        child: Lottie.asset(
                          'assets/lottie/blue_arrow.json',
                          width: 150,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        floatingActionButton: BlocBuilder<LotoCubit, LotoState>(
          builder: (context, state) {
            final isSessionActive =
                state is LotoLoaded && state.session != null;

            // If NO session, show the "Add New Session" FAB
            if (!isSessionActive) {
              return GlassFAB(
                heroTag: 'new-session-fab',
                tooltip: 'New Session',
                enabled: true,
                onPressed: () => _showSessionDialog(context),
                icon: const Icon(Icons.add),
              );
            }

            // If Session EXISTS, show Camera and Gallery options
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GlassFAB(
                  heroTag: 'gallery-fab',
                  mini: true,
                  tooltip: 'Choose from gallery',
                  enabled: true,
                  onPressed: () async {
                    final _picker = ImagePicker();
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image == null) return;

                    if (!context.mounted) return;
                    final cubit = context.read<LotoCubit>();
                    cubit.startCapture(photoPath: image.path);

                    // Navigate to capture form page
                    context.push('/loto/capture');
                  },
                  icon: const Icon(Icons.photo_library),
                ),
                const SizedBox(height: 16),
                GlassFAB(
                  heroTag: 'camera-fab',
                  tooltip: 'Take photo',
                  enabled: true,
                  onPressed: () async {
                    try {
                      final _picker = ImagePicker();
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.camera,
                        preferredCameraDevice: CameraDevice.rear,
                      );
                      if (image == null) return;

                      if (!context.mounted) return;
                      final cubit = context.read<LotoCubit>();
                      cubit.startCapture(photoPath: image.path);

                      // Navigate to capture form page
                      context.push('/loto/capture');
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to open camera: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.camera_alt),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
