import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../state/settings_provider.dart';
import '../../ui/premium_widgets.dart';

class CopilotConfigPage extends ConsumerStatefulWidget {
  const CopilotConfigPage({super.key});
  @override
  ConsumerState<CopilotConfigPage> createState() => _State();
}

class _State extends ConsumerState<CopilotConfigPage> {
  String? _userCode;
  String? _verificationUrl;
  String? _verificationUrlComplete;
  bool _signedIn = false;
  bool _waiting = false;
  String? _error;
  String? _launchMessage;

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final token = await ref
        .read(settingsChannelProvider)
        .getSecure(Keys.cloudCopilotOAuth);
    setState(() => _signedIn = (token != null && token.isNotEmpty));
  }

  Future<void> _start() async {
    setState(() {
      _waiting = true;
      _error = null;
      _launchMessage = null;
    });
    try {
      final code = await ref.read(copilotChannelProvider).requestDeviceCode();
      setState(() {
        _userCode = code['userCode'] as String?;
        _verificationUrl = code['verificationUrl'] as String?;
        _verificationUrlComplete = code['verificationUrlComplete'] as String?;
      });
      if (_verificationUrl != null || _verificationUrlComplete != null) {
        await _openGitHub();
      }
      await ref.read(copilotChannelProvider).pollForOAuthToken(
            deviceCode: code['deviceCode'] as String,
            intervalSeconds: code['intervalSeconds'] as int? ?? 5,
            expiresAtMillis: code['expiresAtMillis'] as int? ??
                (DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000),
          );
      setState(() {
        _signedIn = true;
        _userCode = null;
        _verificationUrl = null;
      });
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      setState(() => _waiting = false);
    }
  }

  Future<void> _openGitHub() async {
    final url = _preferredVerificationUrl;
    final opened = await ref.read(systemChannelProvider).openUrlPreferringApp(
          url,
          preferredPackage: 'com.github.android',
        );
    if (!mounted) return;
    setState(() {
      _launchMessage = switch (opened) {
        'app' => 'Opened the GitHub app for approval.',
        'browser' =>
          'GitHub app was unavailable for this link, so NeelSpeak opened the browser instead.',
        _ => null,
      };
      if (opened == 'none') {
        _error =
            'Could not open GitHub. Install the GitHub app or a browser, then try again.';
      }
    });
  }

  Future<void> _signOut() async {
    await ref.read(copilotChannelProvider).signOut();
    setState(() {
      _signedIn = false;
      _launchMessage = null;
    });
  }

  Future<void> _openBrowser() async {
    final opened = await ref
        .read(systemChannelProvider)
        .openUrlPreferringApp(_preferredVerificationUrl);
    if (!mounted) return;
    setState(() {
      _launchMessage = opened == 'browser'
          ? 'Opened the GitHub verification page in your browser.'
          : _launchMessage;
      if (opened == 'none') {
        _error = 'No browser is available to open github.com/login/device.';
      }
    });
  }

  Future<void> _copyCode() async {
    final userCode = _userCode;
    if (userCode == null || userCode.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: userCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User code copied.')),
    );
  }

  String _friendlyError(Object error) {
    if (error is PlatformException) {
      final message = error.message ?? error.toString();
      if (message.contains('Unable to resolve host')) {
        return 'Could not reach github.com. Check the phone internet/DNS connection, then try again.';
      }
      if (message.contains('access_denied')) {
        return 'GitHub sign-in was cancelled. Start again when you are ready.';
      }
      if (message.contains('expired')) {
        return 'The GitHub device code expired. Start the sign-in again.';
      }
      return message;
    }
    return error.toString();
  }

  String get _preferredVerificationUrl =>
      _verificationUrlComplete ??
      _verificationUrl ??
      'https://github.com/login/device';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Copilot')),
      backgroundColor: Colors.transparent,
      body: AppBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SectionIntro(
                eyebrow: 'Secure sign-in',
                title: 'Connect GitHub Copilot on Android.',
                subtitle:
                    'NeelSpeak starts the OAuth device flow, tries the GitHub mobile app first, and falls back cleanly to the browser when Android cannot hand that link to GitHub.',
                trailing: InfoPill(
                  label: _signedIn ? 'Connected' : 'Setup required',
                  icon: _signedIn ? Icons.check_circle : Icons.lock_outline,
                  tint: _signedIn ? Colors.green : null,
                ),
              ),
              const SizedBox(height: 20),
              if (_signedIn) ...[
                const GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DetailRow(
                        label: 'GitHub Copilot',
                        value:
                            'Signed in successfully. Session tokens refresh automatically every ~30 minutes.',
                        icon: Icons.check_circle,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _signOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ] else ...[
                const GlassPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DetailRow(
                        label: '1. Request a device code',
                        value: 'NeelSpeak gets a short-lived sign-in code from GitHub.',
                        icon: Icons.looks_one_rounded,
                      ),
                      SizedBox(height: 16),
                      DetailRow(
                        label: '2. Approve in GitHub',
                        value:
                            'Open the GitHub app or browser and confirm the device flow with the code shown below.',
                        icon: Icons.looks_two_rounded,
                      ),
                      SizedBox(height: 16),
                      DetailRow(
                        label: '3. Wait for confirmation',
                        value:
                            'Keep this screen open while NeelSpeak polls GitHub and stores the Copilot OAuth token.',
                        icon: Icons.looks_3_rounded,
                      ),
                    ],
                  ),
                ),
                if (_userCode != null) ...[
                  const SizedBox(height: 16),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User code',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          _userCode!,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.2,
                              ),
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final buttons = [
                              OutlinedButton.icon(
                                onPressed: _copyCode,
                                icon: const Icon(Icons.copy_all_rounded),
                                label: const Text('Copy code'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openGitHub,
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Open GitHub app'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _openBrowser,
                                icon: const Icon(Icons.language_rounded),
                                label: const Text('Open browser'),
                              ),
                            ];

                            if (constraints.maxWidth < 640) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (var i = 0; i < buttons.length; i++) ...[
                                    buttons[i],
                                    if (i != buttons.length - 1)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              );
                            }

                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: buttons,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
                if (_waiting) ...[
                  const SizedBox(height: 16),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Waiting for GitHub approval',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _launchMessage ??
                              'Approve the device flow in GitHub, then come back here if Android switched apps.',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _waiting ? null : _start,
                  icon: const Icon(Icons.login_rounded),
                  label: Text(
                    _waiting ? 'Waiting for GitHub…' : 'Sign in with GitHub',
                  ),
                ),
              ],
              if (_launchMessage != null && !_waiting) ...[
                const SizedBox(height: 16),
                Text(_launchMessage!),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
