import 'package:flutter/material.dart';

class LoadingDialog extends StatelessWidget {
  final String? message;
  final int? uploadedCount;
  final int? totalCount;

  const LoadingDialog({
    super.key,
    this.message,
    this.uploadedCount,
    this.totalCount,
  });

  static void show(
    BuildContext context, {
    String? message,
    int? uploadedCount,
    int? totalCount,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder:
          (context) => LoadingDialog(
            message: message,
            uploadedCount: uploadedCount,
            totalCount: totalCount,
          ),
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                message ?? 'Uploading...',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              if (uploadedCount != null && totalCount != null) ...[
                const SizedBox(height: 8),
                Text(
                  '($uploadedCount/$totalCount)',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
