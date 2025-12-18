import 'dart:ui';
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                // Use white glass for the dialog
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 40,
                    width: 40,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    message ?? 'Uploading...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white, // Keep white text as it's glass over dark bg
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (uploadedCount != null && totalCount != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '($uploadedCount/$totalCount)',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
