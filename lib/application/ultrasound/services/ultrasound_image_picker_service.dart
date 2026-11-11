import '/services/edge_device/edge_image_input.dart';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class UltrasoundImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        return EdgeImageInput.fromBytes(bytes).dataUri;
      }
    } catch (e) {
      debugPrint('Error picking image: ${e.runtimeType}');
    }
    return null;
  }

  static Future<String?> captureImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        return EdgeImageInput.fromBytes(bytes).dataUri;
      }
    } catch (e) {
      debugPrint('Error capturing image: ${e.runtimeType}');
    }
    return null;
  }
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────
