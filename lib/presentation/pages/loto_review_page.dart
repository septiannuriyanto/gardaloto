import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:gardaloto/core/service_locator.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:gardaloto/domain/entities/loto_session.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/cubit/loto_state.dart';
import 'package:gardaloto/presentation/cubit/manpower_cubit.dart';
import 'package:gardaloto/presentation/cubit/storage_cubit.dart';

import 'package:gardaloto/presentation/widget/capture_bottomsheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shimmer/shimmer.dart';

class LotoReviewPage extends StatelessWidget {
  final LotoSession session;

  const LotoReviewPage({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => sl<LotoCubit>()..loadReviewSession(session),
        ),
        BlocProvider(create: (_) => sl<ManpowerCubit>()..syncAndLoad()),
        BlocProvider(create: (_) => sl<StorageCubit>()..syncAndLoad()),
      ],
      child: _LotoReviewView(session: session),
    );
  }
}

class _LotoReviewView extends StatefulWidget {
  final LotoSession session;
  const _LotoReviewView({required this.session});

  @override
  State<_LotoReviewView> createState() => _LotoReviewViewState();
}

class _LotoReviewViewState extends State<_LotoReviewView> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _captureImage(BuildContext context, ImageSource source) async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null && context.mounted) {
        // Trigger capture with default location (0,0 for now)
        context.read<LotoCubit>().startCapture(photoPath: photo.path);

        // Capture local cubit before showing modal
        final lotoCubit = context.read<LotoCubit>();

