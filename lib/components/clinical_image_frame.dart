import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Places acquisition metadata against the actual fitted image, not its
/// surrounding letterbox. Resolving the provider only reads local image bytes.
class ClinicalImageFrame extends StatefulWidget {
  const ClinicalImageFrame(
      {super.key, required this.bytes, required this.badge});
  final Uint8List bytes;
  final Widget badge;
  @override
  State<ClinicalImageFrame> createState() => _ClinicalImageFrameState();
}

class _ClinicalImageFrameState extends State<ClinicalImageFrame> {
  ImageStream? _stream;
  late final ImageStreamListener _listener;
  Size? _imageSize;
  @override
  void initState() {
    super.initState();
    _listener = ImageStreamListener((info, _) {
      if (mounted)
        setState(() => _imageSize =
            Size(info.image.width.toDouble(), info.image.height.toDouble()));
      info.dispose();
    }, onError: (Object _, StackTrace? __) {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ClinicalImageFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) _resolve();
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    _imageSize = null;
    _stream = MemoryImage(widget.bytes)
        .resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final area = constraints.biggest;
        final size = _imageSize;
        final rect = size == null
            ? Offset.zero & area
            : Alignment.center.inscribe(
                applyBoxFit(BoxFit.contain, size, area).destination,
                Offset.zero & area);
        return Stack(fit: StackFit.expand, children: [
          Image.memory(widget.bytes,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(
                  child:
                      Text('Image preview unavailable. Replace the image.'))),
          if (size != null)
            Positioned(
                left: rect.left + 8,
                top: rect.top + 8,
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: (rect.width - 16).clamp(0, double.infinity)),
                    child: widget.badge)),
        ]);
      });
}
