import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:nts/components/settings/ai_actions_settings.dart';
import 'package:nts/components/settings/settings_subtitle.dart';
import 'package:nts/components/theming/adaptive_alert_dialog.dart';
import 'package:nts/components/theming/higan/higan_tokens.dart';
import 'package:nts/components/theming/higan/higan_widgets.dart';
import 'package:nts/data/ai/ai_provider.dart';
import 'package:nts/data/ai/ai_router.dart';
import 'package:nts/data/ai/providers/chatgpt_provider.dart';
import 'package:nts/data/ai/providers/claude_code_provider.dart';
import 'package:nts/data/prefs.dart';
import 'package:nts/i18n/strings.g.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings → AI accounts: ChatGPT, Claude and Google, each with its
/// status and a sign-in button. Google first needs the user's own Cloud
/// project ([GoogleSetupCard]).
class AiAccountsSection extends StatefulWidget {
  const new({super.key});

  /// The AI settings (this and AI actions) in a sheet over the current
  /// page, e.g. from the AI menu: closing it goes back to the note, with
  /// its lasso still there.
  static Future<void> open(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: context.higan.surface1,
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (context) => Padding(
      padding: .only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: .fromLTRB(
            24,
            0,
            24,
            HiganSpace.l + MediaQuery.paddingOf(context).bottom,
          ),
          child: const Column(
            crossAxisAlignment: .stretch,
            children: [AiAccountsSection(), AiActionsSection()],
          ),
        ),
      ),
    ),
  );

  @override
  State<AiAccountsSection> createState() => _AiAccountsSectionState();
}

class _AiAccountsSectionState extends State<AiAccountsSection> {
  late final _changes = Listenable.merge([
    AiRouter.changes,
    stows.aiGoogleClientId,
    stows.aiGoogleProjectId,
  ]);

  /// Showing [GoogleSetupCard] although Google is set up.
  var _changingGoogle = false;

  @override
  void initState() {
    super.initState();
    for (final provider in AiRouter.providers) {
      unawaited(provider.refreshStatus());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return ListenableBuilder(
      listenable: _changes,
      builder: (context, _) {
        final googleSetUp =
            stows.aiGoogleClientId.value.isNotEmpty &&
            stows.aiGoogleProjectId.value.isNotEmpty;
        return Column(
          crossAxisAlignment: .stretch,
          children: [
            SettingsSubtitle(subtitle: t.ai.accounts.title),
            Padding(
              padding: const .only(top: HiganSpace.m, bottom: HiganSpace.xs),
              child: Text(
                t.ai.accounts.help,
                style: HiganText.body(
                  context,
                  size: 13,
                  color: c.textSecondary,
                ),
              ),
            ),
            for (final provider in AiRouter.providers)
              if (provider.id == .google && (!googleSetUp || _changingGoogle))
                _AccountRow(
                  provider: provider,
                  setUp: googleSetUp,
                  below: GoogleSetupCard(
                    signedIn: provider.status.value.isSignedIn,
                    onSaved: () {
                      setState(() => _changingGoogle = false);
                      unawaited(provider.refreshStatus());
                    },
                    onCancel: googleSetUp
                        ? () => setState(() => _changingGoogle = false)
                        : null,
                  ),
                )
              else
                _AccountRow(
                  provider: provider,
                  onChangeSetup: provider.id == .google
                      ? () => setState(() => _changingGoogle = true)
                      : null,
                ),
          ],
        );
      },
    );
  }
}

/// One account: its name, a dot and status, a hint or what went wrong,
/// and what can be done (sign in, sign out, ...). [below] goes under it,
/// e.g. Google's setup.
class _AccountRow extends StatelessWidget {
  const new({
    required this.provider,
    this.setUp = true,
    this.below,
    this.onChangeSetup,
  });

  final AiProvider provider;

