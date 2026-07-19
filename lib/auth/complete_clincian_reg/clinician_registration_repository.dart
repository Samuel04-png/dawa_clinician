import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '/backend/supabase/supabase_config.dart';

class ClinicOption {
  const ClinicOption({
    required this.id,
    required this.name,
    this.address,
  });

  final String id;
  final String name;
  final String? address;
}

class ClinicianRegistrationProfile {
  const ClinicianRegistrationProfile({
    required this.id,
    this.name = '',
    this.phoneNumber = '',
    this.speciality = '',
    this.clinicId,
    this.clinicName = '',
    this.startTime,
    this.endTime,
  });

  factory ClinicianRegistrationProfile.fromRow(Map<String, dynamic> row) =>
      ClinicianRegistrationProfile(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        phoneNumber: row['phone_number']?.toString() ?? '',
        speciality: row['speciality']?.toString() ?? '',
        clinicId: _nullableText(row['clinic_id']),
        clinicName: row['clinic_name']?.toString() ?? '',
        startTime: _nullableText(row['start_time']),
        endTime: _nullableText(row['end_time']),
      );

  final String id;
  final String name;
  final String phoneNumber;
  final String speciality;
  final String? clinicId;
  final String clinicName;
  final String? startTime;
  final String? endTime;

  bool get isComplete =>
      id.isNotEmpty &&
      name.trim().isNotEmpty &&
      phoneNumber.trim().isNotEmpty &&
      speciality.trim().isNotEmpty &&
      clinicId != null &&
      clinicName.trim().isNotEmpty &&
      startTime != null &&
      endTime != null;
}

class ClinicianRegistrationInput {
  const ClinicianRegistrationInput({
    required this.name,
    required this.phoneNumber,
    required this.speciality,
    required this.clinic,
    required this.startTime,
    required this.endTime,
  });

  final String name;
  final String phoneNumber;
  final String speciality;
  final ClinicOption clinic;
  final String startTime;
  final String endTime;
}

abstract class ClinicianRegistrationRepository {
  Future<ClinicianRegistrationProfile?> loadProfile();

  Future<List<ClinicOption>> loadClinics();

  Future<ClinicianRegistrationProfile> completeRegistration(
    ClinicianRegistrationInput input,
  );
}

