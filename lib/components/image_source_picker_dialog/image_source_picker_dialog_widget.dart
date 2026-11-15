import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ImageSourcePickerDialogWidget extends StatefulWidget {
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
  State<ImageSourcePickerDialogWidget> createState() =>
      _ImageSourcePickerDialogWidgetState();
}

class _ImageSourcePickerDialogWidgetState
    extends State<ImageSourcePickerDialogWidget> {
  bool _choosing = false;
  String? _error;

  Future<void> _choose(Future<void> Function() action) async {
    if (_choosing) return;
    setState(() {
      _choosing = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(() =>
            _error = 'Could not open the image source. Please try again.');
    } finally {
      if (mounted) setState(() => _choosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight:
                (size.height - MediaQuery.viewInsetsOf(context).vertical - 48)
                    .clamp(120.0, 720.0)),
        child: Material(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                  child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(widget.title,
                                          style: DawaTextStyles.pageTitle),
                                      const SizedBox(height: 8),
                                      Text(widget.subtitle,
                                          style: DawaTextStyles.secondary),
                                    ])),
                                IconButton(
                                    tooltip: 'Close image selection',
                                    onPressed: _choosing
                                        ? null
                                        : () =>
                                            Navigator.of(context).maybePop(),
                                    icon: const Icon(Icons.close_rounded)),
                              ])),
                      const Divider(height: 1),
                      if (_choosing)
                        const LinearProgressIndicator(
                            semanticsLabel: 'Opening image source'),
                      Padding(
                          padding: const EdgeInsets.all(20),
                          child: LayoutBuilder(builder: (context, constraints) {
                            final takePhoto = _ActionCard(
                                icon: Icons.camera_alt_outlined,
                                title: widget.takePhotoLabel,
                                subtitle: widget.takePhotoSubtitle,
                                accent: DawaTokens.brandPrimary,
                                onTap: _choosing
                                    ? null
                                    : () => _choose(widget.onTakePhoto));
                            final upload = _ActionCard(
                                icon: Icons.photo_library_outlined,
                                title: widget.uploadLabel,
                                subtitle: widget.uploadSubtitle,
                                accent: DawaTokens.brandPrimary,
                                onTap: _choosing
                                    ? null
                                    : () => _choose(widget.onUploadImage));
                            if (constraints.maxWidth < 420 ||
                                MediaQuery.textScalerOf(context).scale(14) >
                                    21) {
                              return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    takePhoto,
                                    const SizedBox(height: 12),
                                    upload
                                  ]);
                            }
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: takePhoto),
                                  const SizedBox(width: 12),
                                  Expanded(child: upload)
                                ]);
                          })),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Semantics(
                                liveRegion: true,
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: DawaTokens.statusDanger)))),
                    ]),
              )),
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                          onPressed: _choosing
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48)),
                          child: const Text('Cancel')))),
            ])),
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
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        enabled: onTap != null,
        child: Material(
          color: accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap == null ? null : () async => onTap!(),
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
        ));
  }
}
