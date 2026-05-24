import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '/components/dawa_design_system.dart';

// ─── APP STATE ENUMS ──────────────────────────────────────────────────────────

enum AppState {
  splash,
  login,
  signup,
  otp,
  getStarted,
  dashboard,
  results,
  viaTest,
  terms
}

enum DashboardTab { home, patients, history, profile }

enum PatientStatus { normal, suspicious, pending, untested }

enum RiskLevel { low, medium, high }

enum SuspicionLevel { low, medium, high }

// ─── PATIENT MODEL ────────────────────────────────────────────────────────────

class Patient {
  final String id;
  final String name;
  final int age;
  final String contact;
  final DateTime? lastTestDate;
  final PatientStatus status;
  final RiskLevel riskLevel;
  final String? imageUrl;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.contact,
    this.lastTestDate,
    required this.status,
    required this.riskLevel,
    this.imageUrl,
  });

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      age: json['age'] ?? 0,
      contact: json['contact'] ?? '',
      lastTestDate: json['lastTestDate'] != null
          ? DateTime.parse(json['lastTestDate'])
          : null,
      status: PatientStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => PatientStatus.untested,
      ),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['riskLevel'],
        orElse: () => RiskLevel.low,
      ),
      imageUrl: json['imageUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'contact': contact,
        'lastTestDate': lastTestDate?.toIso8601String(),
        'status': status.toString().split('.').last,
        'riskLevel': riskLevel.toString().split('.').last,
        'imageUrl': imageUrl,
      };

  String get statusString {
    switch (status) {
      case PatientStatus.normal:
        return 'Normal';
      case PatientStatus.suspicious:
        return 'Suspicious';
      case PatientStatus.pending:
        return 'Pending';
      case PatientStatus.untested:
        return 'Untested';
    }
  }

  String get riskLevelString {
    switch (riskLevel) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
    }
  }
}

// ─── VIA TEST RECORD ──────────────────────────────────────────────────────────

class VIATestRecord {
  final String id;
  final String patientId;
  final String patientName;
  final DateTime date;
  final String result;
  final String notes;
  final String? imageUri;
  final String? aiAnalysis;

  VIATestRecord({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.date,
    required this.result,
    required this.notes,
    this.imageUri,
    this.aiAnalysis,
  });

