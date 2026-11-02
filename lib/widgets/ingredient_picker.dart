import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../state/providers.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Bottom sheet to search the ingredient catalog; resolves to the chosen ingredient or null.
Future<Ingredient?> pickIngredient(BuildContext context, {String title = 'Add an ingredient'}) =>
    showModalBottomSheet<Ingredient>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _IngredientPicker(title: title),
    );

class _IngredientPicker extends ConsumerStatefulWidget {
  const _IngredientPicker({required this.title});

  final String title;

  @override
  ConsumerState<_IngredientPicker> createState() => _IngredientPickerState();
}

class _IngredientPickerState extends ConsumerState<_IngredientPicker> {
  Timer? _debounce;
  List<Ingredient> _results = const [];
  bool _loading = true;
  Object? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_request;
    setState(() => _loading = true);
    try {
      final results = await ref.read(apiProvider).searchIngredients(q);
      if (mounted && id == _request) {
        setState(() {
          _results = results;
          _error = null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && id == _request) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.screen, 0, Space.screen, Space.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: Space.md),
                TextField(
                  autofocus: true,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: 'Search, e.g. spinach or red onion', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ]),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
            Expanded(
              child: _error != null
                  ? ErrorView(error: _error!, onRetry: () => _search(''))
                  : _results.isEmpty && !_loading
                      ? const EmptyState(icon: Icons.search_off_rounded, title: 'No ingredients by that name', message: 'Try a simpler word, like "pepper".')
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, i) {
                            final ing = _results[i];
                            return ListTile(
                              title: Text(ing.name),
                              subtitle: Text(ing.isPantryStaple ? 'Pantry staple' : titleCase(ing.category)),
                              trailing: const Icon(Icons.add_rounded),
                              onTap: () => Navigator.of(context).pop(ing),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
