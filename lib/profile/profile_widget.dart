import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/supabase/supabase_config.dart';
import '/components/dawa_design_system.dart';
import '/components/clinical_workspace_components.dart';
import 'package:flutter/services.dart';
import '/components/navigation_design_system.dart';
import '/components/clinical_navigation_shell.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'profile_model.dart';
export 'profile_model.dart';

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});
  static String routeName = 'Profile';
  static String routePath = '/profile';
  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  late ProfileModel _model;
  late final Future<bool> _adminFuture;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());
    _adminFuture = _isAdmin();
    FFAppState().selectedPage = 'Settings';
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final doctorRef = FFAppState().doctor;
    if (doctorRef == null) return _missingProfile(context);
    return StreamBuilder<DoctorRecord>(
      stream: DoctorRecord.getDocument(doctorRef),
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            (snapshot.hasData && snapshot.data!.snapshotData.isEmpty)) {
          return _profileNotice(
            icon: Icons.cloud_off_outlined,
            title: 'Unable to load your profile',
            message: 'Check your connection and try again.',
            actionLabel: 'Retry',
            onAction: () => setState(() {}),
          );
        }
        return ClinicalNavigationShell(
            child: snapshot.hasData
                ? _content(context, snapshot.data!)
                : const Center(
                    child: CircularProgressIndicator(
                        semanticsLabel: 'Loading clinician profile')));
      },
    );
  }

  Widget _content(BuildContext context, DoctorRecord doctor) => LayoutBuilder(
        builder: (context, constraints) {
          final padding = constraints.maxWidth < 600 ? 16.0 : 24.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padding, 12, padding, 32),
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                      maxWidth: DawaTokens.workspaceMaxWidth),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const ClinicalPageHeader(
                            subtitle:
                                'Manage your clinician account and access help for your workspace.'),
                        const SizedBox(height: 12),
                        LayoutBuilder(builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 700 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 21;
                          final account = _profileSummary(context, doctor);
                          final options = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FutureBuilder<bool>(
                                    future: _adminFuture,
                                    builder: (context, snapshot) => snapshot
                                                .data ==
                                            true
                                        ? Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 16),
                                            child: _panel(
                                                'Workspace administration', [
                                              _row(
                                                  icon: Icons
                                                      .price_change_outlined,
                                                  label: 'Services & Pricing',
                                                  description:
                                                      'Manage services available in your workspace.',
                                                  onTap: () => context.pushNamed(
                                                      ClinicianServiceCatalogAdminWidget
                                                          .routeName)),
                                            ]))
                                        : const SizedBox.shrink()),
                                _panel('Help & legal', [
                                  _row(
                                      icon: Icons.help_outline_rounded,
                                      label: 'Support',
                                      description:
                                          'Contact the Dawa support team.',
                                      onTap: () => _support(context)),
                                  _row(
                                      icon: Icons.description_outlined,
                                      label: 'Terms of Service',
                                      description:
                                          'Review the terms for authorized clinical use.',
                                      onTap: () => _terms(context)),
                                ]),
                                const SizedBox(height: 16),
                                DawaCard(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('Session',
                                          style: DawaTextStyles.cardTitle),
                                      const SizedBox(height: 6),
                                      Text(
                                          'End this clinician session on this device.',
                                          style: DawaTextStyles.secondary
                                              .copyWith(
                                                  color: DawaTokens
                                                      .textSecondary)),
                                      const SizedBox(height: 12),
                                      OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  NavigationTokens.brand,
                                              side: const BorderSide(
                                                  color:
                                                      DawaTokens.borderStrong),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10))),
                                          onPressed: _confirmSignOut,
                                          icon: const Icon(Icons.logout_rounded,
                                              size: 18),
                                          label: const Text('Sign out')),
                                    ])),
                              ]);
                          return wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      SizedBox(
                                          width: (constraints.maxWidth * .35)
                                              .clamp(280.0, 360.0)
                                              .toDouble(),
                                          child: account),
                                      const SizedBox(width: 20),
                                      Expanded(child: options),
                                    ])
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                      account,
                                      const SizedBox(height: 16),
                                      options
                                    ]);
                        }),
                        const SizedBox(height: 24),
                        Text('Dawa Clinician v1.0.0',
                            style: DawaTextStyles.secondary.copyWith(
                                color: DawaTokens.textMuted, fontSize: 12)),
                      ]),
                )),
          );
        },
      );

  Widget _profileSummary(BuildContext context, DoctorRecord doctor) {
    final name =
        doctor.name.trim().isEmpty ? currentUserDisplayName : doctor.name;
    final role =
        doctor.speciality.trim().isEmpty ? 'Clinician' : doctor.speciality;
    return DawaCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Clinician account', style: DawaTextStyles.cardTitle),
      const SizedBox(height: 20),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _avatar(name),
        const SizedBox(width: 12),
        Expanded(
            child: Text(name.isEmpty ? 'Clinician account' : name,
                style: DawaTextStyles.pageTitle.copyWith(fontSize: 20))),
      ]),
      const SizedBox(height: 20),
      _accountField('Specialty', role),
      if (doctor.clinicName.trim().isNotEmpty)
        _accountField('Clinic', doctor.clinicName),
      if (currentUserEmail.isNotEmpty) _accountField('Email', currentUserEmail),
      const SizedBox(height: 8),
      FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: NavigationTokens.brand,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 42),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () => context.pushNamed(EditProfileWidget.routeName),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit profile')),
    ]));
  }

  Widget _accountField(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textMuted)),
          const SizedBox(height: 4),
          SelectableText(value,
              style:
                  DawaTextStyles.body.copyWith(color: DawaTokens.textPrimary)),
        ]),
      );

  Widget _avatar(String name) {
    final initials = _initials(name);
    return Semantics(
      label: name.isEmpty ? 'Clinician avatar' : '$name avatar',
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
            color: NavigationTokens.selected, shape: BoxShape.circle),
        child: currentUserPhoto.isEmpty
            ? Text(initials,
                style: DawaTextStyles.cardTitle
                    .copyWith(color: NavigationTokens.brand))
            : ClipOval(
                child: Image.network(currentUserPhoto,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Text(initials,
                        style: DawaTextStyles.cardTitle
                            .copyWith(color: NavigationTokens.brand)))),
      ),
    );
  }

  Widget _panel(String title, List<Widget> children) => DawaCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(DawaTokens.radiusLg),
            child: Material(
              color: Colors.transparent,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        child: Text(title, style: DawaTextStyles.cardTitle)),
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: DawaTokens.border),
                      children[i],
                    ],
                  ]),
            )),
      );

  Widget _row(
      {required IconData icon,
      required String label,
      required String description,
      required VoidCallback onTap}) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        hoverColor: NavigationTokens.hover,
        focusColor: NavigationTokens.selected,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(children: [
              Icon(icon, size: 20, color: DawaTokens.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: DawaTextStyles.cardTitle
                            .copyWith(color: DawaTokens.textPrimary)),
                    const SizedBox(height: 2),
                    Text(description,
                        style: DawaTextStyles.secondary
                            .copyWith(color: DawaTokens.textSecondary))
                  ])),
              Icon(Icons.chevron_right_rounded, color: DawaTokens.textMuted),
            ]),
          ),
        ),
      ),
    );
  }

  Future<bool> _isAdmin() async =>
      (await runSupabaseRequest(
          () => supabaseClient.rpc('current_clinician_is_admin'))) ==
      true;

  Future<void> _support(BuildContext context) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DawaTokens.surface,
          surfaceTintColor: Colors.transparent,
          title: Text('Contact support', style: DawaTextStyles.pageTitle),
          content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Get help with Dawa Clinician.',
                          style: DawaTextStyles.secondary),
                      const SizedBox(height: 20),
                      _contact('Email', 'developer@thestackone.com',
                          'Copy support email'),
                      const SizedBox(height: 16),
                      _contact('Phone', '+260779406330',
                          'Copy support phone number'),
                    ]),
              )),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'))
          ],
        ),
      );

  Widget _contact(String label, String value, String tooltip) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: DawaTextStyles.secondary
                  .copyWith(color: DawaTokens.textMuted)),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: SelectableText(value, style: DawaTextStyles.body)),
            IconButton(
                tooltip: tooltip,
                icon: const Icon(Icons.copy_outlined, size: 18),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (!mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$label copied')));
                }),
          ]),
        ],
      );

  Future<void> _terms(BuildContext context) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: DawaTokens.surface,
          surfaceTintColor: Colors.transparent,
          title: Text('Terms of Service', style: DawaTextStyles.pageTitle),
          content: const SizedBox(
              width: 520,
              child: SingleChildScrollView(
                  child: Text(
                      'Dawa Clinician is intended for authorized clinical users. Use patient data only according to your facility policies, consent requirements, and applicable health privacy regulations.'))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'))
          ],
        ),
      );

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              backgroundColor: DawaTokens.surface,
              surfaceTintColor: Colors.transparent,
              title: Text('Sign out of Dawa Clinician?',
                  style: DawaTextStyles.pageTitle),
              content: const SingleChildScrollView(
                  child: Text(
                      'End your clinician session on this device. You will need to sign in to continue.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Sign out')),
              ],
            ));
    if (confirmed == true && mounted) await _signOut();
  }

  Future<void> _signOut() async {
    GoRouter.of(context).prepareAuthEvent();
    await authManager.signOut();
    GoRouter.of(context).clearRedirectLocation();
    if (mounted) context.goNamedAuth(LoginWidget.routeName, mounted);
  }

  Widget _missingProfile(BuildContext context) => _profileNotice(
        icon: Icons.person_outline_rounded,
        title: 'Clinician profile unavailable',
        message: 'Your clinician profile is not available for this session.',
        actionLabel: 'Return Home',
        onAction: () => context.goNamed(HomeWidget.routeName),
      );

  Widget _profileNotice(
          {required IconData icon,
          required String title,
          required String message,
          required String actionLabel,
          required VoidCallback onAction}) =>
      ClinicalNavigationShell(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                  width: double.infinity,
                  child: ClinicalEmptyState(
                      icon: icon,
                      title: title,
                      message: message,
                      actionLabel: actionLabel,
                      onAction: onAction)),
            ),
          ),
        ),
      );

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'CL';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }
}
