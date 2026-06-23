import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ImageSourcePickerDialogWidget extends StatelessWidget {
  const ImageSourcePickerDialogWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.takePhotoLabel,
    required this.takePhotoSubtitle,
    required this.uploadLabel,
    required this.uploadSubtitle,
    required this.onTakePhoto,
    required this.onUploadImage,
  });

  final String title;
  final String subtitle;
  final String takePhotoLabel;
  final String takePhotoSubtitle;
  final String uploadLabel;
  final String uploadSubtitle;
  final Future<void> Function() onTakePhoto;
  final Future<void> Function() onUploadImage;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 640.0;

    return SafeArea(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24.0),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 600.0,
            maxHeight: size.height * 0.85,
          ),
          child: Material(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 14, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: FlutterFlowTheme.of(context)
                                  .titleLarge
                                  .override(
                                    font: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w700,
                                    ),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.dmSans(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final stack = constraints.maxWidth < 420.0 || isCompact;

                        final takePhoto = _ActionCard(
                          icon: Icons.camera_alt_rounded,
                          title: takePhotoLabel,
                          subtitle: takePhotoSubtitle,
                          accent: DawaTokens.brandPrimary,
                          onTap: onTakePhoto,
                        );
                        final upload = _ActionCard(
                          icon: Icons.photo_library_outlined,
                          title: uploadLabel,
                          subtitle: uploadSubtitle,
                          accent: DawaTokens.brandPrimary,
                          onTap: onUploadImage,
                        );

                        if (stack) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              takePhoto,
                              const SizedBox(height: 12),
                              upload,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: takePhoto),
                            const SizedBox(width: 12),
                            Expanded(child: upload),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
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

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withOpacity(0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async => onTap(),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w700,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.0,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.dmSans(),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
