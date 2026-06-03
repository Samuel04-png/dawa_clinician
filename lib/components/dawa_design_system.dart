import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DawaTokens {
  const DawaTokens._();

  static const brandPrimary = Color(0xFF1E3A8A);
  static const brandPrimaryLight = Color(0xFF3B5FCF);
  static const brandPrimaryPale = Color(0xFFEEF2FF);
  static const brandAccent = Color(0xFF4B5F8F);
  static const statusSuccess = Color(0xFF16A34A);
  static const statusSuccessText = Color(0xFF15803D);
  static const statusSuccessBg = Color(0xFFDCFCE7);
  static const statusWarning = Color(0xFFD97706);
  static const statusWarningText = Color(0xFFB45309);
  static const statusWarningBg = Color(0xFFFEF3C7);
  static const statusDanger = Color(0xFFDC2626);
  static const statusDangerText = Color(0xFFB91C1C);
  static const statusDangerBg = Color(0xFFFEE2E2);
  static const statusInfo = Color(0xFF1E3A8A);
  static const statusInfoBg = Color(0xFFEEF2FF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF8FAFC);
  static const surfaceTertiary = Color(0xFFF1F5F9);
  static const border = Color(0xFFE2E8F0);
  static const borderStrong = Color(0xFFCBD5E1);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF94A3B8);
  static const textInverse = Color(0xFFFFFFFF);

  static const radiusSm = 6.0;
  static const radiusMd = 10.0;
  static const radiusLg = 14.0;
  static const radiusXl = 20.0;

  static const shadowSm = [
    BoxShadow(
      blurRadius: 3,
      spreadRadius: 0,
      color: Color(0x0F000000),
      offset: Offset(0, 1),
    ),
    BoxShadow(
      blurRadius: 2,
      spreadRadius: 0,
      color: Color(0x0A000000),
      offset: Offset(0, 1),
    ),
  ];

  static const shadowMd = [
    BoxShadow(
      blurRadius: 12,
      spreadRadius: 0,
      color: Color(0x14000000),
      offset: Offset(0, 4),
    ),
    BoxShadow(
      blurRadius: 4,
      spreadRadius: 0,
      color: Color(0x0A000000),
      offset: Offset(0, 2),
    ),
  ];

  static const shadowLg = [
    BoxShadow(
      blurRadius: 30,
      spreadRadius: 0,
      color: Color(0x1A000000),
      offset: Offset(0, 10),
    ),
  ];
}

class DawaTextStyles {
  const DawaTextStyles._();

