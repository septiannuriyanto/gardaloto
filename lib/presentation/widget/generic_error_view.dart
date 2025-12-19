import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class GenericErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRefresh;
  final String lottieAsset;

  const GenericErrorView({
    super.key,
    this.message = 'Error Loading Content. Try Refreshing Manually',
    this.onRefresh,
    this.lottieAsset = 'assets/lottie/error_loading.json',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie Animation
            SizedBox(
              width: 200,
              height: 200,
              child: Lottie.asset(
                lottieAsset,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if Lottie file is missing
                  return Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.white54,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Error Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // Refresh Button
            if (onRefresh != null)
              ElevatedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
