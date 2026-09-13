part of '../team_coverage_screen.dart';

/// "선출 보기" switch — single-line right-aligned switch row tied
/// to the lineup-mode flag in [_TeamCoverageStore]. Toggles the
/// dim-everything / tap-name-to-add behavior in the matrix.
class _LineupSwitch extends StatelessWidget {
  final bool value;
  final VoidCallback onToggle;
  const _LineupSwitch({required this.value, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppStrings.t('team.matrix.lineup'),
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 24,
              child: Switch.adaptive(
                value: value,
                onChanged: (_) => onToggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal bottom sheet that lists saved parties (with at least one
/// member) and lets the user pick one to load. Each row also has a
/// rename / delete menu so users don't have to bounce out to the
/// sample sheet just to clean up old parties. Returns the picked
/// party id via [Navigator.pop], or null on dismiss.
class _PartyPickerSheet extends StatefulWidget {
  const _PartyPickerSheet();

  @override
  State<_PartyPickerSheet> createState() => _PartyPickerSheetState();
}

class _PartyPickerSheetState extends State<_PartyPickerSheet> {
  SampleStore _store = const SampleStore();
  bool _loading = true;

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

  Future<void> _renameTeam(TeamFolder t) async {
    final controller = TextEditingController(text: t.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.t('sample.team.namePrompt')),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.t('action.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(AppStrings.t('action.confirm')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.isEmpty || newName == t.name) return;
    await SampleStorage.renameTeam(t.id, newName);
    await _refresh();
  }

  Future<void> _deleteTeam(TeamFolder t) async {
    // Same 3-way prompt as SampleListSheet — keep the member samples
    // (move to the loose pool) or cascade-delete them with the party.
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final candidates = _store.teams
        .where((t) => t.memberIds.isNotEmpty)
        .toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  AppStrings.t('team.load.title'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close, size: 20),
                tooltip: AppStrings.t('action.close'),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      AppStrings.t('team.load.noTeams'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                for (final t in candidates)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(t.name),
                subtitle:
                    Text('${t.memberIds.length} / $kMaxTeamSize'),
                onTap: () => Navigator.pop(context, t.id),
                trailing: PopupMenuButton<String>(
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
              ),
            ],
          ),
        ),
      ],
    );
  }
}
