import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:gardaloto/domain/entities/manpower_entity.dart';
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
import 'package:gardaloto/core/file_utils.dart';

class LotoDraftPage extends StatefulWidget {
  const LotoDraftPage({super.key});

  @override
  State<LotoDraftPage> createState() => _LotoDraftPageState();
}

class _LotoDraftPageState extends State<LotoDraftPage> {
  bool _isDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cubit = context.read<LotoCubit>();

    // Always load active session from persistent storage to ensure fresh state
    // This fixes the issue where returning from History (which uses a different state)
    // might leave this page showing incorrect data if we didn't reload.
    await cubit.loadActiveSession();

    // Load manpower data (sync or local) to ensure names are available
    if (mounted) {
      context.read<ManpowerCubit>().syncAndLoad();
    }

    // Check for lost data (e.g. from camera) after session is loaded
    await _retrieveLostData();
  }

  Future<void> _retrieveLostData() async {
    // retrieveLostData is only relevant on Android where the Activity might be destroyed.
    // On iOS, this is not needed and throws an UnimplementedError.
    if (!Platform.isAndroid) return;

    final ImagePicker picker = ImagePicker();
    try {
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty) {
        return;
      }

      final file = response.file;
      if (file != null) {
        print('♻️ Recovered lost image data: ${file.path}');
        if (mounted) {
          // Save to persistent storage
          final persistentPath = await saveImageToPersistentStorage(file.path);
          print('💾 Saved recovered image to: $persistentPath');

          final cubit = context.read<LotoCubit>();
          // Start capture with recovered image
          cubit.startCapture(photoPath: persistentPath);
          // Navigate to capture page using push to preserve stack
          context.push('/loto/capture');
        }
      } else {
        print('⚠️ Recovered data error: ${response.exception}');
      }
    } catch (e) {
      // Ignore UnimplementedError (e.g. on iOS or some Android versions where not supported needed)
      print('Info: retrieveLostData not supported or failed: $e');
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

    final session = state.session!;

    if (session.operatorName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operator cannot be empty. Please edit Session Info.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (session.fuelman.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fuelman cannot be empty. Please edit Session Info.'),
          backgroundColor: Colors.red,
        ),
      );
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

  Future<void> _showManpowerSelectionDialog({
    required BuildContext context,
    required String title,
    required int filterPosition, // 4 for operator, 5 for fuelman
    required Function(ManpowerEntity entity) onSelected,
  }) async {
    // Capture cubit from parent context
    final manpowerCubit = context.read<ManpowerCubit>();

    await showDialog(
      context: context,
      builder:
          (ctx) => BlocProvider.value(
            value: manpowerCubit,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: GlassPanel(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: BlocBuilder<ManpowerCubit, ManpowerState>(
                        builder: (context, state) {
                          if (state is ManpowerSynced) {
                            List<ManpowerEntity> list;
                            if (filterPosition == 5) {
                              list = List.from(state.fuelmen);
                            } else {
                              list = List.from(state.operators);
                            }

                            // Sort by name
                            list.sort(
                              (a, b) => (a.nama ?? '').compareTo(b.nama ?? ''),
                            );

                            return ListView.separated(
                              itemCount: list.length,
                              separatorBuilder:
                                  (_, __) => const Divider(
                                    color: Colors.white24,
                                    height: 1,
                                  ),
                              itemBuilder: (_, i) {
                                final item = list[i];
                                return ListTile(
                                  title: Text(
                                    item.nama ?? '-',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    item.nrp,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  onTap: () {
                                    onSelected(item);
                                    Navigator.of(ctx).pop();
                                  },
                                );
                              },
                            );
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  void _updateManpower(
    BuildContext context,
    LotoSession currentSession, {
    bool isFuelman = false,
  }) {
    final isFT = currentSession.warehouseCode.toUpperCase().startsWith('FT');
    // If not FT, use filter 5 (same as Fuelman) for Operator as well.
    final filterPos = (isFuelman || !isFT) ? 5 : 4;

    _showManpowerSelectionDialog(
      context: context,
      title: isFuelman ? 'Select Fuelman' : 'Select Operator',
      filterPosition: filterPos,
      onSelected: (entity) {
        // Validation logic for operator name:
        // 1. If we are editing Operator (!isFuelman), update it to new NRP.
        // 2. If we are editing Fuelman (isFuelman) AND warehouse is NOT FT (e.g. FS/FP),
        //    we likely want to sync Operator to match Fuelman (as per FS logic).
        // 3. Otherwise (editing Fuelman in FT), keep existing Operator.

        final newOperatorName =
            !isFuelman ? entity.nrp : currentSession.operatorName;
        final newOperatorPhoto =
            !isFuelman ? entity.photoUrl : currentSession.operatorPhotoUrl;

        // If updating fuelman and applying FS/FP logic (operator follows fuelman)
        final shouldSyncOperator = isFuelman && !isFT;

        final finalOperatorName =
            shouldSyncOperator ? entity.nrp : newOperatorName;
        final finalOperatorPhoto =
            shouldSyncOperator ? entity.photoUrl : newOperatorPhoto;

        final newSession = LotoSession(
          dateTime: currentSession.dateTime,
          shift: currentSession.shift,
          fuelman: isFuelman ? entity.nrp : currentSession.fuelman,
          operatorName: finalOperatorName,
          warehouseCode: currentSession.warehouseCode,
          nomor: currentSession.nomor,
          fuelmanPhotoUrl:
              isFuelman ? entity.photoUrl : currentSession.fuelmanPhotoUrl,
          operatorPhotoUrl: finalOperatorPhoto,
          appVersion: currentSession.appVersion,
        );
        context.read<LotoCubit>().setSession(newSession);
        // Force rebuild
        setState(() {});
      },
    );
  }

  String _formatDate(DateTime dt) {
    // dt is implicitly considered to have Makassar face-values (because of our storage convention)
    // even though it might be a UTC object.
    // We just want to print YYYY-MM-DD HH:MM
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');

    return '$y-$m-$d';
  }

  Widget _buildManpowerTile({
    required String label,
    required String value,
    String? photoUrl,
    required IconData icon,
    required VoidCallback onEdit,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.white24,
                  backgroundImage:
                      (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                  child:
                      (photoUrl == null || photoUrl.isEmpty)
                          ? const Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.white70,
                          )
                          : null,
                ),
                const SizedBox(width: 8),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.edit,
                      size: 14,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
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
            IconButton(
              icon: const Icon(Icons.list),
              onPressed: () => context.pushNamed('loto_sessions'),
              tooltip: 'History',
            ),
            BlocBuilder<LotoCubit, LotoState>(
              builder: (context, state) {
                LotoSession? session;
                List<LotoEntity> records = [];

                if (state is LotoLoaded) {
                  session = state.session;
                  records = state.records;
                } else if (state is LotoUploading) {
                  session = state.session;
                  records = state.records;
                } else if (state is LotoUploadSuccess) {
                  session = state.session;
                  records = state.records;
                } else if (state is LotoUploadError) {
                  session = state.session;
                  records = state.records;
                } else if (state is LotoCapturing) {
                  session = state.session;
                  records = state.records;
                }

                final isSessionActive = session != null;
                final hasRecords = records.isNotEmpty;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSessionActive && hasRecords) ...[
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () async {
                          final paths =
                              records.map((e) => e.photoPath).toList();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saving images to gallery...'),
                              duration: Duration(seconds: 1),
                            ),
                          );

                          final count = await saveSessionImagesToGallery(paths);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Saved $count images to Gallery'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        tooltip: 'Save to Gallery',
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.cyanAccent),
                        onPressed: () => _sendReport(context),
                        tooltip: 'Send Report',
                      ),
                    ],
                  ],
                );
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

                // Use name lookup if feasible, or just show NRP if desired.
                // Actually previous logic showed Name if found, or NRP.
                // To keep it simple, we can display NRP or rely on ManpowerCubit lookup *just for names* if we want,
                // but the user's "snapshot" approach implies we might want to store names too?
                // For now, let's keep the name lookup simple via a separate simpler BlocBuilder or just accepting NRP/Name display.
                // However, to satisfy "fetch photo_url when session is created", we used the session fields.
                // Let's use BlocBuilder ONLY for name resolution, but retrieve Photos from Session.

                return BlocBuilder<ManpowerCubit, ManpowerState>(
                  builder: (context, manpowerState) {
                    String fuelmanDisplay = session?.fuelman ?? '-';
                    String operatorDisplay = session?.operatorName ?? '-';

                    if (manpowerState is ManpowerSynced) {
                      final f =
                          manpowerState.fuelmen
                              .where((e) => e.nrp == session?.fuelman)
                              .firstOrNull;
                      if (f != null)
                        fuelmanDisplay = f.nama ?? session!.fuelman;

                      final o =
                          manpowerState.operators
                              .where((e) => e.nrp == session?.operatorName)
                              .firstOrNull;
                      // Fallback for FS/FP
                      final oFallback =
                          o ??
                          manpowerState.fuelmen
                              .where((e) => e.nrp == session?.operatorName)
                              .firstOrNull;
                      if (oFallback != null)
                        operatorDisplay =
                            oFallback.nama ?? session!.operatorName;
                    }

                    return Column(
                      children: [
                        if (session != null)
                          Flexible(
                            flex: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: GlassPanel(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Title + Delete
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              session.warehouseCode,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.cyanAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${_formatDate(session.dateTime)} • Shift ${session.shift}',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
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
                                    const SizedBox(height: 16),

                                    // Manpower Tiles
                                    Row(
                                      children: [
                                        _buildManpowerTile(
                                          label: 'Fuelman',
                                          value: fuelmanDisplay,
                                          photoUrl: session.fuelmanPhotoUrl,
                                          icon: Icons.local_gas_station,
                                          onEdit:
                                              () => _updateManpower(
                                                context,
                                                session!,
                                                isFuelman: true,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildManpowerTile(
                                          label: 'Operator',
                                          value: operatorDisplay,
                                          photoUrl: session.operatorPhotoUrl,
                                          icon: Icons.engineering,
                                          onEdit:
                                              () => _updateManpower(
                                                context,
                                                session!,
                                                isFuelman: false,
                                              ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // Footer Info
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Nomor: ${session.nomor}',
                                          style: const TextStyle(
                                            color: Colors.white38,
                                            fontSize: 11,
                                            fontFamily: 'Monospace',
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.teal.withValues(
                                              alpha: 0.2,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            border: Border.all(
                                              color: Colors.teal.withValues(
                                                alpha: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            '${records.length} Records',
                                            style: const TextStyle(
                                              color: Colors.tealAccent,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
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
                  },
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

                    // Save to persistent storage
                    final persistentPath = await saveImageToPersistentStorage(
                      image.path,
                    );

                    final cubit = context.read<LotoCubit>();
                    cubit.startCapture(photoPath: persistentPath);

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

                      // Save to persistent storage
                      final persistentPath = await saveImageToPersistentStorage(
                        image.path,
                      );

                      final cubit = context.read<LotoCubit>();
                      cubit.startCapture(photoPath: persistentPath);

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
