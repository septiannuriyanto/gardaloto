import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? color;
  final Border? border;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius = 20,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(color: Colors.white.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: -5,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: panel);
    }
    return panel;
  }
}
