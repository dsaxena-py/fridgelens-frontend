import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';

/// Server address (the laptop's changes with the network), appearance and account.
/// Checks a server address; tests override it.
final serverCheckProvider = Provider<Future<String> Function(String baseUrl)>((ref) => checkServer);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final _address = TextEditingController(text: ref.read(settingsProvider).apiBaseUrl);
  bool _checking = false;
  ({bool ok, String text})? _result;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    final url = _address.text.trim();
    if (!RegExp(r'^https?://\S+$').hasMatch(url)) {
      setState(() => _result = (ok: false, text: 'Start the address with http:// or https://, e.g. http://192.168.1.20:8000'));
      return;
    }
    setState(() {
      _checking = true;
      _result = null;
    });
    await ref.read(settingsProvider.notifier).setApiBaseUrl(url);
    ref.invalidate(inventoryProvider);
    try {
      final detector = await ref.read(serverCheckProvider)(url);
      final note = detector == 'fake' ? ' It is using sample detections until a model is installed.' : '';
      if (mounted) setState(() => _result = (ok: true, text: 'Connected to MealLens.$note'));
    } catch (e) {
      if (mounted) setState(() => _result = (ok: false, text: errorText(e)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final auth = ref.watch(authProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        children: [
          const SectionHeader('Server'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                "The address of the MealLens server on your laptop. The phone and laptop need to be on the same Wi-Fi network.",
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Space.md),
              TextField(
                controller: _address,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Server address', hintText: 'http://192.168.1.20:8000'),
                onSubmitted: (_) => _saveAndTest(),
              ),
              const SizedBox(height: Space.md),
              OutlinedButton(
                onPressed: _checking ? null : _saveAndTest,
                child: _checking
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save and test connection'),
              ),
              if (_result != null) ...[
                const SizedBox(height: Space.md),
                _ResultBanner(ok: _result!.ok, text: _result!.text),
              ],
            ]),
          ),
          const SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) => ref.read(settingsProvider.notifier).setThemeMode(s.first),
            ),
          ),
          const SectionHeader('Account'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: Space.screen),
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(auth.email ?? 'Signed in'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.screen),
            child: OutlinedButton(onPressed: auth.signOut, child: const Text('Sign out')),
          ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) => ok
      ? Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(
              color: StatusColors.success.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Radii.control),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline_rounded, color: StatusColors.success, size: 20),
              const SizedBox(width: Space.md),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
            ]),
          ),
        )
      : InlineBanner(text: text, isError: true);
}
