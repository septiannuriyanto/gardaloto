import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gardaloto/core/constants.dart';

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
            padding: const EdgeInsets.fromLTRB(
              16,
              96,
              16,
              24,
            ), // Increased top padding for taller vignette
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Column 1: Big Unit Code
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      code ?? "-",
                      style: const TextStyle(
                        color: Colors.amber, // Amber color requested
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Vertical Divider
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withOpacity(0.7),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'GPS: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NRP: $nrp',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "Garda LOTO",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w200,
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      // App Version
                      Text(
                        'v$appVersion',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w400,
                          shadows: [
                            Shadow(
                              offset: const Offset(1, 1),
                              blurRadius: 2,
                              color: Colors.black.withOpacity(0.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Image.asset('assets/logo.png', height: 24, width: 24),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
