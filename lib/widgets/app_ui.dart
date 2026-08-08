import 'package:flutter/material.dart';

/// ============================================================================
/// GIC PORTAL SHARED DESIGN SYSTEM
/// A small, cohesive set of reusable building blocks so every tab of the
/// Expert Dashboard shares one modern look: deep-indigo brand color, crisp
/// #F8FAFC surfaces, soft shadows, subtle gradients and pastel status chips.
/// ============================================================================

/// Deep indigo / navy brand palette used across the Expert Dashboard.
class AppPalette {
  AppPalette._();

  // Brand
  static const Color primary = Color(0xFF312E81); // Deep Indigo
  static const Color primaryDark = Color(0xFF1E1B4B); // Navy
  static const Color primaryLight = Color(0xFF6366F1); // Indigo 500
  static const Color accent = Color(0xFF7C3AED); // Violet
  static const Color teal = Color(0xFF0D9488);

  // Surfaces & lines
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color inputFill = Color(0xFFF1F5F9);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Common gradients
  static const List<Color> primaryGradient = [
    Color(0xFF6366F1),
    Color(0xFF4338CA)
  ];
  static const List<Color> sidebarGradient = [
    Color(0xFF312E81),
    Color(0xFF1E1B4B)
  ];
  static const List<Color> successGradient = [
    Color(0xFF22C55E),
    Color(0xFF16A34A)
  ];
  static const List<Color> accentGradient = [
    Color(0xFFA855F7),
    Color(0xFF7C3AED)
  ];

  /// Maps a plan/proposal status to its accent color.
  static Color statusColor(String status) {
    switch (status) {
      case 'Approved':
        return const Color(0xFF16A34A); // green
      case 'Approved by Dept Head':
        return const Color(0xFF0D9488); // teal
      case 'In Progress':
        return const Color(0xFF2563EB); // blue
      case 'Completed':
        return const Color(0xFF7C3AED); // violet
      case 'Rejected':
        return const Color(0xFFDC2626); // red
      case 'Needs Revision':
      case 'Revision Requested':
        return const Color(0xFFEA580C); // orange
      case 'Pending Dean Review':
      case 'Pending':
        return const Color(0xFFD97706); // amber
      default:
        return const Color(0xFF64748B); // slate
    }
  }
}

/// Elevated rounded card with a soft shadow (the base surface of the design).
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final LinearGradient? gradient;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 16,
    this.color = AppPalette.surface,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A card that gently lifts its shadow when hovered (web/desktop micro-interaction).
class HoverCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final BorderSide? border;

  const HoverCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 16,
    this.color = AppPalette.surface,
    this.border,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: _hovered
                ? AppPalette.primaryLight.withValues(alpha: 0.45)
                : (widget.border?.color ?? AppPalette.border),
            width: _hovered ? 1.4 : (widget.border?.width ?? 1),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: 0.10),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// Rounded-square icon tile filled with a tinted gradient + soft colored glow.
class IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const IconBubble({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.72)],
        ),
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

/// Tiny colored pill for micro-indicators (trends, live badges, etc.).
class TrendPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const TrendPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern KPI metric card: gradient icon bubble, big bold value, tinted
/// gradient wash and an optional trend pill.
class MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String? trend;
  final IconData? trendIcon;

  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
    this.trendIcon,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      padding: const EdgeInsets.all(20),
      radius: 18,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconBubble(icon: icon, color: color),
                if (trend != null)
                  TrendPill(label: trend!, icon: trendIcon, color: color),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppPalette.textPrimary,
                height: 1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppPalette.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppPalette.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastel status pill with a colored dot (green Approved, orange Pending, ...).
class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final bool showDot;

  const StatusChip(this.label, {super.key, this.color, this.showDot = true});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppPalette.statusColor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Primary call-to-action button with a subtle gradient + colored glow.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double? height;
  final double? width;
  final double radius;
  final double fontSize;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.colors,
    this.height,
    this.width,
    this.radius = 14,
    this.fontSize = 15,
  });

  @override
  Widget build(BuildContext context) {
    final grad = colors ?? AppPalette.primaryGradient;
    final button = SizedBox(
      height: height ?? 52,
      width: width ?? double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: grad,
          ),
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: grad.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 9),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (onPressed == null) return Opacity(opacity: 0.5, child: button);
    return button;
  }
}

/// Standard rounded, filled input decoration used across the dashboard.
InputDecoration appInputDecoration({
  String? label,
  String? hint,
  IconData? icon,
  Widget? suffixIcon,
  bool alignLabel = false,
}) {
  OutlineInputBorder outlineBorder(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppPalette.inputFill,
    alignLabelWithHint: alignLabel,
    labelStyle: const TextStyle(color: AppPalette.textSecondary),
    hintStyle: const TextStyle(color: AppPalette.textMuted, fontSize: 13),
    enabledBorder: outlineBorder(AppPalette.border, 1),
    focusedBorder: outlineBorder(AppPalette.primaryLight, 1.8),
    disabledBorder:
        outlineBorder(AppPalette.border.withValues(alpha: 0.6), 1),
    border: outlineBorder(AppPalette.border, 1),
  );
}

/// Section heading with optional icon + subtitle for consistent hierarchy.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? AppPalette.primary, size: 26),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.textPrimary,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppPalette.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// Bold inline section label used above form fields.
class FieldLabel extends StatelessWidget {
  final String text;
  final IconData? icon;

  const FieldLabel(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 17, color: AppPalette.primary),
          const SizedBox(width: 6),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppPalette.textPrimary,
          ),
        ),
      ],
    );
  }
}
