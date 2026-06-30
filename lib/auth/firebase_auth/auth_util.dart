import 'dart:async';

import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/services/offline_auth_cache.dart';
import 'package:stream_transform/stream_transform.dart';
import 'firebase_auth_manager.dart';

export 'firebase_auth_manager.dart';

final _authManager = FirebaseAuthManager();
FirebaseAuthManager get authManager => _authManager;

String get currentUserEmail =>
    currentUserDocument?.email ?? currentUser?.email ?? '';

String get currentUserUid => currentUser?.uid ?? '';

String get currentUserDisplayName =>
    currentUserDocument?.displayName ?? currentUser?.displayName ?? '';

String get currentUserPhoto =>
    currentUserDocument?.photoUrl ?? currentUser?.photoUrl ?? '';

String get currentPhoneNumber =>
    currentUserDocument?.phoneNumber ?? currentUser?.phoneNumber ?? '';

String get currentJwtToken => _currentJwtToken ?? '';

bool get currentUserEmailVerified => currentUser?.emailVerified ?? false;

String? _currentJwtToken;
final jwtTokenStream = supabaseClient.auth.onAuthStateChange
    .map((state) => _currentJwtToken = state.session?.accessToken)
    .asBroadcastStream();

DocumentReference? get currentUserReference =>
    loggedIn ? UserRecord.collection.doc(currentUser!.uid) : null;

UserRecord? currentUserDocument;
final authenticatedUserStream = supabaseClient.auth.onAuthStateChange
    .map<String>((state) => state.session?.user.id ?? '')
    .switchMap(
      (uid) => uid.isEmpty
          ? Stream.value(null)
          : UserRecord.getDocument(UserRecord.collection.doc(uid))
              .handleError((_) {}),
    )
    .map((user) {
  currentUserDocument = user;
  if (user != null && currentUserUid.isNotEmpty) {
    OfflineAuthCache.saveSession(
      CachedAuthSession(
        uid: currentUserUid,
        email: user.email.isNotEmpty ? user.email : currentUserEmail,
        displayName: user.displayName.isNotEmpty ? user.displayName : null,
        photoUrl: user.photoUrl.isNotEmpty ? user.photoUrl : null,
        phoneNumber: user.phoneNumber.isNotEmpty ? user.phoneNumber : null,
        emailVerified: currentUserEmailVerified,
        cachedAt: DateTime.now().toUtc(),
      ),
    );
  }

  return currentUserDocument;
}).asBroadcastStream();

class AuthUserStreamWidget extends StatelessWidget {
  const AuthUserStreamWidget({Key? key, required this.builder})
      : super(key: key);

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: authenticatedUserStream,
        builder: (context, _) => builder(context),
      );
}
