import 'package:flutter/material.dart';

class CustomActionChip extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const CustomActionChip({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            // Glass effect: semi-transparent white background
            color: Colors.white.withOpacity(0.1),
            // Subtle white border
            border: Border.all(color: Colors.white24, width: 1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
