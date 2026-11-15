import 'package:clinician/application/cacx/cacx_scan_drafts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<String> save(String uid, {String? id}) => CacxScanDrafts.save(
      uid: uid,
      patientId: 'patient-1',
      patientName: 'Test Patient',
      image: 'data:image/png;base64,abc',
      id: id);

  test(
      'capture persists complete image and patient without an analysis service',
      () async {
    final id = await save('clinician-a');
    final rows = await CacxScanDrafts.forUser('clinician-a');
    expect(rows.single['id'], id);
    expect(rows.single['patient_id'], 'patient-1');
    expect(rows.single['image_data_uri'], 'data:image/png;base64,abc');
    expect(rows.single['status'], 'awaiting_analysis');
    expect(rows.single['synced'], false);
    expect(await CacxScanDrafts.forUser('clinician-b'), isEmpty);
  });

  test(
      'reconnect uploads only this clinician and does not repeat a successful upload',
      () async {
    await save('clinician-a');
    await save('clinician-b');
    final uploads = <Map<String, dynamic>>[];
    Future<void> upload(Map<String, dynamic> row) async => uploads.add(row);
    await CacxScanDrafts.sync(userId: 'clinician-a', upload: upload);
    await CacxScanDrafts.sync(userId: 'clinician-a', upload: upload);
    expect(uploads, hasLength(1));
    expect(uploads.single['user_id'], 'clinician-a');
    expect(uploads.single.containsKey('synced'), false);
    expect(
        (await CacxScanDrafts.forUser('clinician-b')).single['synced'], false);
  });

  test('failed upload retains image and retries with the same database id',
      () async {
    final id = await save('clinician-a');
    await CacxScanDrafts.sync(
        userId: 'clinician-a',
        upload: (_) async => throw StateError('offline'));
    expect(
        (await CacxScanDrafts.forUser('clinician-a')).single['synced'], false);
    await CacxScanDrafts.sync(
        userId: 'clinician-a', upload: (row) async => expect(row['id'], id));
    expect(
        (await CacxScanDrafts.forUser('clinician-a')).single['synced'], true);
  });

  test('saving the current draft updates instead of duplicating it', () async {
    final id = await save('clinician-a');
    await save('clinician-a', id: id);
    expect(await CacxScanDrafts.forUser('clinician-a'), hasLength(1));
  });
}
