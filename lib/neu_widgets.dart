import 'package:flutter/material.dart';

/// Neumorphic ("soft UI") palette.
///
/// The whole look comes from one flat background colour per theme plus two
/// soft shadows: a light one cast from the top-left and a dark one from the
/// bottom-right. Pressed or "inset" shapes invert that light direction with a
/// gradient, so a control visibly sinks into the surface.
abstract final class NeuColors {
  // Light theme: cool, slightly blue-grey so white highlights read as light.
  static const lightBase = Color(0xFFE9EEF6);
  static const lightShadowLight = Color(0xFFFFFFFF);
  static const lightShadowDark = Color(0xFFC4CEDD);

  // Dark theme: charcoal, highlights only a shade above the base.
  static const darkBase = Color(0xFF1F242B);
  static const darkShadowLight = Color(0xFF2C333C);
  static const darkShadowDark = Color(0xFF101419);
}

/// Shadow helpers shared by every neumorphic surface.
abstract final class Neu {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// The flat surface colour everything is extruded from.
  static Color base(BuildContext context) =>
      isDark(context) ? NeuColors.darkBase : NeuColors.lightBase;

  static Color highlight(BuildContext context) => isDark(context)
      ? NeuColors.darkShadowLight
      : NeuColors.lightShadowLight;

  static Color shade(BuildContext context) =>
      isDark(context) ? NeuColors.darkShadowDark : NeuColors.lightShadowDark;

  /// Outer shadows that make a shape look raised off the background.
  static List<BoxShadow> raised(
    BuildContext context, {
    double distance = 5,
    double blur = 14,
    Color? glow,
  }) {
    return [
      BoxShadow(
        color: highlight(context).withValues(alpha: isDark(context) ? 0.9 : 1),
        offset: Offset(-distance, -distance),
        blurRadius: blur,
      ),
      BoxShadow(
        color: shade(context).withValues(alpha: isDark(context) ? 0.9 : 0.75),
        offset: Offset(distance, distance),
        blurRadius: blur,
      ),
      if (glow != null)
        BoxShadow(color: glow.withValues(alpha: 0.22), blurRadius: 20),
    ];
  }

  /// Faint outer rim used by inset shapes (they sit flush with the surface).
  static List<BoxShadow> flush(BuildContext context) => [
        BoxShadow(
          color: shade(context).withValues(alpha: isDark(context) ? 0.6 : 0.35),
          offset: const Offset(1, 2),
          blurRadius: 4,
        ),
      ];

  /// Overlay that fakes an inner shadow: dark from the top-left, light from
  /// the bottom-right. Meant to be clipped by the parent's rounded shape.
  static Widget innerShade(BuildContext context) {
    final dark = shade(context);
    final light = highlight(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            dark.withValues(alpha: isDark(context) ? 0.65 : 0.35),
            dark.withValues(alpha: 0.02),
            light.withValues(alpha: isDark(context) ? 0.22 : 0.85),
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
    );
  }
}

/// A rounded neumorphic panel.
///
/// * `pressed: false` → extruded from the surface, soft drop shadows.
/// * `pressed: true` → inset, i.e. a well cut into the surface (used for input
///   fields, selected quiz options and the pressed state of buttons).
class NeuSurface extends StatelessWidget {
  const NeuSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding,
    this.margin,
    this.pressed = false,
    this.color,
    this.glow,
    this.width,
    this.height,
    this.clip = true,
    this.alignment,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool pressed;
  final Color? color;

  /// Optional brand-colour halo (kept subtle so it stays neumorphic).
  final Color? glow;
  final double? width;
  final double? height;
  final bool clip;
  final AlignmentGeometry? alignment;

