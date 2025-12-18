import 'dart:ui';
import 'package:flutter/material.dart';

class GlassFAB extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget icon;
  final String? label;
  final String? tooltip;
  final Object? heroTag;
  final bool mini;
  final bool enabled;

  const GlassFAB({
    super.key,
    required this.onPressed,
    required this.icon,
    this.label,
    this.tooltip,
    this.heroTag,
    this.mini = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    // Determine size and shape
    final double height = mini ? 40 : 56;
    final double minWidth = height;
    final BorderRadius borderRadius = BorderRadius.circular(height / 2);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      tooltip: tooltip,
      child: Container(
        height: height,
        width: label == null ? height : null, // Enforce circle if no label
        constraints: BoxConstraints(minWidth: minWidth),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: enabled ? onPressed : null,
                borderRadius: borderRadius,
                child: Container(
                  padding: label != null
                      ? const EdgeInsets.symmetric(horizontal: 16)
                      : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: enabled
                        ? Colors.cyanAccent.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.2),
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: enabled
                          ? Colors.cyanAccent.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          color: enabled ? Colors.white : Colors.white38,
                          size: mini ? 20 : 24,
                        ),
                        child: icon,
                      ),
                      if (label != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          label!,
                          style: TextStyle(
                            color: enabled ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
