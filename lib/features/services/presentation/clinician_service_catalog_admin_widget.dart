import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '/backend/supabase/supabase_config.dart';
import '/components/dawa_design_system.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

class ClinicianServiceCatalogAdminWidget extends StatefulWidget {
  const ClinicianServiceCatalogAdminWidget({super.key});

  static String routeName = 'ClinicianServiceCatalogAdmin';
  static String routePath = '/clinician-services';

  @override
  State<ClinicianServiceCatalogAdminWidget> createState() =>
      _ClinicianServiceCatalogAdminWidgetState();
}

class _ClinicianServiceCatalogAdminWidgetState
    extends State<ClinicianServiceCatalogAdminWidget> {
  late final Future<bool> _adminFuture;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController(text: 'consultation');
  final _externalServiceIdController = TextEditingController();
  final _priceController = TextEditingController(text: '0');
  bool _isPaid = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _adminFuture = _isAdmin();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _externalServiceIdController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _adminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.goNamed(ProfileWidget.routeName);
          });
          return const Scaffold(body: SizedBox.shrink());
        }

        return Scaffold(
      backgroundColor: DawaTokens.surfaceSecondary,
      appBar: AppBar(
        backgroundColor: DawaTokens.surface,
        foregroundColor: DawaTokens.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.goNamed(ProfileWidget.routeName),
        ),
        title: Text(
          'Services & Pricing',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add service'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: supabaseClient
            .from('clinician_services')
            .stream(primaryKey: ['id'])
            .map((rows) => rows
                .map((row) => Map<String, dynamic>.from(row as Map))
                .toList(growable: false)),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snapshot.data ?? const <Map<String, dynamic>>[];
          if (services.isEmpty) {
            return const Center(
              child: Text('No services configured yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: services.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final service = services[index];
              final name = (service['name'] ?? 'Service').toString();
              final category = (service['category'] ?? 'general').toString();
              final price = (service['price'] ?? 0).toString();
              final active = service['is_active'] == true;
              final paid = service['is_paid'] == true;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DawaTokens.surface,
                  borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
                  border: Border.all(color: DawaTokens.border),
                  boxShadow: DawaTokens.shadowSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: active
                                      ? DawaTokens.statusSuccessBg
                                      : DawaTokens.statusWarningBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  active ? 'Active' : 'Inactive',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? DawaTokens.statusSuccessText
                                        : DawaTokens.statusWarningText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            category,
                            style: DawaTextStyles.secondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            paid ? 'Paid service' : 'Free service',
                            style: GoogleFonts.dmSans(
                              color: paid ? DawaTokens.brandPrimary : DawaTokens.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'ZMW $price',
                            style: GoogleFonts.dmSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: DawaTokens.brandPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openEditDialog(service),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
        );
      },
    );
  }

  Future<bool> _isAdmin() async {
    final result = await runSupabaseRequest(
      () => supabaseClient.rpc('current_clinician_is_admin'),
    );
    return result == true;
  }

  Future<void> _openCreateDialog() async {
    _resetForm();
    await _showDialog();
  }

  Future<void> _openEditDialog(Map<String, dynamic> service) async {
    _nameController.text = (service['name'] ?? '').toString();
    _descriptionController.text = (service['description'] ?? '').toString();
    _categoryController.text = (service['category'] ?? 'consultation').toString();
    _externalServiceIdController.text =
        (service['external_service_id'] ?? '').toString();
    _priceController.text = ((service['price'] ?? 0) as num).toString();
    _isPaid = service['is_paid'] == true;
    _isActive = service['is_active'] != false;
    await _showDialog();
  }

  Future<void> _showDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            _externalServiceIdController.text.isEmpty ? 'Add service' : 'Edit service',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _externalServiceIdController,
                    decoration: const InputDecoration(labelText: 'External service ID'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price (ZMW)'),
                    validator: (value) {
                      final parsed = double.tryParse(value ?? '');
                      if (parsed == null || parsed < 0) {
                        return 'Enter a valid non-negative amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _isPaid,
                    title: const Text('Paid service'),
                    onChanged: (value) => setState(() => _isPaid = value),
                  ),
                  SwitchListTile(
                    value: _isActive,
                    title: const Text('Visible/active'),
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!_formKey.currentState!.validate()) return;
                final payload = {
                  'external_service_id': _externalServiceIdController.text.trim(),
                  'external_clinic_id': 'clinician-admin',
                  'name': _nameController.text.trim(),
                  'description': _descriptionController.text.trim().isEmpty
                      ? null
                      : _descriptionController.text.trim(),
                  'category': _categoryController.text.trim().isEmpty
                      ? 'consultation'
                      : _categoryController.text.trim(),
                  'is_paid': _isPaid,
                  'price': _isPaid ? double.parse(_priceController.text) : 0.0,
                  'currency': 'ZMW',
                  'is_active': _isActive,
                  'source_updated_at': DateTime.now().toUtc().toIso8601String(),
                };

                await runSupabaseRequest(
                  () => supabaseClient.from('clinician_services').upsert(
                    payload,
                    onConflict: 'external_service_id',
                  ),
                );

                if (!context.mounted) return;
                Navigator.pop(dialogContext);
                _resetForm();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _categoryController.text = 'consultation';
    _externalServiceIdController.clear();
    _priceController.text = '0';
    _isPaid = false;
    _isActive = true;
  }
}