  @override
  Widget build(BuildContext context) {
    final base = color ?? Neu.base(context);
    final shape = BorderRadius.circular(radius);

    Widget content = padding == null
        ? child
        : Padding(padding: padding!, child: child);

    if (pressed) {
      content = Stack(
        children: [
          Positioned.fill(child: Neu.innerShade(context)),
          content,
        ],
      );
    }

    Widget box = Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      decoration: BoxDecoration(
        color: base,
        borderRadius: shape,
        boxShadow: pressed ? Neu.flush(context) : Neu.raised(context, glow: glow),
      ),
      child: clip ? ClipRRect(borderRadius: shape, child: content) : content,
    );

    return box;
  }
}

/// [NeuSurface] that reacts to touch: sinks into the surface while pressed.
class NeuTappable extends StatefulWidget {
  const NeuTappable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.radius = 20,
    this.padding,
    this.margin,
    this.color,
    this.glow,
    this.width,
    this.height,
    this.alignment,
    this.pressed = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Resting state: inset shapes (selected options) stay sunk even when idle.
  final bool pressed;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? glow;
  final double? width;
  final double? height;
  final AlignmentGeometry? alignment;

  @override
  State<NeuTappable> createState() => _NeuTappableState();
}

class _NeuTappableState extends State<NeuTappable> {
  bool _down = false;

  void _setDown(bool value) {
    if (_down == value) return;
    setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setDown(true) : null,
      onTapCancel: enabled ? () => _setDown(false) : null,
      onTapUp: enabled ? (_) => _setDown(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: NeuSurface(
          radius: widget.radius,
          padding: widget.padding,
          margin: widget.margin,
          pressed: _down || widget.pressed,
          color: widget.color,
          glow: widget.glow,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Neumorphic pill button. The [accent] tints the label and a soft halo while
/// the body stays the colour of the surrounding surface.
class NeuButton extends StatelessWidget {
  const NeuButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = const Color(0xFFFEB03C),
    this.icon,
    this.minHeight = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final IconData? icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final dark = Neu.isDark(context);
    final fg = enabled
        ? (dark
            ? Color.alphaBlend(accent.withValues(alpha: 0.42), Colors.white)
            : Color.alphaBlend(Colors.black.withValues(alpha: 0.42), accent))
        : (dark ? const Color(0xFF6B7482) : const Color(0xFF9AA6B5));

    return NeuTappable(
      onTap: onPressed,
      radius: 18,
      glow: enabled ? accent : null,
      child: Container(
        height: minHeight,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 21),
              const SizedBox(width: 9),
            ],
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App-wide photo background.
///
/// Sits behind the navigator (see `MaterialApp.builder`) so every screen shows
/// it through the transparent scaffold background. A translucent veil of the
/// theme's base colour keeps text and the soft neumorphic highlights readable
/// over the picture.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  static const String imagePath = 'assets/images/26857.jpg';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Neu.isDark(context);
    final base = Neu.base(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          imagePath,
          fit: BoxFit.cover,
          // Missing picture: fall back to the plain neumorphic surface.
          errorBuilder: (_, _, _) => ColoredBox(color: base),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                base.withValues(alpha: dark ? 0.80 : 0.68),
                base.withValues(alpha: dark ? 0.86 : 0.76),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Round icon button that presses in like the pill button.
class NeuIconButton extends StatelessWidget {
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.accent = const Color(0xFFFEB03C),
    this.size = 46,
    this.tooltip,
    this.child,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color accent;
  final double size;
  final String? tooltip;

  /// Optional replacement for the icon (e.g. a progress spinner).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final dark = Neu.isDark(context);
    final fg = enabled
        ? (dark
            ? Color.alphaBlend(accent.withValues(alpha: 0.42), Colors.white)
            : Color.alphaBlend(Colors.black.withValues(alpha: 0.42), accent))
        : (dark ? const Color(0xFF6B7482) : const Color(0xFF9AA6B5));

    final button = NeuTappable(
      onTap: onPressed,
      radius: size / 2,
      width: size,
      height: size,
      glow: enabled ? accent : null,
      alignment: Alignment.center,
      child: child ?? Icon(icon, color: fg, size: size * 0.44),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