  /// False for Google before its Cloud project is set up: no buttons yet.
  final bool setUp;
  final Widget? below;
  final VoidCallback? onChangeSetup;

  static const _narrow = 520.0;

  String get _hint => switch (provider.id) {
    .chatgpt => t.ai.accounts.chatgptHint,
    .claude => t.ai.accounts.claudeHint,
    .google => t.ai.accounts.googleHint,
  };

  Future<void> _signIn(
    BuildContext context,
    Future<void> Function() signIn,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await signIn();
    } on AiError catch (e) {
      if (e.code == AiError.cancelled || e.message.isEmpty) return;
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _signOut(BuildContext context) async {
    // Claude Code's sign-out is also Terminal's
    if (provider.id == .claude) {
      final sure = await showDialog<bool>(
        context: context,
        builder: (context) => AdaptiveAlertDialog(
          title: Text(t.ai.accounts.claudeSignOutTitle),
          content: Text(t.ai.accounts.claudeSignOutBody),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t.common.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(context, true),
              child: Text(t.ai.accounts.signOut),
            ),
          ],
        ),
      );
      if (sure != true) return;
    }
    await provider.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final status = provider.status.value;
    final iPad = Theme.of(context).platform == .iOS;

    final (String label, Color dot) = switch (status.state) {
      _ when !setUp => (t.ai.google.notSetUp, c.textTertiary),
      .signedIn => (
        status.label == null
            ? t.ai.accounts.signedIn
            : t.ai.accounts.signedInAs(who: status.label!),
        c.stamenMark,
      ),
      .signingIn => (t.ai.accounts.signingIn, c.stamenMark),
      .unavailable when iPad && provider.id == .claude => (
        t.ai.accounts.macOnly,
        c.textTertiary,
      ),
      .unavailable => (t.ai.accounts.unavailable, c.textTertiary),
      .error => (t.ai.accounts.problem, c.higan),
      .signedOut => (t.ai.accounts.notSignedIn, c.textTertiary),
    };
    // What went wrong (or why it can't be used), else a hint
    final deviceCode = provider.id == .chatgpt && status.state == .signingIn
        ? _deviceCode(status.detail)
        : null;
    final problem = setUp && status.state != .signedIn && deviceCode == null
        ? status.detail
        : null;
    final warn =
        status.state == .error ||
        (status.state == .signedOut && problem != null);

    Widget spinner() => const SizedBox.square(
      dimension: 16,
      child: CircularProgressIndicator(strokeWidth: 1.5),
    );

    final buttons = <Widget>[
      if (setUp)
        ...switch (status.state) {
          .signedIn => [
            if (onChangeSetup != null)
              TextButton(
                onPressed: onChangeSetup,
                child: Text(t.ai.google.change),
              ),
            OutlinedButton(
              onPressed: () => _signOut(context),
              child: Text(t.ai.accounts.signOut),
            ),
          ],
          .signingIn => [
            spinner(),
            TextButton(
              onPressed: switch (provider) {
                // Stops `claude auth login`; never signs Claude Code out
                final ClaudeCodeProvider claude => claude.cancelSignIn,
                _ => provider.signOut,
              },
              child: Text(t.common.cancel),
            ),
          ],
          .unavailable when iPad && provider.id == .claude => const [],
          .unavailable || .error => [
            OutlinedButton(
              onPressed: provider.refreshStatus,
              child: Text(t.ai.accounts.checkAgain),
            ),
          ],
          .signedOut => [
            if (onChangeSetup != null)
              TextButton(
                onPressed: onChangeSetup,
                child: Text(t.ai.google.change),
              ),
            if (provider case final ChatGptProvider chatgpt)
              TextButton(
                onPressed: () => _signIn(context, chatgpt.signInWithDeviceCode),
                child: Text(t.ai.accounts.useCode),
              ),
            FilledButton(
              onPressed: () => _signIn(context, () => provider.signIn(context)),
              child: Text(t.ai.accounts.signIn),
            ),
          ],
        },
    ];