        // Show bottom sheet directly - no navigation needed
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          barrierColor: Colors.black54,
          builder: (context) => BlocProvider.value(
            value: lotoCubit,
            child: const CaptureBottomSheet(),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('LOTO Review'),
        actions: [
          BlocBuilder<LotoCubit, LotoState>(
            builder: (context, state) {
              if (state is LotoLoaded) {
                final hasPending = state.records.any(
                  (r) => !r.photoPath.startsWith('http'),
                );
                if (hasPending) {
                  return IconButton(
                    icon: const Icon(Icons.send, color: Colors.blue),
                    onPressed: () {
                      context.read<LotoCubit>().uploadPendingRecords();
                    },
                  );
                }
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocConsumer<LotoCubit, LotoState>(
        listener: (context, state) {
          if (state is LotoCapturing) {
            // Capture form is now shown via GoRouter navigation in _captureImage method
            // No need to handle here anymore
          } else if (state is LotoUploading) {
            // Show loading dialog if not already showing
            // Note: This is a simple implementation. For better UX, use a proper dialog manager.
            // We check if we are already showing a dialog by checking the top route?
            // Or we can just show it and rely on the state change to close it?
            // A common pattern is to show a non-dismissible dialog.

            // However, since state updates frequently for progress, we shouldn't push a new dialog every time.
            // We can check if the current state was NOT LotoUploading before.
            // But BlocListener doesn't give previous state easily unless we use listenWhen.

            // Let's use a simpler approach: The builder handles the "Loading" overlay if we want inline.
            // But the user asked for a "dialog upload".

            // To avoid multiple dialogs, we can use a boolean flag in the State class,
            // or just show a SnackBar with progress?
            // User said "dialog upload".

            // Let's try to show a dialog that listens to the bloc itself?
            // Or just show one dialog and let it rebuild?

            // Actually, showing a dialog from listener is tricky with progress updates.
            // Best way: Show dialog ONCE when starting.
            // But how do we know it started?
            // We can check `if (state.uploadedCount == 0)`.
            if (state.uploadedCount == 0) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder:
                    (dialogContext) => BlocProvider.value(
                      value: context.read<LotoCubit>(),
                      child: BlocBuilder<LotoCubit, LotoState>(
                        builder: (context, state) {
                          double? progress;
                          String text = 'Uploading...';

                          if (state is LotoUploading) {
                            if (state.totalCount > 0) {
                              progress = state.uploadedCount / state.totalCount;
                              text =
                                  'Uploading ${state.uploadedCount}/${state.totalCount}';
                            }
                          }

                          return AlertDialog(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(text),
                                if (progress != null) ...[
                                  const SizedBox(height: 8),
                                  LinearProgressIndicator(value: progress),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
              );
            }
          } else if (state is LotoUploadSuccess) {
            // Close dialog
            Navigator.of(context).pop(); // Pop the dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is LotoUploadError) {
            // Close dialog
            Navigator.of(context).pop(); // Pop the dialog
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
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
          } else if (state is LotoLoading) {
            return _buildSkeletonLoader();
          } else if (state is LotoError) {
            return Center(child: Text('Error: ${state.message}'));
          }

          session ??= widget.session;

          // If we still have no session (e.g. initial loading failed), show error or skeleton
          // But we handled LotoLoading above.

          return BlocBuilder<ManpowerCubit, ManpowerState>(
            builder: (context, manpowerState) {
              // Lookup names
              String fuelmanDisplay = session!.fuelman;
              String operatorDisplay = session!.operatorName;

              if (manpowerState is ManpowerSynced) {
                final fuelmanEntity =
                    manpowerState.fuelmen
                        .where((e) => e.nrp == session!.fuelman)
                        .firstOrNull;
                if (fuelmanEntity != null) {
                  fuelmanDisplay = fuelmanEntity.nama ?? session!.fuelman;
                }

                final operatorEntity =
                    manpowerState.operators
                        .where((e) => e.nrp == session!.operatorName)
                        .firstOrNull;
                if (operatorEntity != null) {
                  operatorDisplay =
                      operatorEntity.nama ?? session!.operatorName;
                }
              }

              return Column(
                children: [
                  Flexible(
                    flex: 0,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header: Title & Number
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Session Details',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF2F2F7,
                                    ), // iOS System Grey 6
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    session!.nomor,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),

                          // Content
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Warehouse & Date
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildInfoItem(
                                        'WAREHOUSE',
                                        session!.warehouseCode,
                                        icon: Icons.warehouse_outlined,
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildInfoItem(
                                        'DATE',
                                        session!.dateTime
                                            .toLocal()
                                            .toString()
                                            .split(' ')[0],
                                        icon: Icons.calendar_today_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Personnel
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9F9F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _buildInfoItem(
                                          'FUELMAN',
                                          fuelmanDisplay,
                                          isName: true,
                                        ),
                                      ),
                                      Container(
                                        width: 1,
                                        height: 30,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildInfoItem(
                                          'OPERATOR',
                                          operatorDisplay,
                                          isName: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Shift Badge
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE5F1FB),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Shift ${session!.shift}',
                                      style: const TextStyle(
                                        color: Color(0xFF007AFF),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
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
                  Flexible(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child:
                          records.isEmpty
                              ? const Center(child: Text('No records found'))
                              : GridView.builder(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 88,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 4,
                                      mainAxisSpacing: 4,
                                    ),
                                itemCount: records.length,
                                itemBuilder: (context, index) {
                                  final record = records[index];
                                  final isLocal =
                                      !record.photoPath.startsWith('http');

                                  return GestureDetector(
                                    onTap: () {
                                      // Open zoomable image viewer
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => Scaffold(
                                                appBar: AppBar(
                                                  backgroundColor: Colors.black,
                                                  iconTheme:
                                                      const IconThemeData(
                                                        color: Colors.white,
                                                      ),
                                                ),
                                                backgroundColor: Colors.black,
                                                body: PhotoView(
                                                  imageProvider:
                                                      isLocal
                                                          ? FileImage(
                                                                File(
                                                                  record
                                                                      .photoPath,
                                                                ),
                                                              )
                                                              as ImageProvider
                                                          : CachedNetworkImageProvider(
                                                            record.photoPath,
                                                          ),
                                                  heroAttributes:
                                                      PhotoViewHeroAttributes(
                                                        tag: record.photoPath,
                                                      ),
                                                ),
                                              ),
                                        ),
                                      );
                                    },
                                    child: Hero(
                                      tag: record.photoPath,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          isLocal
                                              ? Image.file(
                                                File(record.photoPath),
                                                fit: BoxFit.cover,
                                              )
                                              : CachedNetworkImage(
                                                imageUrl: record.photoPath,
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    (context, url) =>
                                                        Shimmer.fromColors(
                                                          baseColor:
                                                              Colors.grey[300]!,
                                                          highlightColor:
                                                              Colors.grey[100]!,
                                                          child: Container(
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(Icons.error),
                                              ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              color: Colors.black54,
                                              padding: const EdgeInsets.all(2),
                                              child: Text(
                                                record.codeNumber,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          if (isLocal) ...[
                                            const Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Icon(
                                                Icons.pending,
                                                color: Colors.orange,
                                                size: 16,
                                              ),
                                            ),
                                            Positioned(
                                              top: -8,
                                              left: -8,
                                              child: GestureDetector(
                                                onTap: () {
                                                  context
                                                      .read<LotoCubit>()
                                                      .delete(record);
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ), // Hit target padding
                                                  child: Container(
                                                    decoration:
                                                        const BoxDecoration(
                                                          color: Colors.red,
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color:
                                                                  Colors
                                                                      .black26,
                                                              blurRadius: 2,
                                                              offset: Offset(
                                                                0,
                                                                1,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                    child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ] else
                                            const Positioned(
                                              top: 4,
                                              right: 4,
                                              child: Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 16,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: () => _captureImage(context, ImageSource.camera),
            child: const Icon(Icons.camera_alt),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: () => _captureImage(context, ImageSource.gallery),
            child: const Icon(Icons.photo_library),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value, {
    IconData? icon,
    bool isName = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isName ? 15 : 14,
            fontWeight: isName ? FontWeight.w600 : FontWeight.normal,
            color: Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 12,
              itemBuilder:
                  (_, __) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(color: Colors.white),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
