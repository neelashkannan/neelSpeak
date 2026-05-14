import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/settings_provider.dart';

class CopilotConfigPage extends ConsumerStatefulWidget {
  const CopilotConfigPage({super.key});
  @override
  ConsumerState<CopilotConfigPage> createState() => _State();
}

class _State extends ConsumerState<CopilotConfigPage> {
  String? _userCode;
  String? _verificationUrl;
  bool _signedIn = false;
  bool _waiting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final token = await ref.read(settingsChannelProvider).getSecure(Keys.cloudCopilotOAuth);
    setState(() => _signedIn = (token != null && token.isNotEmpty));
  }

  Future<void> _start() async {
    setState(() { _waiting = true; _error = null; });
    try {
      final code = await ref.read(copilotChannelProvider).requestDeviceCode();
      setState(() {
        _userCode = code['userCode'] as String?;
        _verificationUrl = code['verificationUrl'] as String?;
      });
      if (_verificationUrl != null) {
        await launchUrl(Uri.parse(_verificationUrl!), mode: LaunchMode.externalApplication);
      }
      await ref.read(copilotChannelProvider).pollForOAuthToken(
        deviceCode: code['deviceCode'] as String,
        intervalSeconds: code['intervalSeconds'] as int? ?? 5,
        expiresAtMillis: code['expiresAtMillis'] as int? ?? (DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000),
      );
      setState(() { _signedIn = true; _userCode = null; _verificationUrl = null; });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _waiting = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(copilotChannelProvider).signOut();
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GitHub Copilot')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_signedIn) ...[
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text('Signed in to GitHub Copilot'),
                subtitle: Text('Session token refreshes automatically every ~30 minutes.'),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _signOut, child: const Text('Sign out')),
          ] else ...[
            const Text(
              'Sign in with the GitHub OAuth device flow. NeelSpeak opens GitHub in your browser; '
              'enter the user code shown below.',
            ),
            const SizedBox(height: 16),
            if (_userCode != null) Card(
              child: ListTile(
                title: const Text('User code'),
                subtitle: SelectableText(_userCode!,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                trailing: TextButton(
                  onPressed: () => launchUrl(Uri.parse(_verificationUrl ?? 'https://github.com/login/device'),
                      mode: LaunchMode.externalApplication),
                  child: const Text('Open page'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _waiting ? null : _start,
              child: Text(_waiting ? 'Waiting for browser…' : 'Sign in with GitHub'),
            ),
          ],
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