    final text = Column(
      crossAxisAlignment: .start,
      spacing: 3,
      children: [
        Text(provider.displayName, style: HiganText.body(context)),
        Row(
          spacing: HiganSpace.s,
          children: [
            SizedBox.square(
              dimension: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(color: dot, shape: .circle),
              ),
            ),
            Flexible(child: HiganLabel(label, size: 10)),
          ],
        ),
        Text(
          problem ?? _hint,
          style: HiganText.body(
            context,
            size: 13,
            color: warn ? c.higanText : c.textSecondary,
          ),
        ),
      ],
    );

    return Container(
      padding: const .symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hairline)),
      ),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: HiganSpace.m,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final actions = Wrap(
                spacing: HiganSpace.s,
                runSpacing: HiganSpace.s,
                crossAxisAlignment: .center,
                children: buttons,
              );
              if (buttons.isEmpty) return text;
              return constraints.maxWidth < _narrow
                  ? Column(
                      crossAxisAlignment: .start,
                      spacing: HiganSpace.m,
                      children: [text, actions],
                    )
                  : Row(
                      spacing: HiganSpace.l,
                      children: [
                        Expanded(child: text),
                        actions,
                      ],
                    );
            },
          ),
          if (deviceCode != null) _DeviceCode(code: deviceCode),
          ?below,
        ],
      ),
    );
  }

  /// The code in ChatGPT's "Enter the code … at …" while signing in with
  /// a code, if it says one.
  static String? _deviceCode(String? detail) =>
      RegExp(r'code ([A-Z0-9]{3,}(?:-[A-Z0-9]+)*)')
          .firstMatch(detail ?? '')?[1];
}

/// ChatGPT's sign-in code, big, with the page to type it on.
class _DeviceCode extends StatelessWidget {
  const new({required this.code});

  final String code;

