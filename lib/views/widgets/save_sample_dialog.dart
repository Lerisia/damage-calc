import 'package:flutter/material.dart';
import '../../data/sample_storage.dart';
import '../../utils/app_strings.dart';

/// Result returned by [SaveSampleDialog]. Either [teamId] is set
/// (existing team), or [newTeamName] is set (will be created on
/// confirm), or both null (loose / 팀 밖).
class SaveSampleDialogResult {
  final String name;
  final String? teamId;
  final String? newTeamName;
  const SaveSampleDialogResult({
    required this.name,
    this.teamId,
    this.newTeamName,
  });
}

/// Save dialog with name field + team picker. The team list shows
/// each team's fill state ("정공팀 (4/6)") and disables full ones so
/// the user doesn't try to push a 7th member. A "+ 새 팀" button
/// next to the dropdown opens a name prompt; the team isn't actually
/// created until the user confirms the save.
///
/// Shared between the calculator's per-side save and the team
/// builder's per-slot save so the two flows feel identical.
class SaveSampleDialog extends StatefulWidget {
  final String defaultName;
  /// If the active panel/slot was loaded from a saved sample, its
  /// current team is used as the dropdown default so re-saving
  /// doesn't silently move the pokemon out of its team.
  final String? loadedName;

  const SaveSampleDialog({
    super.key,
    required this.defaultName,
    this.loadedName,
  });

  @override
  State<SaveSampleDialog> createState() => _SaveSampleDialogState();
}

class _SaveSampleDialogState extends State<SaveSampleDialog> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.defaultName);

  SampleStore _store = const SampleStore();
  bool _loading = true;
  String? _selectedTeamId; // null = loose
  String? _pendingNewTeamName; // set when "+ 새 팀" provided a name

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final store = await SampleStorage.loadStore();
    if (!mounted) return;
    String? defaultTeam;
    if (widget.loadedName != null) {
      // Pre-select the team the existing sample lives in so re-save
      // keeps it there (most common workflow: tweak then save again).
      final existing = store.samples
          .where((s) => s.name == widget.loadedName)
          .firstOrNull;
      if (existing != null) {
        defaultTeam = store.teamOf(existing.id)?.id;
      }
    }
    setState(() {
      _store = store;
      _selectedTeamId = defaultTeam;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _promptNewTeamName() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
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
    if (name == null || name.isEmpty) return;
    setState(() {
      _pendingNewTeamName = name;
      _selectedTeamId = null; // dropdown unselected; pending name takes over
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppStrings.t('sample.save')),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameCtrl,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: AppStrings.t('sample.name'),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: _teamPickerOrPending()),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: AppStrings.t('sample.team.add'),
                      icon: const Icon(Icons.create_new_folder_outlined,
                          size: 20),
                      onPressed: _promptNewTeamName,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                if (SampleStorage.isWebStorage)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      AppStrings.t('sample.browserWarning'),
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.cancel')),
        ),
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.pop(
                    context,
                    SaveSampleDialogResult(
                      name: _nameCtrl.text.trim(),
                      teamId: _pendingNewTeamName == null
                          ? _selectedTeamId
                          : null,
                      newTeamName: _pendingNewTeamName,
                    ),
                  ),
          child: Text(AppStrings.t('action.save')),
        ),
      ],
    );
  }

  Widget _teamPickerOrPending() {
    // Pending new-team takes precedence over the dropdown so the user
    // sees what they just typed; tap the chip to clear it and
    // re-pick.
    if (_pendingNewTeamName != null) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.t('sample.save.team'),
        ),
        child: Row(
          children: [
            const Icon(Icons.create_new_folder, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_pendingNewTeamName!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            InkWell(
              onTap: () => setState(() => _pendingNewTeamName = null),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ],
        ),
      );
    }
    // Tap-to-pick instead of DropdownButton — Material's dropdown
    // animation is hard-coded to 300 ms, which felt slow inside the
    // in-battle save flow. A SimpleDialog opens via the standard
    // showDialog ~150 ms fade and lets us also style full/disabled
    // teams with a more obvious "full" indicator.
    final selectedLabel = _selectedTeamId == null
        ? AppStrings.t('sample.save.team.none')
        : (_store.teams
                    .where((t) => t.id == _selectedTeamId)
                    .firstOrNull
                    ?.name ??
                AppStrings.t('sample.save.team.none'));
    return InkWell(
      onTap: () async {
        final picked = await showDialog<_TeamPick>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => SimpleDialog(
            title: Text(AppStrings.t('sample.save.team')),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, const _TeamPick(null)),
                child: Text(AppStrings.t('sample.save.team.none')),
              ),
              for (final t in _store.teams)
                SimpleDialogOption(
                  onPressed: t.memberIds.length >= kMaxTeamSize
                      ? null
                      : () => Navigator.pop(ctx, _TeamPick(t.id)),
                  child: Text(
                    '${t.name}  (${t.memberIds.length}/$kMaxTeamSize)',
                    style: TextStyle(
                      color: t.memberIds.length >= kMaxTeamSize
                          ? Colors.grey
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        );
        if (picked == null) return;
        setState(() => _selectedTeamId = picked.id);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.t('sample.save.team'),
          isDense: true,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(selectedLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
            ),
            const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Carrier for the team-picker SimpleDialog return value — using a
/// dedicated type lets us distinguish "no team selected" (id = null,
/// returned via tap) from "dismissed" (the dialog returns null).
class _TeamPick {
  final String? id;
  const _TeamPick(this.id);
}