class SupabaseClinicianRegistrationRepository
    implements ClinicianRegistrationRepository {
  SupabaseClinicianRegistrationRepository({SupabaseClient? client})
      : _client = client ?? supabaseClient;

  static const _requestTimeout = Duration(seconds: 15);
  static const _profileColumns =
      'id,name,phone_number,speciality,clinic_id,clinic_name,start_time,end_time,"user_Id",auth_user_id';

  final SupabaseClient _client;

  @override
  Future<ClinicianRegistrationProfile?> loadProfile() async {
    final userId = _requireUserId();
    debugPrint('[Registration] Looking up the clinician profile.');

    try {
      final row = await _findProfileRow(userId).timeout(_requestTimeout);
      debugPrint(
        row == null
            ? '[Registration] No clinician profile was found.'
            : '[Registration] Clinician profile lookup completed.',
      );
      return row == null ? null : ClinicianRegistrationProfile.fromRow(row);
    } catch (error, stackTrace) {
      debugPrint('[Registration] Clinician profile lookup failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ClinicianRegistrationException.from(error);
    }
  }

  @override
  Future<List<ClinicOption>> loadClinics() async {
    _requireUserId();
    debugPrint('[Registration] Loading the clinic directory.');

    try {
      final response = await _client
          .from('clinic')
          .select('id,name,address')
          .order('name')
          .timeout(_requestTimeout);
      final clinics = (response as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) =>
              (row['id']?.toString().trim().isNotEmpty ?? false) &&
              (row['name']?.toString().trim().isNotEmpty ?? false))
          .map(
            (row) => ClinicOption(
              id: row['id'].toString(),
              name: row['name'].toString().trim(),
              address: _nullableText(row['address']),
            ),
          )
          .toList(growable: false);
      debugPrint('[Registration] Clinic directory loaded (${clinics.length}).');
      return clinics;
    } catch (error, stackTrace) {
      debugPrint('[Registration] Clinic loading failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ClinicianRegistrationException.from(error);
    }
  }

  @override
  Future<ClinicianRegistrationProfile> completeRegistration(
    ClinicianRegistrationInput input,
  ) async {
    final userId = _requireUserId();
    debugPrint('[Registration] Submitting clinician registration.');

    try {
      final current = await _findProfileRow(userId).timeout(_requestTimeout);
      final payload = <String, dynamic>{
        'name': input.name.trim(),
        'phone_number': input.phoneNumber.trim(),
        'speciality': input.speciality.trim(),
        'clinic_id': input.clinic.id,
        'clinic_name': input.clinic.name,
        'start_time': input.startTime,
        'end_time': input.endTime,
      };

      Map<String, dynamic> savedRow;
      if (current != null) {
        final profileId = current['id']?.toString();
        if (profileId == null || profileId.isEmpty) {
          throw const ClinicianRegistrationException(
            'The existing clinician profile is missing its identifier.',
          );
        }
        final response = await _client
            .from('doctor')
            .update(payload)
            .eq('id', profileId)
            .select(_profileColumns)
            .single()
            .timeout(_requestTimeout);
        savedRow = Map<String, dynamic>.from(response);
      } else {
        final response = await _client
            .from('doctor')
            .insert({
              'id': const Uuid().v4(),
              ...payload,
              'user_Id': 'user/$userId',
              'auth_user_id': userId,
            })
            .select(_profileColumns)
            .single()
            .timeout(_requestTimeout);
        savedRow = Map<String, dynamic>.from(response);
      }

      final profile = ClinicianRegistrationProfile.fromRow(savedRow);
      if (!profile.isComplete) {
        throw const ClinicianRegistrationException(
          'The clinician profile was saved without all required registration fields.',
        );
      }
      debugPrint(
          '[Registration] Clinician registration completed successfully.');
      return profile;
    } catch (error, stackTrace) {
      debugPrint('[Registration] Registration submission failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw ClinicianRegistrationException.from(error);
    }
  }

  String _requireUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      throw const ClinicianRegistrationException(
        'Your session is no longer available. Please go back and sign in again.',
      );
    }
    return userId;
  }

  Future<Map<String, dynamic>?> _findProfileRow(String userId) async {
    final byAuthId = await _client
        .from('doctor')
        .select(_profileColumns)
        .eq('auth_user_id', userId)
        .limit(1)
        .maybeSingle();
    if (byAuthId != null) {
      return Map<String, dynamic>.from(byAuthId);
    }

    for (final storedUserId in ['user/$userId', userId]) {
      final legacy = await _client
          .from('doctor')
          .select(_profileColumns)
          .eq('user_Id', storedUserId)
          .limit(1)
          .maybeSingle();
      if (legacy != null) {
        return Map<String, dynamic>.from(legacy);
      }
    }
    return null;
  }
}

class ClinicianRegistrationException implements Exception {
  const ClinicianRegistrationException(this.message);

  factory ClinicianRegistrationException.from(Object error) {
    if (error is ClinicianRegistrationException) {
      return error;
    }
    if (error is TimeoutException) {
      return const ClinicianRegistrationException(
        'The request took too long. Check your connection and try again.',
      );
    }
    if (error is AuthException) {
      return ClinicianRegistrationException(error.message);
    }
    if (error is PostgrestException) {
      final lower = error.message.toLowerCase();
      if (lower.contains('clinician identity fields are server managed')) {
        return const ClinicianRegistrationException(
          'Your clinic assignment could not be completed. Please retry after the registration database update is deployed.',
        );
      }
      if (lower.contains('row-level security') || error.code == '42501') {
        return const ClinicianRegistrationException(
          'Your account is not allowed to update this clinician profile. Please sign in again or contact an administrator.',
        );
      }
      if (lower.contains('duplicate') || error.code == '23505') {
        return const ClinicianRegistrationException(
          'A clinician profile is already linked to this account. Retry to update the existing profile.',
        );
      }
      return ClinicianRegistrationException(error.message);
    }
    return const ClinicianRegistrationException(
      'Registration could not be completed. Please check your connection and try again.',
    );
  }

  final String message;

  @override
  String toString() => message;
}

String? _nullableText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}