  static TextStyle get pageTitle => GoogleFonts.dmSans(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get cardTitle => GoogleFonts.dmSans(
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get body => GoogleFonts.dmSans(
        fontSize: 14,
        height: 1.6,
      );

  static TextStyle get secondary => GoogleFonts.dmSans(
        fontSize: 13,
        height: 1.45,
      );

  static TextStyle get label => GoogleFonts.dmSans(
        fontSize: 12,
        height: 1.2,
        letterSpacing: 0.72,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get statNumber => GoogleFonts.dmSans(
        fontSize: 28,
        height: 1,
        fontWeight: FontWeight.w700,
      );
}

class DawaCard extends StatelessWidget {
  const DawaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.urgent = false,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool urgent;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF151B2A) : DawaTokens.surface;
    final border = isDark ? const Color(0xFF2B3443) : DawaTokens.border;
    final shadow = isDark ? <BoxShadow>[] : DawaTokens.shadowSm;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        border: Border.all(color: border),
        boxShadow: shadow,
      ),
      child: child,
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class DawaAvatarCircle extends StatelessWidget {
  const DawaAvatarCircle({
    super.key,
    required this.name,
    this.moduleColor = DawaTokens.brandPrimary,
    this.size = 40,
    this.photoUrl,
  });

  final String name;
  final Color moduleColor;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: moduleColor.withOpacity(0.14),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoUrl == null || photoUrl!.isEmpty
          ? Center(
              child: Text(
                initials,
                style: GoogleFonts.dmSans(
                  color: moduleColor,
                  fontSize: size <= 34 ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Image.network(photoUrl!, fit: BoxFit.cover),
    );
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'PT';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}

class DawaStatusBadge extends StatelessWidget {
  const DawaStatusBadge({
    super.key,
    required this.status,
    this.label,
  });

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final spec = _specFor(status);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 170),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: spec.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: spec.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(spec.icon, size: 13, color: spec.foreground),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label ?? spec.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.dmSans(
                  color: spec.foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static _StatusSpec _specFor(String rawStatus) {
    final normalized = rawStatus
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalized) {
      case 'completed':
      case 'complete':
        return const _StatusSpec(
          label: 'Completed',
          icon: Icons.check_rounded,
          background: DawaTokens.statusSuccessBg,
          foreground: DawaTokens.statusSuccessText,
          border: DawaTokens.statusSuccess,
        );
      case 'needs_review':
      case 'review':
      case 'suspicious':
        return _StatusSpec(
          label: normalized == 'suspicious' ? 'Suspicious' : 'Needs Review',
          icon: Icons.priority_high_rounded,
          background: DawaTokens.statusWarningBg,
          foreground: DawaTokens.statusWarningText,
          border: DawaTokens.statusWarning,
        );
      case 'normal':
        return const _StatusSpec(
          label: 'Normal',
          icon: Icons.check_rounded,
          background: DawaTokens.statusSuccessBg,
          foreground: DawaTokens.statusSuccessText,
          border: DawaTokens.statusSuccess,
        );
      case 'pending':
      case 'scheduled':
        return const _StatusSpec(
          label: 'Pending',
          icon: Icons.circle_rounded,
          background: DawaTokens.surfaceTertiary,
          foreground: DawaTokens.textSecondary,
          border: DawaTokens.borderStrong,
        );
      case 'missing_data':
        return const _StatusSpec(
          label: 'Missing Data',
          icon: Icons.warning_amber_rounded,
          background: DawaTokens.statusDangerBg,
          foreground: DawaTokens.statusDangerText,
          border: DawaTokens.statusDanger,
        );
      case 'had_first_encounter':
        return const _StatusSpec(
          label: 'Had first encounter',
          icon: Icons.check_rounded,
          background: DawaTokens.statusSuccessBg,
          foreground: DawaTokens.statusSuccessText,
          border: DawaTokens.statusSuccess,
        );
      case 'new':
        return const _StatusSpec(
          label: 'New',
          icon: Icons.fiber_new_rounded,
          background: DawaTokens.statusWarningBg,
          foreground: DawaTokens.statusWarningText,
          border: DawaTokens.statusWarning,
        );
      case 'active':
        return const _StatusSpec(
          label: 'Active',
          icon: Icons.circle_rounded,
          background: DawaTokens.statusInfoBg,
          foreground: DawaTokens.statusInfo,
          border: DawaTokens.statusInfo,
        );
      default:
        return _StatusSpec(
          label: rawStatus.isEmpty ? 'Pending' : rawStatus,
          icon: Icons.circle_rounded,
          background: DawaTokens.surfaceTertiary,
          foreground: DawaTokens.textSecondary,
          border: DawaTokens.borderStrong,
        );
    }
  }
}

class DawaAIConfidenceBar extends StatelessWidget {
  const DawaAIConfidenceBar({
    super.key,
    required this.analysis,
    this.confidence,
  });

  final String analysis;
  final double? confidence;

  @override
  Widget build(BuildContext context) {
    final parsed = confidence ?? confidenceFromText(analysis);
    final cleanText = _cleanAnalysisText(analysis);
    final fillColor = parsed >= 90
        ? DawaTokens.statusSuccess
        : parsed >= 75
            ? DawaTokens.statusWarning
            : DawaTokens.statusDanger;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        Text(
          'AI:',
          style: GoogleFonts.dmSans(
            color: DawaTokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            cleanText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              color: DawaTokens.brandPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 4,
              value: (parsed.clamp(0, 100)) / 100,
              backgroundColor: DawaTokens.border,
              valueColor: AlwaysStoppedAnimation<Color>(fillColor),
            ),
          ),
        ),
        Text(
          '${parsed.round()}%',
          style: GoogleFonts.dmSans(
            color: DawaTokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static double confidenceFromText(String value) {
    final match = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(value);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  String _cleanAnalysisText(String value) {
    var text = value.trim();
    text =
        text.replaceAll(RegExp(r'AI\s*analysis:\s*', caseSensitive: false), '');
    text = text.replaceAll(
        RegExp(r'AI\s*confidence\s*', caseSensitive: false), '');
    text = text.replaceAll(
        RegExp(r';?\s*confidence\s*\d+(?:\.\d+)?%\.?', caseSensitive: false),
        '');
    text = text.replaceAll(RegExp(r'\d+(?:\.\d+)?%\s*-\s*'), '');
    return text.trim().isEmpty ? 'Analysis available' : text.trim();
  }
}

class DawaStatCard extends StatelessWidget {
  const DawaStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = DawaTokens.brandPrimary,
    this.width,
    this.accentBorder = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? width;
  final bool accentBorder;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isUrgent = label.toLowerCase().contains('missing');
    final numberColor = isUrgent
        ? DawaTokens.statusDanger
        : Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      width: width,
      child: DawaCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth <= 230;

            return Container(
              padding: const EdgeInsets.all(16),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatIconWrap(icon: icon, color: color, size: 36),
                        const SizedBox(height: 12),
                        Text(
                          value,
                          style: DawaTextStyles.statNumber
                              .copyWith(color: numberColor),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DawaTextStyles.secondary.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                value,
                                style: DawaTextStyles.statNumber
                                    .copyWith(color: numberColor),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: DawaTextStyles.secondary
                                    .copyWith(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _StatIconWrap(icon: icon, color: color, size: 38),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _StatIconWrap extends StatelessWidget {
  const _StatIconWrap({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: size <= 36 ? 19 : 20),
    );
  }
}

class _StatusSpec {
  const _StatusSpec({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color border;
}
