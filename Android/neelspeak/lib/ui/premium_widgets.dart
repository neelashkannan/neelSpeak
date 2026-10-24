import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The NeelSpeak brand mark: the white waveform from the app icon on the
/// brand gradient. Drawn as a vector so it stays crisp from a 24 dp app-bar
/// glyph up to the onboarding hero, in light and dark themes.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 56,
    this.rounded = true,
    this.withGlow = true,
  });

  final double size;
  final bool rounded;
  final bool withGlow;

  @override
  Widget build(BuildContext context) {
    final radius = rounded ? size * 0.28 : 0.0;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: NeelSpeakBrand.gradient,
          boxShadow: withGlow
              ? [
                  BoxShadow(
                    color: NeelSpeakBrand.primary.withAlpha(110),
                    blurRadius: size * 0.4,
                    offset: Offset(0, size * 0.18),
                  ),
                ]
              : null,
        ),
        child: CustomPaint(painter: _WaveformPainter()),
      ),
    );
  }
}

/// Waveform traced from assets/logo_mark.png. Coordinates are relative to
/// the waveform's width (x 0…1, y centred on 0); the same curve is used for
/// the adaptive launcher icon in res/drawable/ic_launcher_foreground.xml.
class _WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.66;
    final left = (size.width - w) / 2;
    final midY = size.height / 2;
    Offset p(double x, double y) => Offset(left + x * w, midY + y * w);

    final path = Path()
      ..moveTo(p(0, 0.135).dx, p(0, 0.135).dy)
      ..lineTo(p(0.0874, 0.135).dx, p(0.0874, 0.135).dy);
    void curve(List<double> c) {
      final a = p(c[0], c[1]), b = p(c[2], c[3]), e = p(c[4], c[5]);
      path.cubicTo(a.dx, a.dy, b.dx, b.dy, e.dx, e.dy);
    }

    curve([0.1417, 0.135, 0.1534, -0.0573, 0.2078, -0.0573]);
    curve([0.2777, -0.0573, 0.2932, 0.2961, 0.3515, 0.2961]);
    curve([0.4233, 0.2961, 0.4369, -0.2961, 0.5, -0.2961]);
    curve([0.5631, -0.2961, 0.5767, 0.2961, 0.6485, 0.2961]);
    curve([0.7068, 0.2961, 0.7223, -0.0573, 0.7922, -0.0573]);
    curve([0.8466, -0.0573, 0.8583, 0.135, 0.9126, 0.135]);
    path.lineTo(p(1, 0.135).dx, p(1, 0.135).dy);

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.width * 0.045).clamp(1.2, 6.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF020617),
                  Color(0xFF0B1220),
                  Color(0xFF111827),
                ]
              : const [
                  Color(0xFFF4F7FF),
                  Color(0xFFF8FAFC),
                  Color(0xFFEEF2FF),
                ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _GlowOrb(
              color: scheme.primary.withAlpha(dark ? 90 : 55),
              size: 280,
            ),
          ),
          Positioned(
            top: 140,
            left: -90,
            child: _GlowOrb(
              color: scheme.secondary.withAlpha(dark ? 70 : 40),
              size: 220,
            ),
          ),
          Positioned(
            bottom: -90,
            right: -40,
            child: _GlowOrb(
              color: scheme.tertiary.withAlpha(dark ? 60 : 34),
              size: 180,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final decoration = BoxDecoration(
      color: dark
          ? const Color(0xFF111827).withAlpha(214)
          : Colors.white.withAlpha(222),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: theme.colorScheme.onSurface.withAlpha(dark ? 34 : 18),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(dark ? 52 : 18),
          blurRadius: dark ? 30 : 22,
          offset: const Offset(0, 12),
        ),
      ],
    );

    if (onTap == null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: padding,
        decoration: decoration,
        child: child,
      );
    }

    // Ink paints the panel on the Material so the ripple shows on top of it.
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: decoration,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionIntro extends StatelessWidget {
  const SectionIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(185),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({
    super.key,
    required this.label,
    this.icon,
    this.tint,
  });

  final String label;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(56)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline message for errors, warnings and confirmations. Pairs an icon with
/// the text so state never relies on colour alone.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.title,
    this.tone = StatusTone.error,
    this.action,
    this.onDismiss,
  });

  final String message;
  final String? title;
  final StatusTone tone;
  final Widget? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (color, icon) = switch (tone) {
      StatusTone.error => (scheme.error, Icons.error_outline_rounded),
      StatusTone.warning => (scheme.warning, Icons.warning_amber_rounded),
      StatusTone.success => (scheme.success, Icons.check_circle_outline_rounded),
      StatusTone.info => (scheme.primary, Icons.info_outline_rounded),
    };
    return Semantics(
      liveRegion: tone == StatusTone.error,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, Space.md),
        decoration: BoxDecoration(
          color: color.withAlpha(24),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(70)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null) ...[
                    Text(
                      title!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                  ],
                  Text(message, style: theme.textTheme.bodyMedium),
                  if (action != null) ...[
                    const SizedBox(height: Space.sm),
                    action!,
                  ],
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                icon: const Icon(Icons.close_rounded, size: 20),
              )
            else
              const SizedBox(width: Space.sm),
          ],
        ),
      ),
    );
  }
}

enum StatusTone { error, warning, success, info }

class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha(150),
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withAlpha(0),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded icon tile that heads each onboarding step and settings card.
class StepIcon extends StatelessWidget {
  const StepIcon({super.key, required this.icon, this.size = 64});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: primary.withAlpha(22),
          borderRadius: BorderRadius.circular(size * 0.34),
        ),
        child: Icon(icon, size: size * 0.47, color: primary),
      ),
    );
  }
}

/// Primary + optional secondary action. Stacks full-width on phones (and
/// at large text sizes), sits side by side on wide screens.
class ActionButtons extends StatelessWidget {
  const ActionButtons({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final hasSecondary = secondaryLabel != null;
    final primary = FilledButton(onPressed: onPrimary, child: Text(primaryLabel));
    final secondary = hasSecondary
        ? OutlinedButton(onPressed: onSecondary, child: Text(secondaryLabel!))
        : null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        if (constraints.maxWidth < 520 || scale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (secondary != null) ...[
                secondary,
                const SizedBox(height: Space.md),
              ],
              primary,
            ],
          );
        }
        return Row(
          children: [
            if (secondary != null) ...[
              Expanded(child: secondary),
              const SizedBox(width: Space.md),
            ],
            Expanded(child: primary),
          ],
        );
      },
    );
  }
}