  factory VIATestRecord.fromJson(Map<String, dynamic> json) {
    return VIATestRecord(
      id: json['id'] ?? '',
      patientId: json['patientId'] ?? '',
      patientName: json['patientName'] ?? '',
      date: DateTime.parse(json['date']),
      result: json['result'] ?? '',
      notes: json['notes'] ?? '',
      imageUri: json['imageUri'],
      aiAnalysis: json['aiAnalysis'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'patientName': patientName,
        'date': date.toIso8601String(),
        'result': result,
        'notes': notes,
        'imageUri': imageUri,
        'aiAnalysis': aiAnalysis,
      };
}

// ─── ANALYSIS RESULT ──────────────────────────────────────────────────────────

class AnalysisResult {
  final String imageUrl;
  final String label;
  final double confidence;
  final SuspicionLevel suspicionLevel;
  final String recommendation;
  final Map<String, dynamic>? rawOutput;
  final String? error;

  AnalysisResult({
    required this.imageUrl,
    required this.label,
    required this.confidence,
    required this.suspicionLevel,
    required this.recommendation,
    this.rawOutput,
    this.error,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      imageUrl: json['imageUrl'] ?? '',
      label: json['label'] ?? '',
      confidence: (json['confidence'] as num).toDouble(),
      suspicionLevel: SuspicionLevel.values.firstWhere(
        (e) => e.toString().split('.').last == json['suspicionLevel'],
        orElse: () => SuspicionLevel.low,
      ),
      recommendation: json['recommendation'] ?? '',
      rawOutput: json['rawOutput'],
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() => {
        'imageUrl': imageUrl,
        'label': label,
        'confidence': confidence,
        'suspicionLevel': suspicionLevel.toString().split('.').last,
        'recommendation': recommendation,
        'rawOutput': rawOutput,
        'error': error,
      };

  String get suspicionLevelString {
    switch (suspicionLevel) {
      case SuspicionLevel.low:
        return 'Low';
      case SuspicionLevel.medium:
        return 'Medium';
      case SuspicionLevel.high:
        return 'High';
    }
  }

  Color get suspicionColor {
    switch (suspicionLevel) {
      case SuspicionLevel.high:
        return DawaTokens.statusDanger;
      case SuspicionLevel.medium:
        return DawaTokens.statusWarning;
      case SuspicionLevel.low:
        return DawaTokens.statusSuccess;
    }
  }
}

// ─── USER PROFILE ─────────────────────────────────────────────────────────────

class UserProfile {
  final String name;
  final String role;
  final String email;
  final String clinic;
  final int credits;

  UserProfile({
    required this.name,
    required this.role,
    required this.email,
    required this.clinic,
    required this.credits,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        role: json['role'] ?? '',
        email: json['email'] ?? '',
        clinic: json['clinic'] ?? '',
        credits: json['credits'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'email': email,
        'clinic': clinic,
        'credits': credits,
      };
}

// ─── SCREENING DATA (charts) ──────────────────────────────────────────────────

class ScreeningData {
  final String month;
  final int normal;
  final int lowGrade;
  final int highGrade;

  ScreeningData({
    required this.month,
    required this.normal,
    required this.lowGrade,
    required this.highGrade,
  });
}

// ─── GRADIO SERVICE ───────────────────────────────────────────────────────────
//
// How the real model works (from app.py):
//   Backbone : kmunzwa/medsiglip-diagnosis  (SiglipModel – vision encoder)
//   Head     : classifier.pt  →  Linear(1152,128) → ReLU → Dropout → Linear(128,5)
//   Classes  : ["Negative", "CIN1", "CIN2", "CIN3", "Positive"]
//
// The Gradio Space outputs a plain-text Textbox string, exactly:
//
//    Predicted: CIN2
//
//    Probabilities:
//     Negative: 0.0123
//     CIN1: 0.0456
//     CIN2: 0.8921
//     CIN3: 0.0312
//     Positive: 0.0188
//
// We upload the image, call /call/predict, poll the SSE result, then parse
// that plain-text string to get the class and confidence.

class GradioService {
  static const String _baseUrl =
      'https://khanyitapiwa00-cervical-cancer-ai-demo.hf.space';

  // ── Public entry point ─────────────────────────────────────────────────────
  static Future<AnalysisResult> analyzeVIAImage(String base64Image) async {
    try {
      // 1. Decode base64 → raw bytes
      final rawBase64 =
          base64Image.contains(',') ? base64Image.split(',').last : base64Image;
      final imageBytes = base64Decode(rawBase64);

      // 2. Detect MIME type & extension
      String mimeType = 'image/jpeg';
      String extension = 'jpg';
      if (base64Image.startsWith('data:')) {
        mimeType = base64Image.split(';').first.replaceFirst('data:', '');
        final ext = mimeType.split('/').last;
        extension = ext == 'jpeg' ? 'jpg' : ext;
      }

      // 3. Upload → predict → poll
      final uploadedPath = await _uploadImage(imageBytes, mimeType, extension);
      debugPrint('[Gradio] uploaded: $uploadedPath');

      final eventId = await _submitPredict(uploadedPath);
      debugPrint('[Gradio] event_id: $eventId');

      final rawText = await _pollResult(eventId);
      debugPrint('[Gradio] raw text:\n$rawText');

      // 4. Parse the plain-text Textbox response
      return _parseGradioText(base64Image, rawText);
    } catch (e) {
      debugPrint('[Gradio] error: $e');
      return AnalysisResult(
        imageUrl: base64Image,
        label: 'Network Error',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'Unable to reach the AI model. Please check your internet connection and try again.',
        error: e.toString(),
      );
    }
  }

  // ── Step 1: Upload image via multipart/form-data ───────────────────────────
  static Future<String> _uploadImage(
      List<int> bytes, String mimeType, String extension) async {
    final boundary =
        '----GradioBoundary${DateTime.now().millisecondsSinceEpoch}';
    final filename = 'cervix.$extension';

    final body = <int>[];
    body.addAll(utf8.encode('--$boundary\r\n'));
    body.addAll(utf8.encode(
        'Content-Disposition: form-data; name="files"; filename="$filename"\r\n'));
    body.addAll(utf8.encode('Content-Type: $mimeType\r\n\r\n'));
    body.addAll(bytes);
    body.addAll(utf8.encode('\r\n--$boundary--\r\n'));

    final response = await http.post(
      Uri.parse('$_baseUrl/upload'),
      headers: {'Content-Type': 'multipart/form-data; boundary=$boundary'},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Image upload failed (${response.statusCode}): ${response.body}');
    }

    // Returns JSON array: ["/tmp/gradio/abc/cervix.jpg"]
    final List<dynamic> paths = jsonDecode(response.body) as List<dynamic>;
    if (paths.isEmpty) throw Exception('Upload returned empty path list');
    return paths.first as String;
  }

  // ── Step 2: Submit prediction job ─────────────────────────────────────────
  static Future<String> _submitPredict(String uploadedPath) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/call/predict'),
      headers: {'Content-Type': 'application/json'},
      // Gradio Image(type="pil") accepts a file-path object
      body: jsonEncode({
        'data': [
          {'path': uploadedPath}
        ]
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Predict submit failed (${response.statusCode}): ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final eventId = json['event_id'] as String?;
    if (eventId == null || eventId.isEmpty) {
      throw Exception('No event_id in response: ${response.body}');
    }
    return eventId;
  }

  // ── Step 3: Poll SSE result ────────────────────────────────────────────────
  static Future<String> _pollResult(String eventId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/call/predict/$eventId'),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Result poll failed (${response.statusCode}): ${response.body}');
    }

    // SSE body looks like:
    //   event: complete
    //   data: ["\" Predicted: CIN2\\n\\n Probabilities:\\n ..."]
    //
    // We grab the last "data:" line (complete event overwrites process events).
    String? dataLine;
    for (final line in response.body.split('\n')) {
      if (line.startsWith('data:')) {
        dataLine = line.replaceFirst('data:', '').trim();
      }
    }

    if (dataLine == null || dataLine.isEmpty) {
      throw Exception('No data line in SSE response:\n${response.body}');
    }

    // The payload is a JSON array; element 0 is the Textbox string
    final dynamic decoded = jsonDecode(dataLine);
    if (decoded is List && decoded.isNotEmpty) {
      return decoded.first.toString();
    }
    return decoded.toString();
  }

  // ── Step 4: Parse the Textbox plain-text string from app.py ───────────────
  //
  // app.py builds the string exactly as:
  //   " Predicted: {CLASSES[predicted_class]}\n\n"
  //   " Probabilities:\n"
  //   "  {cls}: {prob:.4f}\n"   ← one line per class
  //
  static AnalysisResult _parseGradioText(String imageUrl, String text) {
    String predictedClass = '';
    double confidence = 0.0;

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // ── "Predicted: CIN2" line ─────────────────────────────────────────
      if (trimmed.toLowerCase().contains('predicted:')) {
        predictedClass = trimmed
            .split(':')
            .last
            .trim()
            // Strip any leading emoji / special chars app.py may add
            .replaceAll(RegExp(r'^[^\w]+'), '')
            .trim();
        continue;
      }

      // ── "CIN2: 0.8921" probability lines ──────────────────────────────
      // Only read the line that matches the predicted class so we get its prob
      if (predictedClass.isNotEmpty) {
        final colonIdx = trimmed.indexOf(':');
        if (colonIdx != -1) {
          final cls = trimmed.substring(0, colonIdx).trim();
          final prob = double.tryParse(trimmed.substring(colonIdx + 1).trim());
          if (cls.toLowerCase() == predictedClass.toLowerCase() &&
              prob != null) {
            confidence = prob * 100;
          }
        }
      }
    }

    debugPrint(
        '[Gradio] parsed → class="$predictedClass"  confidence=${confidence.toStringAsFixed(1)}%');

    if (predictedClass.isEmpty) {
      return AnalysisResult(
        imageUrl: imageUrl,
        label: 'Parse Error',
        confidence: 0,
        suspicionLevel: SuspicionLevel.low,
        recommendation:
            'The AI model returned an unrecognised response. Please try again.',
        error: 'Raw response:\n$text',
      );
    }

    return _buildResult(imageUrl, predictedClass, confidence);
  }

  // ── Map class name → AnalysisResult ───────────────────────────────────────
  //
  // Covers every label the app.py CLASSES list can produce:
  //   ["Negative", "CIN1", "CIN2", "CIN3", "Positive"]
  //
  static AnalysisResult _buildResult(
      String imageUrl, String cls, double confidence) {
    final key = cls.toLowerCase().trim();

    SuspicionLevel suspicion;
    String displayLabel;
    String recommendation;

    switch (key) {
      case 'positive':
        suspicion = SuspicionLevel.high;
        displayLabel = 'Positive – Cancer Suspected';
        recommendation =
            'Urgent oncology referral required. Initiate the cancer management '
            'pathway per Zambian MoH guidelines immediately — do not delay.';
        break;

      case 'cin3':
        suspicion = SuspicionLevel.high;
        displayLabel = 'CIN3 – Severe Dysplasia';
        recommendation = 'Refer for colposcopy and biopsy immediately. '
            '"See and Treat" with LEEP / CKC is strongly recommended '
            'if the patient is eligible.';
        break;

      case 'cin2':
        suspicion = SuspicionLevel.high;
        displayLabel = 'CIN2 – Moderate Dysplasia';
        recommendation = 'Refer for colposcopy and directed biopsy. '
            'Consider "See and Treat" if colposcopy is unavailable. '
            'Schedule follow-up in 6 months.';
        break;

      case 'cin1':
        suspicion = SuspicionLevel.medium;
        displayLabel = 'CIN1 – Mild Dysplasia';
        recommendation =
            'Repeat VIA in 12 months. Counsel patient on risk factors '
            '(HPV, smoking, multiple partners). '
            'Refer for HPV DNA triage testing if available in your facility.';
        break;

      case 'negative':
      default:
        suspicion = SuspicionLevel.low;
        displayLabel = 'Negative – No Abnormality Detected';
        recommendation =
            'No immediate action required. Schedule routine cervical '
            'screening in 3–5 years per Zambian MoH / WHO guidelines.';
    }

    return AnalysisResult(
      imageUrl: imageUrl,
      label: displayLabel,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      suspicionLevel: suspicion,
      recommendation: recommendation,
    );
  }
}

// ─── IMAGE PICKER SERVICE ─────────────────────────────────────────────────────

class ImagePickerService {
  static final ImagePicker _picker = ImagePicker();

  static Future<String?> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final b64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$b64';
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
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        final b64 = base64Encode(bytes);
        return 'data:image/jpeg;base64,$b64';
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
    }
    return null;
  }
}

// ─── MOCK DATA ────────────────────────────────────────────────────────────────

class MockData {
  static List<Patient> getPatients() {
    return List.generate(20, (index) {
      final names = [
        "Alice Mumba",
        "Beatrice Zulu",
        "Chipo Banda",
        "Dorothy Lungu",
        "Esther Phiri",
        "Florence Sakala",
        "Grace Mwape",
        "Hilda Tembo",
        "Ireen Mulenga",
        "Joyce Ngoma",
        "Kondwani Daka",
        "Lillian Chama",
        "Mary Soko",
        "Nancy Kaira",
        "Olive Mwanza",
        "Patricia Gondwe",
        "Queen Nyirenda",
        "Ruth Kangwa",
        "Sarah Mbewe",
        "Theresa Singogo",
      ];

      final status = (index == 0 || index == 2)
          ? PatientStatus.suspicious
          : index % 5 == 0
              ? PatientStatus.pending
              : PatientStatus.normal;

      final riskLevel =
          (index == 0 || index == 2) ? RiskLevel.high : RiskLevel.low;

      return Patient(
        id: 'DM-${1000 + index}',
        name: names[index],
        age: 25 + (index % 20),
        contact: '097${1000000 + (index * 111111)}',
        lastTestDate: DateTime.now().subtract(Duration(days: 30 - index)),
        status: status,
        riskLevel: riskLevel,
      );
    });
  }

  static List<VIATestRecord> getHistoryRecords() {
    return [
      VIATestRecord(
        id: '1',
        patientId: 'DM-1001',
        patientName: 'Beatrice Zulu',
        date: DateTime(2025, 11, 19),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 94%',
      ),
      VIATestRecord(
        id: '2',
        patientId: 'DM-1002',
        patientName: 'Chipo Banda',
        date: DateTime(2025, 11, 18),
        result: 'Suspicious',
        notes: 'Requires follow-up',
        aiAnalysis: 'Confidence: 89%',
      ),
      VIATestRecord(
        id: '3',
        patientId: 'DM-1003',
        patientName: 'Dorothy Lungu',
        date: DateTime(2025, 11, 17),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 92%',
      ),
      VIATestRecord(
        id: '4',
        patientId: 'DM-1004',
        patientName: 'Esther Phiri',
        date: DateTime(2025, 11, 16),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 96%',
      ),
      VIATestRecord(
        id: '5',
        patientId: 'DM-1000',
        patientName: 'Alice Mumba',
        date: DateTime(2025, 11, 15),
        result: 'Normal',
        notes: 'Routine screening',
        aiAnalysis: 'Confidence: 91%',
      ),
    ];
  }

  static List<ScreeningData> getScreeningData() {
    return [
      ScreeningData(month: 'Jun', normal: 42, lowGrade: 5, highGrade: 2),
      ScreeningData(month: 'Jul', normal: 55, lowGrade: 8, highGrade: 1),
      ScreeningData(month: 'Aug', normal: 48, lowGrade: 6, highGrade: 3),
      ScreeningData(month: 'Sep', normal: 60, lowGrade: 10, highGrade: 2),
      ScreeningData(month: 'Oct', normal: 72, lowGrade: 12, highGrade: 4),
      ScreeningData(month: 'Nov', normal: 65, lowGrade: 8, highGrade: 3),
    ];
  }
}
