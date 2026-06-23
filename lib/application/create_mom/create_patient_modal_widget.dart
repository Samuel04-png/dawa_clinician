import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class CreatePatientModalWidget extends StatefulWidget {
  const CreatePatientModalWidget({super.key});

  @override
  State<CreatePatientModalWidget> createState() =>
      _CreatePatientModalWidgetState();
}

class _CreatePatientModalWidgetState extends State<CreatePatientModalWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _occupationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  DateTime? _datePicked;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _datePicked ?? DateTime(1995),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(
          () => _datePicked = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_datePicked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a date of birth.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final generatedPassword = _passwordController.text.isEmpty
          ? functions.generateCustomPassword()
          : _passwordController.text;
      final email = _emailController.text.isEmpty
          ? functions.createUniqueEmail(
              _nameController.text,
              _datePicked!,
              _phoneController.text,
            )
          : _emailController.text;

      FFAppState().motherCreatedTime = getCurrentTimestamp;
      FFAppState().randomPasswordGenerated = generatedPassword;
      GoRouter.of(context).prepareAuthEvent();

      final user = await authManager.createAccountWithEmail(
        context,
        email,
        generatedPassword,
      );
      if (user == null) {
        if (mounted) setState(() => _saving = false);
        return;
      }

      await UserRecord.collection.doc(user.uid).update(
            createUserRecordData(
              role: 'Mother',
              createdTime: FFAppState().motherCreatedTime,
            ),
          );

      await MotherRecord.collection.doc().set(
            createMotherRecordData(
              dateOfBirth: _datePicked,
              occupation: _occupationController.text,
              address: _addressController.text,
              name: _nameController.text,
              phoneNumber: _phoneController.text,
            ),
          );

      final createdUser = await queryUserRecordOnce(
        queryBuilder: (userRecord) => userRecord.where(
          'created_time',
          isEqualTo: FFAppState().motherCreatedTime,
        ),
        singleRecord: true,
      ).then((s) => s.firstOrNull);

      final createdMother = await queryMotherRecordOnce(
        queryBuilder: (motherRecord) => motherRecord
            .where('name', isEqualTo: _nameController.text)
            .where('phone_number', isEqualTo: _phoneController.text),
        singleRecord: true,
      ).then((s) => s.firstOrNull);

      if (createdMother != null) {
        await createdMother.reference.update(
          createMotherRecordData(
            motherId: createdMother.reference.id,
            userId: createdUser?.reference,
          ),
        );
      }

      await SendSMSCall.call(
        email: createdUser?.email,
        password: generatedPassword,
        number: _phoneController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create patient: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: FlutterFlowTheme.of(context).primaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: FlutterFlowTheme.of(context).alternate),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(color: FlutterFlowTheme.of(context).primary),
        ),
      ),
      validator: (value) {
        if (!requiredField) {
          return null;
        }
        if ((value ?? '').trim().isEmpty) {
          return '$label is required';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 640.0;

    return SafeArea(
      child: Dialog(
        insetPadding: const EdgeInsets.all(24.0),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isCompact ? 20.0 : 28.0),
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
                              'Register New Patient',
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
                              'Create the patient record in a centered modal without leaving your current workspace.',
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
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildField(
                            controller: _nameController,
                            label: 'Name',
                            hint: 'Janet Zulu',
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _addressController,
                            label: 'Address',
                            hint: 'Libala Stage 1, Lusaka',
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _occupationController,
                            label: 'Occupation',
                            hint: 'Trader',
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _phoneController,
                            label: 'Phone Number',
                            keyboardType: TextInputType.phone,
                            hint: '+260...',
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _emailController,
                            label: 'Email Address',
                            keyboardType: TextInputType.emailAddress,
                            hint: 'Optional - leave blank to auto-generate',
                            requiredField: false,
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _passwordController,
                            label: 'Password',
                            obscureText: true,
                            hint: 'Optional - leave blank for auto-generated',
                            requiredField: false,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickDob,
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: Text(
                              _datePicked == null
                                  ? 'Date of birth'
                                  : dateTimeFormat('yMMMd', _datePicked),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DawaTokens.brandPrimary,
                            foregroundColor: DawaTokens.textInverse,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                          ),
                          child: Text(
                            _saving ? 'Creating...' : 'Create Patient',
                          ),
                        ),
                      ),
                    ],
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