  static final page = Uri.https('auth.openai.com', '/codex/device');

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    return Container(
      padding: const .all(HiganSpace.l),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: const .all(.circular(HiganRadius.card)),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: .start,
        spacing: HiganSpace.m,
        children: [
          HiganLabel(t.ai.accounts.deviceCode.title),
          SelectableText(
            code,
            style: HiganText.label(
              context,
              size: 26,
              color: c.text,
              tracking: 0.12,
            ),
          ),
          Text(
            t.ai.accounts.deviceCode.body,
            style: HiganText.body(context, size: 13, color: c.textSecondary),
          ),
          Wrap(
            spacing: HiganSpace.s,
            runSpacing: HiganSpace.s,
            children: [
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                icon: const Icon(Symbols.content_copy, size: 16, weight: 300),
                label: Text(t.ai.accounts.deviceCode.copy),
              ),
              OutlinedButton.icon(
                onPressed: () => launchUrl(page),
                icon: const Icon(Symbols.open_in_new, size: 16, weight: 300),
                label: Text(t.ai.accounts.deviceCode.open),
              ),
              Padding(
                padding: const .only(top: 9),
                child: Text(
                  t.ai.accounts.deviceCode.waiting,
                  style: HiganText.body(
                    context,
                    size: 13,
                    color: c.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The steps to make a Google Cloud project for nts, and fields for its
/// OAuth client ID and project ID (public identifiers, not secrets).
class GoogleSetupCard extends StatefulWidget {
  const new({
    super.key,
    required this.onSaved,
    this.onCancel,
    this.signedIn = false,
  });

  final VoidCallback onSaved;
  final VoidCallback? onCancel;

  /// Google is signed in: a different client ID signs it out.
  final bool signedIn;

  static final console = Uri.https('console.cloud.google.com', '/');

  /// E.g. 123-abc.apps.googleusercontent.com.
  static bool isClientId(String id) =>
      RegExp(r'^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$').hasMatch(id);

  /// Google's rules: 6 to 30 lowercase letters, digits and hyphens.
  static bool isProjectId(String id) =>
      RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(id);

  @override
  State<GoogleSetupCard> createState() => _GoogleSetupCardState();
}

class _GoogleSetupCardState extends State<GoogleSetupCard> {
  late final _clientId = TextEditingController(
    text: stows.aiGoogleClientId.value,
  );
  late final _projectId = TextEditingController(
    text: stows.aiGoogleProjectId.value,
  );
  var _tried = false;

  bool get _valid =>
      GoogleSetupCard.isClientId(_clientId.text.trim()) &&
      GoogleSetupCard.isProjectId(_projectId.text.trim());

  void _save() {
    setState(() => _tried = true);
    if (!_valid) return;
    stows.aiGoogleClientId.value = _clientId.text.trim();
    stows.aiGoogleProjectId.value = _projectId.text.trim();
    widget.onSaved();
  }

  @override
  void dispose() {
    _clientId.dispose();
    _projectId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.higan;
    final steps = [
      t.ai.google.step1,
      t.ai.google.step2,
      t.ai.google.step3,
      t.ai.google.step4,
      t.ai.google.step5,
    ];
    final clientIdError =
        _tried && !GoogleSetupCard.isClientId(_clientId.text.trim())
        ? t.ai.google.invalidClientId
        : null;
    final projectIdError =
        _tried && !GoogleSetupCard.isProjectId(_projectId.text.trim())
        ? t.ai.google.invalidProjectId
        : null;
    final signsOut =
        widget.signedIn &&
        _clientId.text.trim() != stows.aiGoogleClientId.value;
    return Container(
      padding: const .all(HiganSpace.l + 2),
      decoration: BoxDecoration(
        color: c.surface1,
        borderRadius: const .all(.circular(HiganRadius.card)),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Text(t.ai.google.title, style: HiganText.title(context, size: 22)),
          const SizedBox(height: HiganSpace.s),
          Text(
            t.ai.google.body,
            style: HiganText.body(context, size: 13, color: c.textSecondary),
          ),
          const SizedBox(height: HiganSpace.l),
          for (final (i, step) in steps.indexed)
            Padding(
              padding: const .only(bottom: HiganSpace.m),
              child: Row(
                crossAxisAlignment: .start,
                spacing: HiganSpace.m,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '${i + 1}',
                      style: HiganText.label(
                        context,
                        size: 12,
                        color: c.higanText,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(step, style: HiganText.body(context, size: 14)),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () =>
                launchUrl(GoogleSetupCard.console, mode: .externalApplication),
            icon: const Icon(Symbols.open_in_new, size: 16, weight: 300),
            label: Text(t.ai.google.openConsole),
          ),
          const SizedBox(height: HiganSpace.l),
          TextField(
            controller: _clientId,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: .url,
            style: HiganText.body(context, size: 14),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t.ai.google.clientId,
              hintText: '123456789-abc.apps.googleusercontent.com',
              errorText: clientIdError,
              errorMaxLines: 2,
              helperText: signsOut ? t.ai.google.changeSignsOut : null,
              helperMaxLines: 2,
            ),
          ),
          const SizedBox(height: HiganSpace.m),
          TextField(
            controller: _projectId,
            autocorrect: false,
            enableSuggestions: false,
            style: HiganText.body(context, size: 14),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(
              labelText: t.ai.google.projectId,
              hintText: 'nts-notes',
              errorText: projectIdError,
            ),
          ),
          const SizedBox(height: HiganSpace.l),
          Row(
            mainAxisAlignment: .end,
            spacing: HiganSpace.s,
            children: [
              if (widget.onCancel case final onCancel?)
                TextButton(onPressed: onCancel, child: Text(t.common.cancel)),
              FilledButton(onPressed: _save, child: Text(t.ai.google.save)),
            ],
          ),
        ],
      ),
    );
  }
}
