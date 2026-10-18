import 'package:flutter/material.dart';

/// Duolingo-flavored colors and reusable widgets.
///
/// Kept lightweight (no packages, no images): the signature look comes from
/// flat saturated colors, chunky rounded shapes and the 3D "bottom edge"
/// created with a hard offset shadow.
abstract final class DuoColors {
  // Palette inspired by the reference screenshot in `images/`:
  // gold-orange #FEB03C, pink #FE6C8F, light blue #6F9EFD, and charcoal
  // dark surfaces with a subtle teal cast.
  static const green = Color(0xFFFEB03C);
  static const greenLight = Color(0xFFFFE8C7);
  static const greenBorder = Color(0xFFFFD581);
  static const greenText = Color(0xFF8A5A00);

  static const blue = Color(0xFF6F9EFD);
  static const blueLight = Color(0xFFE3ECFF);
  static const blueBorder = Color(0xFFA9C4FF);
  static const blueText = Color(0xFF3D63C9);

  static const orange = Color(0xFFFE6C8F);
  static const orangeDark = Color(0xFFD14B74);

  static const red = Color(0xFFFF4B4B);
  static const redLight = Color(0xFFFFDFE0);
  static const redBorder = Color(0xFFFFB2B2);
  static const redText = Color(0xFFEA2B2B);

  static const teal = Color(0xFF35D0BA);
  static const tealDark = Color(0xFF1FA892);

  static const border = Color(0xFFE5E5E5);
  static const borderColor = Color(0xFFC7C7C7);
  static const disabledBg = Color(0xFFE5E5E5);
  static const disabledText = Color(0xFFAFAFAF);

  static const text = Color(0xFF413B33);
  static const textLight = Color(0xFF756E63);

  // Dark-mode surfaces (charcoal with a teal cast, per the reference).
  static const darkSurface = Color(0xFF1E2226);
  static const darkSurfaceBorder = Color(0xFF2A3134);
  static const darkSelectedBg = Color(0xFF202C4D);
  static const darkCorrectBg = Color(0xFF3A2A08);
  static const darkCorrectBorder = Color(0xFFFEB03C);
  static const darkIncorrectBg = Color(0xFF3A1622);
  static const darkIncorrectBorder = Color(0xFFFF8FA5);

  /// Blends ~24% black into [color] to get the darker 3D edge shade.
  static Color edge(Color color) =>
      Color.alphaBlend(const Color(0x3D000000), color);
}

/// Rounded filled button (flat, no 3D edge).
class DuoButton extends StatelessWidget {
  const DuoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = DuoColors.green,
    this.textColor = const Color(0xFF241A00),
    this.icon,
    this.minHeight = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;

    final bgColor = enabled ? color : DuoColors.disabledBg;
    final fgColor = enabled
        ? textColor
        : (isDark ? const Color(0xFFAFAFAF) : DuoColors.disabledText);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            height: minHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: fgColor, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: fgColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Side-by-side icon + bold number, as in the Duolingo top stats bar.
class DuoStat extends StatelessWidget {
  const DuoStat({
    super.key,
    required this.icon,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// Green rounded progress bar with the Duolingo look.
class DuoProgressBar extends StatelessWidget {
  const DuoProgressBar({super.key, required this.value});

  /// Progress from 0 to 1.
  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 14,
        backgroundColor: DuoColors.border,
        valueColor: const AlwaysStoppedAnimation<Color>(DuoColors.green),
      ),
    );
  }
}  /// Answer-choice card with bordered rounded look and
  /// selected/correct/incorrect color states.
enum DuoOptionState { normal, selected, correct, incorrect, muted }

class DuoOptionTile extends StatelessWidget {
  const DuoOptionTile({
    super.key,
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final DuoOptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color border;
    Color fg;
    switch (state) {
      case DuoOptionState.correct:
        bg = isDark ? DuoColors.darkCorrectBg : DuoColors.greenLight;
        border = isDark
            ? DuoColors.darkCorrectBorder
            : DuoColors.greenBorder;
        fg = isDark
            ? DuoColors.darkCorrectBorder
            : DuoColors.greenText;
        break;
      case DuoOptionState.incorrect:
        bg = isDark ? DuoColors.darkIncorrectBg : DuoColors.redLight;
        border = isDark
            ? DuoColors.darkIncorrectBorder
            : DuoColors.redBorder;
        fg = isDark
            ? DuoColors.darkIncorrectBorder
            : DuoColors.redText;
        break;
      case DuoOptionState.selected:
        bg = isDark ? DuoColors.darkSelectedBg : DuoColors.blueLight;
        border = isDark ? DuoColors.blue : DuoColors.blueBorder;
        fg = isDark ? DuoColors.blue : DuoColors.blueText;
        break;
      case DuoOptionState.muted:
        bg = isDark ? DuoColors.darkSurface : Colors.white;
        border = DuoColors.border;
        fg = isDark ? const Color(0xFFE7ECF0) : DuoColors.text;
        break;
      case DuoOptionState.normal:
        bg = isDark ? DuoColors.darkSurface : Colors.white;
        border =
            isDark ? DuoColors.darkSurfaceBorder : DuoColors.border;
        fg = isDark ? const Color(0xFFF1F7FB) : DuoColors.text;
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 2),
        boxShadow: [
          BoxShadow(color: border, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: state == DuoOptionState.muted ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-width bottom banner shown after answering — bright green when
/// correct, red when wrong, with a white continue-style button inside.
class DuoFeedbackBanner extends StatelessWidget {
  const DuoFeedbackBanner({
    super.key,
    required this.correct,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
    this.detail,
  });

  final bool correct;
  final String message;
  final String? detail;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bg = correct ? DuoColors.greenLight : DuoColors.redLight;
    final accent = correct ? DuoColors.greenText : DuoColors.redText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                correct
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: accent,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              style: TextStyle(
                color: accent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          DuoButton(
            label: buttonLabel,
            onPressed: onPressed,
            color: correct ? DuoColors.green : DuoColors.red,
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }
}
