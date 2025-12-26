import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';

class LotoCard extends StatelessWidget {
  final LotoEntity entity;
  final VoidCallback? onImageTap;
  final bool isProcessing; // New prop

  const LotoCard({
    super.key,
    required this.entity,
    this.onImageTap,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Builder(
                  builder: (context) {
                    // SKELETON STATE
                    if (isProcessing) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Processing",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final file = File(entity.photoPath);
                    if (file.existsSync()) {
                      return GestureDetector(
                        onTap:
                            onImageTap ??
                            () {
                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder:
                                      (context) => Dialog(
                                        child: Image.file(file),
                                        backgroundColor: Colors.transparent,
                                        insetPadding: const EdgeInsets.all(12),
                                      ),
                                );
                              }
                            },
                        child: Hero(
                          tag: entity.photoPath,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(file, fit: BoxFit.cover),
                          ),
                        ),
                      );
                    }
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.white54),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            entity.codeNumber,
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Delete record'),
                                    content: const Text(
                                      'Are you sure you want to delete this record? This will remove the saved photo file as well.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true) {
                              try {
                                if (context.mounted) {
                                  await context.read<LotoCubit>().delete(
                                    entity,
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Deleted')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Delete failed: $e'),
                                    ),
                                  );
                                }
                              }
                            }
                          }, // Closes onPressed
                        ), // Closes IconButton
                      ],
                    ),

                    const SizedBox(height: 4),
                    Text(
                      "GPS: ${entity.latitude.toStringAsFixed(5)}, "
                      "${entity.longitude.toStringAsFixed(5)}",
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      "Time: ${entity.timestamp}",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    if (!entity.photoPath.startsWith('http'))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Size: ${_getFileSize(entity.photoPath)}",
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.cyanAccent,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Path: ${entity.photoPath}",
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white30,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
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

  String _getFileSize(String path) {
    try {
      final file = File(path);
      if (!file.existsSync()) return "";
      int bytes = file.lengthSync();
      if (bytes < 1024) return "$bytes B";
      if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
      return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    } catch (e) {
      return "";
    }
  }
}
