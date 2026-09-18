import 'dart:convert';

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
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
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
        return 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
    }
    return null;
  }
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────
