import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '/backend/supabase/supabase_config.dart';
import '/flutter_flow/flutter_flow_util.dart';

Future<String?> geminiGenerateText(
  BuildContext context,
  String prompt,
) =>
    _invokeGemini(context, {
      'action': 'generateText',
      'prompt': prompt,
      'model': 'gemini-1.5-pro',
    });

Future<String?> geminiCountTokens(
  BuildContext context,
  String prompt,
) =>
    _invokeGemini(context, {
      'action': 'countTokens',
      'prompt': prompt,
      'model': 'gemini-1.5-pro',
    });

Future<Uint8List> loadImageBytesFromUrl(String imageUrl) async {
  final response = await http.get(Uri.parse(imageUrl));

  if (response.statusCode == 200) {
    return response.bodyBytes;
  } else {
    throw Exception('Failed to load image');
  }
}

Future<String?> geminiTextFromImage(
  BuildContext context,
  String prompt, {
  String? imageNetworkUrl = '',
  FFUploadedFile? uploadImageBytes,
}) async {
  assert(
    imageNetworkUrl != null || uploadImageBytes != null,
    'Either imageNetworkUrl or uploadImageBytes must be provided.',
  );

  final imageBytes = uploadImageBytes != null
      ? uploadImageBytes.bytes
      : await loadImageBytesFromUrl(imageNetworkUrl!);

  return _invokeGemini(context, {
    'action': 'textFromImage',
    'prompt': prompt,
    'model': 'gemini-1.5-flash',
    'imageBase64': base64Encode(imageBytes!),
    'mimeType': 'image/jpeg',
  });
}

Future<String?> _invokeGemini(
  BuildContext context,
  Map<String, dynamic> body,
) async {
  try {
    final response = await supabaseClient.functions.invoke(
      'gemini',
      body: body,
    );
    if (response.status < 200 || response.status >= 300) {
      showSnackbar(context, 'Gemini request failed: ${response.data}');
      return null;
    }
    final data = response.data;
    if (data is Map && data['text'] != null) {
      return data['text'].toString();
    }
    return data?.toString();
  } catch (e) {
    showSnackbar(context, e.toString());
    return null;
  }
}
