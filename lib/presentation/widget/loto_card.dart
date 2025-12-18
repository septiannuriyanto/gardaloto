import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gardaloto/domain/entities/loto_entity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gardaloto/presentation/cubit/loto_cubit.dart';
import 'package:gardaloto/presentation/widget/glass_panel.dart';

class LotoCard extends StatelessWidget {
  final LotoEntity entity;
  final VoidCallback? onImageTap;

  const LotoCard({super.key, required this.entity, this.onImageTap});

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
                    final file = File(entity.photoPath);
                    if (file.existsSync()) {
                      return GestureDetector(
                        onTap: onImageTap ?? () {
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
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                                   await context.read<LotoCubit>().delete(entity);
                                   if (context.mounted) {
                                     ScaffoldMessenger.of(context).showSnackBar(
                                       const SnackBar(content: Text('Deleted')),
                                     );
                                   }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Delete failed: $e')),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
