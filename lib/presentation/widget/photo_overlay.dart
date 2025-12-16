import 'dart:io';

import 'package:flutter/material.dart';

class PhotoOverlay extends StatelessWidget {
  final String photoPath;
  final String nrp;
  final String? code;
  final double lat;
  final double lng;
  final DateTime timestamp;

  const PhotoOverlay({
    super.key,
    required this.photoPath,
    required this.nrp,
    required this.code,
    required this.lat,
    required this.lng,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Builder(
          builder: (context) {
            final file = File(photoPath);
            if (file.existsSync()) {
              return Image.file(
                file,
                width: double.infinity,
                fit: BoxFit.cover,
              );
            }

            // If the file doesn't exist (simulation or missing), show a
            // placeholder instead of crashing the app.
            return Container(
              width: double.infinity,
              height: 200,
              color: Colors.grey.shade300,
              child: const Center(
                child: Icon(Icons.broken_image, size: 64, color: Colors.grey),
              ),
            );
          },
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.9),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Column 1: Big Unit Code
                Expanded(
                  child: Text(
                    code ?? "-",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 16),
                // Vertical Divider
                Container(
                  width: 1, 
                  height: 50, 
                  color: Colors.white.withOpacity(0.7)
                ),
                const SizedBox(width: 16),
                // Column 2: Details
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TIME: ${timestamp.toString().split('.')[0]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'GPS: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NRP: $nrp',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
