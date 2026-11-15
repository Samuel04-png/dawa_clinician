import 'dart:async';
import 'dart:convert';
import 'package:clinician/backend/backend.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final requests = <http.Request>[];
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    for (final name in [
      'com.llfbandit.app_links/events',
      'com.llfbandit.app_links/messages'
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    await Supabase.initialize(
        url: 'http://127.0.0.1:54321',
        anonKey: 'local-test-key',
        authOptions: const FlutterAuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request);
          final offset =
              int.tryParse(request.url.queryParameters['offset'] ?? '') ?? 0;
          final limit =
              int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 2;
          final rows = [
            {'id': 'synthetic-one'},
            {'id': 'synthetic-two'}
          ].skip(offset).take(limit).toList();
          return http.Response(jsonEncode(rows), 200,
              headers: {'content-type': 'application/json'}, request: request);
        }));
  });
  tearDownAll(() async => Supabase.instance.dispose());

  test(
      'legacy live pagination reports its single-subscription stream limitation',
      () async {
    final controller =
        PagingController<DocumentSnapshot?, MotherRecord>(firstPageKey: null);
    await expectLater(
        queryMotherRecordPage(
            pageSize: 1, isStream: true, controller: controller),
        throwsStateError);
    // The first page was already appended before the legacy second subscription failed.
    expect(controller.itemList!.single.reference.id, 'synthetic-one');
    controller.dispose();
  });

  test(
      'User legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryUserRecordCount(limit: 1), 1);
    expect(await queryUserRecordCount(), 2);
    final once = await queryUserRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryUserRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller =
        PagingController<DocumentSnapshot?, UserRecord>(firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryUserRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryUserRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryUserRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });

  test(
      'Mother legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryMotherRecordCount(limit: 1), 1);
    expect(await queryMotherRecordCount(), 2);
    final once = await queryMotherRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryMotherRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller =
        PagingController<DocumentSnapshot?, MotherRecord>(firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryMotherRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryMotherRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryMotherRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });

  test(
      'Doctor legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryDoctorRecordCount(limit: 1), 1);
    expect(await queryDoctorRecordCount(), 2);
    final once = await queryDoctorRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryDoctorRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller =
        PagingController<DocumentSnapshot?, DoctorRecord>(firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryDoctorRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryDoctorRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryDoctorRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });

  test(
      'Clinic legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryClinicRecordCount(limit: 1), 1);
    expect(await queryClinicRecordCount(), 2);
    final once = await queryClinicRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryClinicRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller =
        PagingController<DocumentSnapshot?, ClinicRecord>(firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryClinicRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryClinicRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryClinicRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });

  test(
      'FirstEncounter legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryFirstEncounterRecordCount(limit: 1), 1);
    expect(await queryFirstEncounterRecordCount(), 2);
    final once = await queryFirstEncounterRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryFirstEncounterRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller =
        PagingController<DocumentSnapshot?, FirstEncounterRecord>(
            firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryFirstEncounterRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryFirstEncounterRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryFirstEncounterRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });

  test(
      'Encounter legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryEncounterRecordCount(limit: 1), 1);
    expect(await queryEncounterRecordCount(), 2);
    final once = await queryEncounterRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryEncounterRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller = PagingController<DocumentSnapshot?, EncounterRecord>(
        firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryEncounterRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryEncounterRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryEncounterRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });

  test(
      'Parity legacy queries preserve filtering, limits and pagination without duplicate rows',
      () async {
    requests.clear();
    expect(await queryParityRecordCount(limit: 1), 1);
    expect(await queryParityRecordCount(), 2);
    final once = await queryParityRecordOnce(singleRecord: true);
    expect(once.single.reference.id, 'synthetic-one');
    final streamed = await queryParityRecord(limit: 1).first;
    expect(streamed.single.reference.id, 'synthetic-one');
    final controller =
        PagingController<DocumentSnapshot?, ParityRecord>(firstPageKey: null);
    final subscriptions = <StreamSubscription?>[];
    final first = await queryParityRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        queryBuilder: (q) => q.where('id', isNotEqualTo: ''),
        streamSubscriptions: subscriptions);
    await Future<void>.delayed(Duration.zero);
    expect(first.data.single.reference.id, 'synthetic-one');
    expect(controller.itemList!.map((r) => r.reference.id), ['synthetic-one']);
    expect(requests.last.url.queryParameters['id'], 'neq.');
    final second = await queryParityRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: first.nextPageMarker);
    expect(second.data.single.reference.id, 'synthetic-two');
    expect(controller.itemList!.map((r) => r.reference.id),
        ['synthetic-one', 'synthetic-two']);
    final empty = await queryParityRecordPage(
        pageSize: 1,
        isStream: false,
        controller: controller,
        nextPageMarker: second.nextPageMarker);
    expect(empty.data, isEmpty);
    expect(empty.nextPageMarker, isNull);
    for (final subscription in subscriptions) {
      await subscription?.cancel();
    }
    controller.dispose();
  });
}
