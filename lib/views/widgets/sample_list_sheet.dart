import 'package:flutter/material.dart';
import '../../data/sample_storage.dart';
import '../../utils/app_strings.dart';
import '../../utils/korean_search.dart';

/// Bottom sheet that surfaces the saved-pokemon storage as a folder
/// tree: parties (groups of up to 6) at the top, loose samples below.
/// The sheet owns its own [SampleStore] state and re-reads from
/// [SampleStorage] after every mutation (rename, move, delete, …) so
/// callers stay out of CRUD concerns and only consume a load.
///
/// Used from both the calculator (load into attacker/defender) and
/// the party-coverage screen (load into a slot), so the UI stays
/// identical across the two consumers.
class SampleListSheet extends StatefulWidget {
  final Map<String, String> itemNameMap;

  /// Invoked when the user taps a pokemon row to load it. The sheet
  /// does NOT auto-close; the caller is expected to pop it after
  /// applying state (matches the prior calc behaviour where
  /// state-application happens on the parent before dismiss).
  final void Function(StoredSample) onLoad;

  const SampleListSheet({
    super.key,
    required this.onLoad,
    this.itemNameMap = const {},
  });

  @override
  State<SampleListSheet> createState() => _SampleListSheetState();
}

class _SampleListSheetState extends State<SampleListSheet> {
  SampleStore _store = const SampleStore();
  bool _loading = true;
  String _query = '';
  // Collapsed party ids — defaults to expanded for newly seen parties
  // so first-time use shows everything. Reset each sheet open (not
  // persisted across navigations).
  final Set<String> _collapsed = <String>{};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final store = await SampleStorage.loadStore();
    if (!mounted) return;
    setState(() {
      _store = store;
      _loading = false;
    });
  }

  // ── Mutations ──────────────────────────────────────────────────

  Future<void> _addTeam() async {
    final name = await _promptName(title: AppStrings.t('sample.team.add'));
    if (name == null || name.isEmpty) return;
    await SampleStorage.createTeam(name);
    await _refresh();
  }

  Future<void> _renameTeam(TeamFolder t) async {
    final name = await _promptName(
        title: AppStrings.t('sample.team.namePrompt'), initial: t.name);
    if (name == null || name.isEmpty || name == t.name) return;
    await SampleStorage.renameTeam(t.id, name);
    await _refresh();
  }

  Future<void> _deleteTeam(TeamFolder t) async {
    // 3-way prompt: keep members (loose) / cascade delete / cancel.
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${AppStrings.t('sample.team.delete.title')}: ${t.name}'),
        content: t.memberIds.isEmpty
            ? null
            : Text(AppStrings.t('sample.team.delete.body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.cancel')),
          ),
          if (t.memberIds.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cascade'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(AppStrings.t('sample.team.delete.cascade')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: Text(t.memberIds.isEmpty
                ? AppStrings.t('action.confirm')
                : AppStrings.t('sample.team.delete.keep')),
          ),
        ],
      ),
    );
    if (result == null) return;
    await SampleStorage.deleteTeam(t.id, deleteMembers: result == 'cascade');
    await _refresh();
  }

  Future<void> _renamePokemon(StoredSample s) async {
    final name = await _promptName(
      title: AppStrings.t('sample.pokemon.rename'),
      initial: s.name,
      validator: (text) {
        if (text == s.name) return null;
        // Globally unique — cheap check against current store.
        if (_store.samples.any((x) => x.name == text)) {
          return AppStrings.t('sample.name.dup');
        }
        return null;
      },
    );
    if (name == null || name.isEmpty || name == s.name) return;
    await SampleStorage.updatePokemon(s.id, name: name);
    await _refresh();
  }

  Future<void> _deletePokemon(StoredSample s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('"${s.name}" 삭제'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppStrings.t('action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppStrings.t('sample.pokemon.delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await SampleStorage.deletePokemon(s.id);
    await _refresh();
  }

  Future<void> _movePokemon(StoredSample s) async {
    final currentTeamId = _store.teamOf(s.id)?.id;
    final pickedAction = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              dense: true,
              title: Text(
                AppStrings.t('sample.move.title'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: Text(AppStrings.t('sample.move.toLoose')),
              enabled: currentTeamId != null,
              onTap: () => Navigator.pop(ctx, '__loose__'),
            ),
            for (final t in _store.teams)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text('${t.name}  (${t.memberIds.length}/$kMaxTeamSize)'),
                enabled: t.id != currentTeamId &&
                    t.memberIds.length < kMaxTeamSize,
                trailing: t.memberIds.length >= kMaxTeamSize &&
                        t.id != currentTeamId
                    ? Text(AppStrings.t('sample.team.full'),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500))
                    : null,
                onTap: () => Navigator.pop(ctx, t.id),
              ),
          ],
        ),
      ),
    );
    if (pickedAction == null) return;
    final targetId = pickedAction == '__loose__' ? null : pickedAction;
    try {
      await SampleStorage.movePokemon(s.id, targetId);
    } on TeamFullException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.t('sample.team.fullSnack')),
      ));
      return;
    }
    await _refresh();
  }

  Future<String?> _promptName({
    required String title,
    String initial = '',
    String? Function(String)? validator,
  }) async {
    final controller = TextEditingController(text: initial);
    String? errorText;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(errorText: errorText),
            onSubmitted: (text) {
              final err = validator?.call(text.trim());
              if (err != null) {
                setLocal(() => errorText = err);
                return;
              }
              Navigator.pop(ctx, text.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.t('action.cancel')),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                final err = validator?.call(text);
                if (err != null) {
                  setLocal(() => errorText = err);
                  return;
                }
                Navigator.pop(ctx, text);
              },
              child: Text(AppStrings.t('action.confirm')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  bool _matches(StoredSample s) {
    if (_query.isEmpty) return true;
    final scores = [
      koreanMatchScore(_query, s.name),
      koreanMatchScore(_query, s.state.pokemonNameKo),
      koreanMatchScore(_query, s.state.pokemonName),
    ];
    return scores.any((sc) => sc > 0);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            if (SampleStorage.isWebStorage)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Text(
                  AppStrings.t('sample.browserWarning'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: AppStrings.t('sample.search'),
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _addTeam,
                    icon: const Icon(Icons.create_new_folder_outlined,
                        size: 18),
                    label: Text(AppStrings.t('sample.team.add')),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            Expanded(child: _body(scrollController)),
          ],
        );
      },
    );
  }

  Widget _body(ScrollController scrollController) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_store.teams.isEmpty && _store.samples.isEmpty) {
      return Center(
        child: Text(AppStrings.t('sample.empty'),
            style: const TextStyle(fontSize: 14)),
      );
    }
    if (_query.isNotEmpty) {
      final hits = _store.samples.where(_matches).toList();
      if (hits.isEmpty) {
        return Center(
          child: Text(AppStrings.t('search.noResults'),
              style: TextStyle(color: Colors.grey[400])),
        );
      }
      return ListView.separated(
        controller: scrollController,
        itemCount: hits.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _pokemonTile(hits[i]),
      );
    }
    final sections = <Widget>[];
    for (final t in _store.teams) {
      final collapsed = _collapsed.contains(t.id);
      sections.add(_teamHeader(t, collapsed: collapsed));
      if (collapsed) continue;
      if (t.memberIds.isEmpty) {
        sections.add(_emptyTeamPlaceholder());
      } else {
        for (final pid in t.memberIds) {
          final s = _store.sampleById(pid);
          if (s != null) sections.add(_pokemonTile(s, indent: true));
        }
      }
    }
    final loose = _store.looseSamples;
    if (loose.isNotEmpty) {
      sections.add(_looseHeader(loose.length));
      for (final s in loose) {
        sections.add(_pokemonTile(s));
      }
    }
    return ListView(
      controller: scrollController,
      children: sections,
    );
  }

  Widget _teamHeader(TeamFolder t, {required bool collapsed}) {
    final scheme = Theme.of(context).colorScheme;
    final full = t.memberIds.length >= kMaxTeamSize;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => setState(() {
          if (collapsed) {
            _collapsed.remove(t.id);
          } else {
            _collapsed.add(t.id);
          }
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: [
              AnimatedRotation(
                turns: collapsed ? 0 : 0.25,
                duration: const Duration(milliseconds: 100),
                child: const Icon(Icons.chevron_right, size: 20),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.folder_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${t.memberIds.length}/$kMaxTeamSize',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      full ? Colors.orange.shade700 : Colors.grey.shade600,
                  fontWeight: full ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '',
                popUpAnimationStyle: AnimationStyle(
                    duration: const Duration(milliseconds: 100)),
                icon: const Icon(Icons.more_vert, size: 18),
                padding: EdgeInsets.zero,
                onSelected: (v) {
                  if (v == 'rename') _renameTeam(t);
                  if (v == 'delete') _deleteTeam(t);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(AppStrings.t('sample.team.rename')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(AppStrings.t('sample.team.delete'),
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _looseHeader(int count) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          const Icon(Icons.inbox_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AppStrings.t('sample.loose.title'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _emptyTeamPlaceholder() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 8, 16, 8),
      child: Text(
        AppStrings.t('sample.team.empty'),
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _pokemonTile(StoredSample s, {bool indent = false}) {
    final state = s.state;
    final itemKo = state.selectedItem != null
        ? widget.itemNameMap[state.selectedItem] ?? state.selectedItem
        : null;
    final parts = [
      'Lv.${state.level}',
      state.nature.localizedName,
      if (itemKo != null) itemKo,
    ];
    return ListTile(
      contentPadding:
          EdgeInsets.fromLTRB(indent ? 32 : 16, 0, 4, 0),
      title: Text(s.name),
      subtitle: Text(
        '${state.localizedPokemonName} | ${parts.join(' ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => widget.onLoad(s),
      trailing: PopupMenuButton<String>(
        tooltip: '',
        popUpAnimationStyle:
            AnimationStyle(duration: const Duration(milliseconds: 100)),
        icon: const Icon(Icons.more_vert, size: 18),
        padding: EdgeInsets.zero,
        onSelected: (v) {
          if (v == 'rename') _renamePokemon(s);
          if (v == 'move') _movePokemon(s);
          if (v == 'delete') _deletePokemon(s);
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'rename',
            child: Text(AppStrings.t('sample.pokemon.rename')),
          ),
          PopupMenuItem(
            value: 'move',
            child: Text(AppStrings.t('sample.pokemon.move')),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(AppStrings.t('sample.pokemon.delete'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
