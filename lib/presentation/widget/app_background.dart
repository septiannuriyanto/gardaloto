import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027), // Deep Dark Blue/Black
            Color(0xFF203A43), // Muted Teal/Grey-Blue
            Color(0xFF2C5364), // Softer Blue-Grey
          ],
        ),
      ),
      child: SafeArea(child: child),
    );
  }
}
