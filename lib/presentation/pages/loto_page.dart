import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:gardaloto/presentation/cubit/auth_cubit.dart';
import 'package:gardaloto/presentation/cubit/auth_state.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/presentation/widget/capture_form_page.dart';
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

class LotoPage extends StatefulWidget {
  const LotoPage({super.key});

  @override
  State<LotoPage> createState() => _LotoPageState();
}

class _LotoPageState extends State<LotoPage> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Load active session first to ensure we have the session context
    // Force reload to clear any stale capturing state if we just navigated here
    await context.read<LotoCubit>().loadActiveSession();
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
        // Navigate to capture page
        context.go('/loto/capture');
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
        drawer: const Drawer(child: Sidebar()),
        appBar: AppBar(
          title: const Text("LOTO"),
          actions: [
            BlocBuilder<LotoCubit, LotoState>(
              builder: (context, state) {
                final isSessionActive =
                    state is LotoLoaded && state.session != null;
                final hasRecords =
                    state is LotoLoaded && state.records.isNotEmpty;

                if (isSessionActive && hasRecords) {
                  return IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendReport(context),
                    tooltip: 'Send Report',
                  );
                } else if (!isSessionActive) {
                  return PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'new_session') {
                        _showSessionDialog(context);
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem<String>(
                          value: 'new_session',
                          child: Text('New Session'),
                        ),
                      ];
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocBuilder<LotoCubit, LotoState>(
          builder: (context, state) {
            if (state is LotoLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is LotoLoaded) {
              final session = state.session;

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
                        child: Card(
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
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () =>
                                              _confirmAndDeleteSession(context),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Fuelman: $fuelmanDisplay'),
                                const SizedBox(height: 4),
                                Text('Operator: $operatorDisplay'),
                                const SizedBox(height: 4),
                                Text('Warehouse: ${session.warehouseCode}'),
                                const SizedBox(height: 4),
                                Text(
                                  'Nomor: ${session.nomor} • Shift: ${session.shift}',
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tanggal: ${session.dateTime.toLocal().toString().split('.').first}',
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
                          state.records.isEmpty
                              ? const Center(child: Text('No records yet'))
                              : ListView.builder(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 88,
                                ),
                                itemCount: state.records.length,
                                itemBuilder:
                                    (_, i) =>
                                        LotoCard(entity: state.records[i]),
                              ),
                    ),
                  ),
                ],
              );
            }

            return const SizedBox();
          },
        ),
        floatingActionButton: BlocBuilder<LotoCubit, LotoState>(
          builder: (context, state) {
            final isSessionActive =
                state is LotoLoaded && state.session != null;
            final fabColor = isSessionActive ? null : Colors.grey;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'gallery-fab',
                  mini: true,
                  backgroundColor: fabColor,
                  tooltip: 'Choose from gallery',
                  onPressed:
                      !isSessionActive
                          ? null
                          : () async {
                            final _picker = ImagePicker();
                            final XFile? image = await _picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (image == null) return;

                            if (!context.mounted) return;
                            final cubit = context.read<LotoCubit>();
                            cubit.startCapture(photoPath: image.path);

                            // Navigate to capture form page
                            context.go('/loto/capture');
                          },
                  child: const Icon(Icons.photo_library),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'camera-fab',
                  backgroundColor: fabColor,
                  tooltip: 'Take photo',
                  onPressed:
                      !isSessionActive
                          ? null
                          : () async {
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
                              context.go('/loto/capture');
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
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
