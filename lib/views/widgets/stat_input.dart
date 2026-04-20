import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/abilitydex.dart';
import '../../data/itemdex.dart';
import '../../utils/korean_search.dart';
import '../../models/ability.dart';
import '../../models/item.dart';
import '../../models/nature_profile.dart';
import '../../models/rank.dart';
import '../../models/stats.dart';
import '../../models/status.dart';
import '../../utils/app_strings.dart';
import '../../utils/localization.dart';
import '../../models/room.dart';
import '../../models/terrain.dart';
import '../../models/weather.dart';
import '../../utils/ability_effects.dart';
import '../../utils/item_effects.dart';
import '../../utils/speed_calculator.dart';
import '../../utils/room_effects.dart';
import '../../utils/champions_mode.dart';
import '../../utils/stat_calculator.dart';
import 'typeahead_helpers.dart';

class _ClampingFormatter extends TextInputFormatter {
  final int min;
  final int max;
  final bool allowNegative;

  _ClampingFormatter({required this.min, required this.max, this.allowNegative = false});

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    if (allowNegative && newValue.text == '-') return newValue;

    final parsed = int.tryParse(newValue.text);
    if (parsed == null) return oldValue;

    if (parsed > max) {
      return TextEditingValue(
        text: '$max',
        selection: TextSelection.collapsed(offset: '$max'.length),
      );
    }
    if (parsed < min) {
      return TextEditingValue(
        text: '$min',
        selection: TextSelection.collapsed(offset: '$min'.length),
      );
    }
    return newValue;
  }
}

/// Non-nullable enum used purely as the [PopupMenuButton] value type
/// for nature pickers. [PopupMenuButton.onSelected] swallows null
/// selections (routing them to [onCanceled]), so we can't use
/// `PopupMenuButton<NatureStat?>` directly — we'd never learn when
/// the user picked "None".
enum _NaturePick { none, atk, def, spa, spd, spe }

_NaturePick _pickFromStat(NatureStat s) {
  switch (s) {
    case NatureStat.atk: return _NaturePick.atk;
    case NatureStat.def: return _NaturePick.def;
    case NatureStat.spa: return _NaturePick.spa;
    case NatureStat.spd: return _NaturePick.spd;
    case NatureStat.spe: return _NaturePick.spe;
  }
}

NatureStat? _statFromPick(_NaturePick p) {
  switch (p) {
    case _NaturePick.none: return null;
    case _NaturePick.atk: return NatureStat.atk;
    case _NaturePick.def: return NatureStat.def;
    case _NaturePick.spa: return NatureStat.spa;
    case _NaturePick.spd: return NatureStat.spd;
    case _NaturePick.spe: return NatureStat.spe;
  }
}

class StatInput extends StatefulWidget {
  final int level;
  final NatureProfile nature;
  final Stats iv;
  final Stats ev;
  final Stats baseStats;
  final List<String> pokemonAbilities;
  final String? selectedAbility;
  final String? selectedItem;
  final Rank rank;
  final int hpPercent;
  final StatusCondition status;
  final ValueChanged<int> onLevelChanged;
  final ValueChanged<NatureProfile> onNatureChanged;
  final ValueChanged<Stats> onIvChanged;
  final ValueChanged<Stats> onEvChanged;
  final ValueChanged<String> onAbilityChanged;
  final ValueChanged<String?> onItemChanged;
  final ValueChanged<Rank> onRankChanged;
  final ValueChanged<int> onHpPercentChanged;
  final ValueChanged<StatusCondition> onStatusChanged;

  const StatInput({
    super.key,
    required this.level,
    required this.nature,
    required this.iv,
    required this.ev,
    required this.baseStats,
    required this.pokemonAbilities,
    this.selectedAbility,
    this.selectedItem,
    required this.rank,
    required this.hpPercent,
    required this.status,
    required this.onLevelChanged,
    required this.onNatureChanged,
    required this.onIvChanged,
    required this.onEvChanged,
    required this.onAbilityChanged,
    required this.onItemChanged,
    required this.onRankChanged,
    required this.onHpPercentChanged,
    required this.onStatusChanged,
    this.opponentSpeed,
    this.opponentAlwaysLast = false,
    this.weather = Weather.none,
    this.terrain = Terrain.none,
    this.room = const RoomConditions(),
    this.isDynamaxed = false,
    this.tailwind = false,
    this.onItemTap,
    this.onAbilityTap,
    this.onStatEditComplete,
    this.useSpMode = false,
    this.onSpModeChanged,
    this.isAttacker = true,
  });

  /// Side identity — drives accent color for toggles like EV↔SP.
  final bool isAttacker;

  final VoidCallback? onItemTap;
  final VoidCallback? onAbilityTap;
  final VoidCallback? onStatEditComplete;

  /// Whether to display EV in SP (Stat Point) mode for Champions.
  final bool useSpMode;
  final ValueChanged<bool>? onSpModeChanged;

  final int? opponentSpeed;
  final bool opponentAlwaysLast;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final bool isDynamaxed;
  final bool tailwind;

  @override
  State<StatInput> createState() => _StatInputState();
}

class _StatInputState extends State<StatInput> {
  Map<String, String> _abilityNameMap = {};
  static Map<String, Ability> _abilityDataMap = {};
  List<String> _cachedSortedAbilities = [];
  List<String> _lastPokemonAbilities = [];
  int _evResetCounter = 0;
  final _abilityController = TextEditingController();
  final _itemController = TextEditingController();
  final _abilityFocusNode = FocusNode();
  final _itemFocusNode = FocusNode();

  Map<String, String> _itemNameMap = {};
  static Map<String, Item> _itemDataMap = {};

  bool _hasFocusedStatField = false;

  @override
  void initState() {
    super.initState();
    _loadAbilities();
    _loadItems();
  }

  @override
  void didUpdateWidget(covariant StatInput old) {
    super.didUpdateWidget(old);
    // SP/EV toggle always resets display regardless of focus
    if (widget.useSpMode != old.useSpMode) {
      _hasFocusedStatField = false;
      _evResetCounter++;
    }
    // Only reset TextFormField when values changed externally
    // (e.g. from speed tab), NOT during typing (focus is active).
    else if (!_hasFocusedStatField &&
        (widget.ev != old.ev || widget.iv != old.iv ||
         widget.rank != old.rank || widget.hpPercent != old.hpPercent)) {
      _evResetCounter++;
    }
  }

  @override
  void dispose() {
    _abilityController.dispose();
    _itemController.dispose();
    _abilityFocusNode.dispose();
    _itemFocusNode.dispose();
    super.dispose();
  }


  static Map<String, String>? _abilityCache;
  static AppLanguage? _abilityCacheLang;
  static Map<String, String>? _itemCache;
  static AppLanguage? _itemCacheLang;

  Future<void> _loadAbilities() async {
    if (_abilityCache != null && _abilityCacheLang == AppStrings.current) {
      final dex = await loadAbilitydex();
      setState(() {
        _abilityNameMap = _abilityCache!;
        _abilityDataMap = dex;
        _rebuildSortedAbilities();
      });
      return;
    }
    try {
      final dex = await loadAbilitydex();
      final map = <String, String>{};
      for (final entry in dex.entries) {
        // Skip non-mainline (spin-off / Colosseum) abilities — their
        // names would otherwise show up in the picker and confuse
        // users. The explicit flag replaces the old "nameKo has no
        // Hangul" heuristic, which was ambiguous and produced edge
        // cases.
        if (entry.value.nonMainline) continue;
        map[entry.key] = entry.value.localizedName;
      }
      _abilityCache = map;
      _abilityCacheLang = AppStrings.current;
      setState(() {
        _abilityNameMap = map;
        _abilityDataMap = dex;
        _rebuildSortedAbilities();
      });
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    if (_itemCache != null && _itemCacheLang == AppStrings.current) {
      final dex = await loadItemdex();
      setState(() { _itemNameMap = _itemCache!; _itemDataMap = dex; });
      return;
    }
    try {
      final dex = await loadItemdex();
      final map = <String, String>{};
      for (final entry in dex.entries) {
        if (entry.value.battle) {
          map[entry.key] = entry.value.localizedName;
        }
      }
      _itemCache = map;
      _itemCacheLang = AppStrings.current;
      setState(() {
        _itemNameMap = map;
        _itemDataMap = dex;
      });
    } catch (_) {}
  }

  String _abilityKo(String englishName) {
    return _abilityNameMap[englishName] ?? englishName;
  }

  /// Expands abilities that have numbered variants (e.g. Supreme Overlord → 0~5).
  static List<String> _expandAbilities(List<String> abilities, Map<String, String> nameMap) {
    final expanded = <String>[];
    for (final a in abilities) {
      if (a == 'Supreme Overlord') {
        for (int i = 0; i <= 5; i++) {
          final key = 'Supreme Overlord $i';
          if (nameMap.containsKey(key)) expanded.add(key);
        }
      } else {
        expanded.add(a);
      }
    }
    return expanded;
  }

  void _rebuildSortedAbilities() {
    final all = _abilityNameMap.keys.toList();
    final pokemon = _expandAbilities(widget.pokemonAbilities, _abilityNameMap);
    final rest = all.where((a) => !pokemon.contains(a)).toList();
    rest.sort((a, b) => _abilityKo(a).compareTo(_abilityKo(b)));
    _cachedSortedAbilities = [...pokemon, ...rest];
    _lastPokemonAbilities = List.of(widget.pokemonAbilities);
  }

  List<String> _sortedAbilities() {
    if (!_listEquals(_lastPokemonAbilities, widget.pokemonAbilities)) {
      _rebuildSortedAbilities();
    }
    return _cachedSortedAbilities;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final actualStats = StatCalculator.calculate(
      baseStats: widget.baseStats,
      iv: widget.iv,
      ev: widget.ev,
      nature: widget.nature,
      level: widget.level,
      rank: widget.rank,
    );

    return Column(
      children: [
        // Level + Ability + Status
        Row(
          children: [
            SizedBox(
              width: 48,
              child: _LevelInput(
                level: widget.level,
                onChanged: widget.onLevelChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: _abilityNameMap.isNotEmpty
                  ? KeyedSubtree(
                      key: ValueKey('ability_${widget.selectedAbility}'),
                      child: _abilityAutocomplete(),
                    )
                  : InputDecorator(
                      decoration: InputDecoration(labelText: AppStrings.t('label.ability'), isDense: true),
                      child: const Text('-', style: TextStyle(color: Colors.grey)),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: PopupMenuButton<StatusCondition>(
                initialValue: widget.status,
                tooltip: AppStrings.t('label.status'),
                popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: AppStrings.t('label.status'),
                    isDense: true,
                  ),
                  child: Text(
                    '${KoStrings.statusIcon[widget.status]!} ${widget.status.localizedName}',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                itemBuilder: (_) => StatusCondition.values
                    .map((st) => PopupMenuItem(
                        value: st,
                        child: Row(
                          children: [
                            Text(KoStrings.statusIcon[st]!, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(st.localizedName),
                          ],
                        )))
                    .toList(),
                onSelected: (v) => widget.onStatusChanged(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Nature (two dropdowns: ↑ / ↓) + Item.
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _natureDropdowns(),
            ),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _itemAutocomplete()),
          ],
        ),
        const SizedBox(height: 12),

        _statHeader(context),
        const Divider(height: 1),

        _statRow(context, 'HP', widget.baseStats.hp, widget.iv.hp, widget.ev.hp,
            actualStats.hp, null, 0, (newIv, newEv, _) {
          widget.onIvChanged(_copyIv(hpVal: newIv));
          widget.onEvChanged(_copyEv(hpVal: newEv));
        }, rankIndex: -1, dynamaxHp: widget.isDynamaxed),
        _statRow(context, AppStrings.t('stat.attack'), widget.baseStats.attack, widget.iv.attack,
            widget.ev.attack, actualStats.attack, widget.nature.attackModifier,
            widget.rank.attack, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(atkVal: newIv));
          widget.onEvChanged(_copyEv(atkVal: newEv));
          if (newRank != null) _updateRank(atkVal: newRank);
        }, rankIndex: 0),
        _statRow(context, AppStrings.t('stat.defense'), widget.baseStats.defense, widget.iv.defense,
            widget.ev.defense, actualStats.defense, widget.nature.defenseModifier,
            widget.rank.defense, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(defVal: newIv));
          widget.onEvChanged(_copyEv(defVal: newEv));
          if (newRank != null) _updateRank(defVal: newRank);
        }, rankIndex: 1),
        _statRow(context, AppStrings.t('stat.spAttack'), widget.baseStats.spAttack, widget.iv.spAttack,
            widget.ev.spAttack, actualStats.spAttack, widget.nature.spAttackModifier,
            widget.rank.spAttack, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(spaVal: newIv));
          widget.onEvChanged(_copyEv(spaVal: newEv));
          if (newRank != null) _updateRank(spaVal: newRank);
        }, rankIndex: 2),
        _statRow(context, AppStrings.t('stat.spDefense'), widget.baseStats.spDefense, widget.iv.spDefense,
            widget.ev.spDefense, actualStats.spDefense, widget.nature.spDefenseModifier,
            widget.rank.spDefense, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(spdVal: newIv));
          widget.onEvChanged(_copyEv(spdVal: newEv));
          if (newRank != null) _updateRank(spdVal: newRank);
        }, rankIndex: 3),
        _statRow(context, AppStrings.t('stat.speed'), widget.baseStats.speed, widget.iv.speed,
            widget.ev.speed, actualStats.speed, widget.nature.speedModifier,
            widget.rank.speed, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(speVal: newIv));
          widget.onEvChanged(_copyEv(speVal: newEv));
          if (newRank != null) _updateRank(speVal: newRank);
        }, rankIndex: 4),
        const Divider(height: 1),
        _summaryRow(context, _effectiveSpeed(actualStats.speed)),
      ],
    );
  }

  /// Two compact nature pickers — ↑ slot and ↓ slot, each rendered
  /// as a [PopupMenuButton] rather than [DropdownButtonFormField]
  /// so the popup animation is snappy (100 ms) instead of Flutter's
  /// default 300 ms drawer feel, which matters when you're tapping
  /// through damage checks mid-battle.
  Widget _natureDropdowns() {
    return Row(
      children: [
        Expanded(child: _naturePicker(widget.nature.up, true)),
        const SizedBox(width: 6),
        Expanded(child: _naturePicker(widget.nature.down, false)),
      ],
    );
  }

  Widget _naturePicker(NatureStat? value, bool isUp) {
    final tint = isUp ? Colors.red : Colors.blue;
    final label = value == null
        ? AppStrings.t('nature.none')
        : _statLabel(value);
    final textColor = value == null ? Colors.grey : tint;
    // Modal bottom sheet instead of PopupMenu — PopupMenu had a
    // known iOS rendering bug where the menu got drawn behind other
    // widgets when this picker was in the second row of StatInput
    // inside a SingleChildScrollView. Bottom sheets use a different
    // route path and don't hit that bug.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _openNatureSheet(isUp, tint, value),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: AppStrings.t(
              isUp ? 'nature.buffLabel' : 'nature.nerfLabel'),
          isDense: true,
        ),
        child: Text(label, style: TextStyle(fontSize: 16, color: textColor)),
      ),
    );
  }

  Future<void> _openNatureSheet(
      bool isUp, Color tint, NatureStat? current) async {
    final picked = await showModalBottomSheet<_NaturePick>(
      context: context,
      useRootNavigator: true,
      sheetAnimationStyle:
          AnimationStyle(duration: const Duration(milliseconds: 150)),
      showDragHandle: false,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _natureSheetOption(
              ctx,
              label: AppStrings.t('nature.none'),
              color: Colors.grey,
              value: _NaturePick.none,
              selected: current == null,
            ),
            for (final s in NatureStat.values)
              _natureSheetOption(
                ctx,
                label: _statLabel(s),
                color: tint,
                value: _pickFromStat(s),
                selected: current == s,
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final stat = _statFromPick(picked);
    widget.onNatureChanged(isUp
        ? widget.nature.copyWith(up: stat, clearUp: stat == null)
        : widget.nature.copyWith(down: stat, clearDown: stat == null));
  }

  Widget _natureSheetOption(
    BuildContext ctx, {
    required String label,
    required Color color,
    required _NaturePick value,
    required bool selected,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        selected ? Icons.check : null,
        size: 18, color: color,
      ),
      title: Text(label,
          style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
      onTap: () => Navigator.pop(ctx, value),
    );
  }

  String _statLabel(NatureStat s) {
    switch (s) {
      case NatureStat.atk: return AppStrings.t('stat.attack');
      case NatureStat.def: return AppStrings.t('stat.defense');
      case NatureStat.spa: return AppStrings.t('stat.spAttack');
      case NatureStat.spd: return AppStrings.t('stat.spDefense');
      case NatureStat.spe: return AppStrings.t('stat.speed');
    }
  }

  Widget _abilityAutocomplete() {
    final sorted = _sortedAbilities();
    final initialText = widget.selectedAbility != null
        ? _abilityKo(widget.selectedAbility!)
        : '';
    if (!_abilityFocusNode.hasFocus) {
      _abilityController.text = initialText;
    }

    return buildTypeAhead<String>(
      controller: _abilityController,
      focusNode: _abilityFocusNode,
      suggestionsCallback: (query) {
        if (query.isEmpty || query == initialText) return sorted;
        return sorted.where((a) {
          final data = _abilityDataMap[a];
          return triLanguageScore(query,
            nameKo: data?.nameKo ?? _abilityKo(a),
            nameEn: data?.nameEn ?? a,
            nameJa: data?.nameJa ?? '',
            internalKey: a,
          ) > 0;
        }).toList();
      },
      decoration: InputDecoration(labelText: AppStrings.t('label.ability'), isDense: true),
      itemBuilder: (context, ability) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(_abilityKo(ability), style: const TextStyle(fontSize: 14)),
        );
      },
      onSelected: (v) {
        _abilityController.text = _abilityKo(v);
        _abilityFocusNode.unfocus();
        widget.onAbilityChanged(v);
      },
      onSubmittedPick: (text) {
        if (text.isEmpty) return null;
        final matches = sorted.where((a) {
          final data = _abilityDataMap[a];
          return triLanguageScore(text,
            nameKo: data?.nameKo ?? _abilityKo(a),
            nameEn: data?.nameEn ?? a,
            nameJa: data?.nameJa ?? '',
            internalKey: a,
          ) > 0;
        }).toList();
        return matches.isNotEmpty ? matches.first : null;
      },
    );
  }

  String _itemDisplayName(String? key) {
    if (key == null || key.isEmpty) return AppStrings.t('label.none');
    return _itemNameMap[key] ?? key;
  }

  Widget _itemAutocomplete() {
    final allItems = ['', ..._itemNameMap.keys];
    if (widget.selectedItem != null && allItems.contains(widget.selectedItem)) {
      allItems.remove(widget.selectedItem);
      allItems.insert(0, widget.selectedItem!);
    }

    final initialText = _itemDisplayName(widget.selectedItem);
    if (!_itemFocusNode.hasFocus) {
      _itemController.text = initialText;
    }

    return KeyedSubtree(
      key: ValueKey('item_${widget.selectedItem}'),
      child: buildTypeAhead<String>(
        controller: _itemController,
        focusNode: _itemFocusNode,
        suggestionsCallback: (text) {
          if (text.isEmpty || text == initialText) return allItems;
          return allItems.where((key) {
            final data = _itemDataMap[key];
            return triLanguageScore(text,
              nameKo: data?.nameKo ?? _itemDisplayName(key.isEmpty ? null : key),
              nameEn: data?.nameEn ?? '',
              nameJa: data?.nameJa ?? '',
              internalKey: key,
            ) > 0;
          }).toList();
        },
        decoration: InputDecoration(labelText: AppStrings.t('label.item'), isDense: true),
        itemBuilder: (context, key) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(_itemDisplayName(key.isEmpty ? null : key), style: const TextStyle(fontSize: 14)),
          );
        },
        onSelected: (v) {
          _itemController.text = _itemDisplayName(v.isEmpty ? null : v);
          _itemFocusNode.unfocus();
          widget.onItemChanged(v.isEmpty ? null : v);
        },
        onSubmittedPick: (text) {
          if (text.isEmpty) return null;
          final matches = allItems.where((key) {
            final data = _itemDataMap[key];
            return triLanguageScore(text,
              nameKo: data?.nameKo ?? _itemDisplayName(key.isEmpty ? null : key),
              nameEn: data?.nameEn ?? '',
              nameJa: data?.nameJa ?? '',
              internalKey: key,
            ) > 0;
          }).toList();
          return matches.isNotEmpty ? matches.first : null;
        },
      ),
    );
  }

  void _updateRank({int? atkVal, int? defVal, int? spaVal, int? spdVal, int? speVal}) {
    widget.onRankChanged(Rank(
      attack: atkVal ?? widget.rank.attack,
      defense: defVal ?? widget.rank.defense,
      spAttack: spaVal ?? widget.rank.spAttack,
      spDefense: spdVal ?? widget.rank.spDefense,
      speed: speVal ?? widget.rank.speed,
    ));
  }

  int _effectiveSpeed(int baseSpeed) {
    return calcEffectiveSpeed(
      baseSpeed: baseSpeed,
      ability: widget.selectedAbility,
      item: widget.selectedItem,
      status: widget.status,
      weather: widget.weather,
      terrain: widget.terrain,
      isDynamaxed: widget.isDynamaxed,
      tailwind: widget.tailwind,
    );
  }

  Widget _summaryRow(BuildContext context, int mySpeed) {
    final bs = widget.baseStats;
    final ev = widget.ev;
    final baseTotal = bs.hp + bs.attack + bs.defense + bs.spAttack + bs.spDefense + bs.speed;

    final int usedPoints;
    final int maxPoints;
    if (widget.useSpMode) {
      usedPoints = ChampionsMode.totalSpFromEv(ev);
      maxPoints = ChampionsMode.maxTotalSp;
    } else {
      usedPoints = ev.hp + ev.attack + ev.defense + ev.spAttack + ev.spDefense + ev.speed;
      maxPoints = 510;
    }
    final style = const TextStyle(fontSize: 14, fontWeight: FontWeight.bold);

    String speedText = '';
    Color speedColor = Colors.grey;
    if (widget.opponentSpeed != null) {
      final bool alwaysLast = checkAlwaysLast(
          item: widget.selectedItem,
          ability: widget.selectedAbility,
          isDynamaxed: widget.isDynamaxed);
      final result = getSpeedResult(
        mySpeed: mySpeed,
        opponentSpeed: widget.opponentSpeed!,
        myAlwaysLast: alwaysLast,
        opponentAlwaysLast: widget.opponentAlwaysLast,
        room: widget.room,
      );
      switch (result) {
        case SpeedResult.alwaysLast:
          speedText = AppStrings.t('speed.guaranteedLast');
          speedColor = Colors.red;
        case SpeedResult.alwaysFirst:
          speedText = AppStrings.t('speed.guaranteedFirst');
          speedColor = Colors.green;
        case SpeedResult.faster:
          speedText = AppStrings.t('speed.faster');
          speedColor = Colors.green;
        case SpeedResult.slower:
          speedText = AppStrings.t('speed.slower');
          speedColor = Colors.red;
        case SpeedResult.tied:
          speedText = AppStrings.t('speed.tie');
        speedColor = Colors.orange;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 7, child: Text('${AppStrings.t('stat.total')} $baseTotal', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 6, child: Text(
            usedPoints > maxPoints ? '${AppStrings.t('ev.exceeded')} ${usedPoints - maxPoints}' : '${AppStrings.t('ev.remaining')} ${maxPoints - usedPoints}',
            style: style.copyWith(
              color: usedPoints > maxPoints ? Colors.red : null,
            ), textAlign: TextAlign.center)),
          Expanded(flex: 7, child: Text(speedText, style: style.copyWith(
            color: speedColor, fontSize: 14,
          ), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _modeLabel(String text, bool active) {
    final baseStyle = Theme.of(context).textTheme.bodySmall;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.isAttacker
        ? (isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: active
          ? BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(3),
            )
          : null,
      child: Text(
        text,
        style: baseStyle?.copyWith(
          fontWeight: active ? FontWeight.w700 : FontWeight.normal,
          color: active ? accent : Colors.grey,
        ),
      ),
    );
  }

  Widget _statHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    final isWide = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('', style: style)),
          Expanded(flex: 2, child: Text(AppStrings.t('stat.base'), style: style, textAlign: TextAlign.center)),
          Expanded(flex: isWide ? 2 : 3, child: Text(AppStrings.t('stat.iv'), style: style, textAlign: TextAlign.center)),
          Expanded(flex: isWide ? 7 : 6, child: widget.onSpModeChanged != null
              ? InkWell(
                  onTap: () => widget.onSpModeChanged!(!widget.useSpMode),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _modeLabel('EV', !widget.useSpMode),
                      Text(' ↔ ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                      _modeLabel('SP', widget.useSpMode),
                    ],
                  ),
                )
              : Text(AppStrings.t('stat.ev'), style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text(AppStrings.t('stat.rank'), style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text(AppStrings.t('stat.actual'), style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context, String label, int base, int ivVal, int evVal,
    int actual, double? natureModifier, int rankVal,
    void Function(int newIv, int newEv, int? newRank) onChanged, {
    required int rankIndex,
    bool dynamaxHp = false,
  }) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    Color? actualColor;
    if (natureModifier != null && natureModifier > 1.0) actualColor = Colors.red;
    if (natureModifier != null && natureModifier < 1.0) actualColor = Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(flex: 2, child: Text('$base', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
          Expanded(flex: isWide ? 2 : 3, child: _miniInput(ivVal, 0, 31, (v) => onChanged(v, evVal, null))),
          Expanded(
            flex: isWide ? 7 : 6,
            child: _evControl(evVal, (v) => onChanged(ivVal, v, null)),
          ),
          Expanded(
            flex: 3,
            child: rankIndex >= 0
                ? _rankControl(rankVal, (v) => onChanged(ivVal, evVal, v))
                : _hpPercentControl(),
          ),
          Expanded(
            flex: 3,
            child: dynamaxHp
              ? FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$actual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: actualColor)),
                      Text('(×2)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                )
              : Text('$actual', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: actualColor)),
          ),
        ],
      ),
    );
  }

  Widget _evControl(int value, ValueChanged<int> onChanged) {
    final isWide = MediaQuery.of(context).size.width >= 600;
    final sp = widget.useSpMode;
    final displayValue = sp ? ChampionsMode.evToSp(value) : value;
    final maxDisplay = sp ? ChampionsMode.maxPerStat : 252;
    final step = sp ? 1 : 4;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _flexButton('0', () {
            setState(() => _evResetCounter++);
            onChanged(0);
            widget.onStatEditComplete?.call();
          }),
        ),
        if (isWide)
          Expanded(
            flex: 2,
            child: _flexButton('-', displayValue <= 0 ? null : () {
              setState(() => _evResetCounter++);
              if (sp) {
                final newSp = (displayValue - step).clamp(0, maxDisplay);
                onChanged(ChampionsMode.spToEv(newSp));
              } else {
                onChanged((value - step).clamp(0, 252));
              }
              widget.onStatEditComplete?.call();
            }),
          ),
        Expanded(
          flex: 3,
          child: Focus(
            onFocusChange: (hasFocus) {
              _hasFocusedStatField = hasFocus;
              if (!hasFocus) {
                setState(() => _evResetCounter++); // normalize display
                widget.onStatEditComplete?.call();
              }
            },
            child: SizedBox(
              height: 28,
              child: TextFormField(
                key: ValueKey('ev_$_evResetCounter'),
                initialValue: '$displayValue',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ClampingFormatter(min: 0, max: maxDisplay),
                ],
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                ),
                onChanged: (text) {
                  final parsed = int.tryParse(text);
                  if (parsed != null) {
                    if (sp) {
                      onChanged(ChampionsMode.spToEv(parsed.clamp(0, maxDisplay)));
                    } else {
                      onChanged(parsed.clamp(0, 252));
                    }
                  } else if (text.isEmpty) {
                    onChanged(0);
                  }
                },
              ),
            ),
          ),
        ),
        if (isWide)
          Expanded(
            flex: 2,
            child: _flexButton('+', displayValue >= maxDisplay ? null : () {
              setState(() => _evResetCounter++);
              if (sp) {
                final newSp = (displayValue + step).clamp(0, maxDisplay);
                onChanged(ChampionsMode.spToEv(newSp));
              } else {
                onChanged((value + step).clamp(0, 252));
              }
              widget.onStatEditComplete?.call();
            }),
          ),
        Expanded(
          flex: 2,
          child: _flexButton('max', () {
            setState(() => _evResetCounter++);
            onChanged(sp ? ChampionsMode.spToEv(maxDisplay) : 252);
            widget.onStatEditComplete?.call();
          }),
        ),
      ],
    );
  }

  Widget _hpPercentControl() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 28,
            child: TextFormField(
              key: const ValueKey('hp_pct'),
              initialValue: '${widget.hpPercent}',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ClampingFormatter(min: 0, max: 100),
              ],
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                suffixText: '%',
                suffixStyle: TextStyle(fontSize: 11),
              ),
              onChanged: (text) {
                final parsed = int.tryParse(text);
                if (parsed != null) {
                  widget.onHpPercentChanged(parsed.clamp(0, 100));
                } else if (text.isEmpty) {
                  widget.onHpPercentChanged(100);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _flexButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      height: 24,
      child: IconButton(
        onPressed: onPressed,
        icon: Text(text, style: const TextStyle(fontSize: 10)),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          side: const BorderSide(width: 0.5, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _rankControl(int value, ValueChanged<int> onChanged) {
    // Keying on _evResetCounter (but NOT on value) keeps the same widget
    // alive while the user types, so the keyboard doesn't collapse on
    // every keystroke. External resets (sample load, reset button) bump
    // the counter, which reseeds the display with a signed value.
    return Focus(
      onFocusChange: (hasFocus) {
        _hasFocusedStatField = hasFocus;
        if (!hasFocus) {
          setState(() => _evResetCounter++);
          widget.onStatEditComplete?.call();
        }
      },
      child: SizedBox(
        height: 32,
        child: TextFormField(
        key: ValueKey('rank_$_evResetCounter'),
        initialValue: value > 0 ? '+$value' : '$value',
        textAlign: TextAlign.center,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^[+-]?[0-9]?$')),
        ],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: value > 0 ? Colors.red : value < 0 ? Colors.blue : null,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        ),
        onChanged: (text) {
          // Don't commit incomplete inputs like '-' or '+' — wait for digits
          // (or focus loss, which reseeds from the committed value).
          if (text.isEmpty) {
            onChanged(0);
            return;
          }
          if (text == '-' || text == '+') return;
          final parsed = int.tryParse(text.replaceAll('+', ''));
          if (parsed != null) {
            onChanged(parsed.clamp(-6, 6));
          }
        },
      ),
      ),
    );
  }

  Widget _miniInput(int value, int min, int max, ValueChanged<int> onChanged) {
    return Focus(
      onFocusChange: (hasFocus) {
        _hasFocusedStatField = hasFocus;
        if (!hasFocus) {
          setState(() => _evResetCounter++);
          widget.onStatEditComplete?.call();
        }
      },
      child: SizedBox(
        height: 32,
        child: TextFormField(
          initialValue: '$value',
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _ClampingFormatter(min: min, max: max),
          ],
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          ),
          onChanged: (text) {
            final parsed = int.tryParse(text);
            if (parsed != null) {
              onChanged(parsed);
            } else if (text.isEmpty) {
              onChanged(min);
            }
          },
        ),
      ),
    );
  }

  Stats _copyIv({int? hpVal, int? atkVal, int? defVal, int? spaVal, int? spdVal, int? speVal}) {
    return Stats(hp: hpVal ?? widget.iv.hp, attack: atkVal ?? widget.iv.attack,
      defense: defVal ?? widget.iv.defense, spAttack: spaVal ?? widget.iv.spAttack,
      spDefense: spdVal ?? widget.iv.spDefense, speed: speVal ?? widget.iv.speed);
  }

  Stats _copyEv({int? hpVal, int? atkVal, int? defVal, int? spaVal, int? spdVal, int? speVal}) {
    return Stats(hp: hpVal ?? widget.ev.hp, attack: atkVal ?? widget.ev.attack,
      defense: defVal ?? widget.ev.defense, spAttack: spaVal ?? widget.ev.spAttack,
      spDefense: spdVal ?? widget.ev.spDefense, speed: speVal ?? widget.ev.speed);
  }

}

/// Level input that clamps to 1~100 and shows the clamped value on focus loss.
class _LevelInput extends StatefulWidget {
  final int level;
  final ValueChanged<int> onChanged;

  const _LevelInput({required this.level, required this.onChanged});

  @override
  State<_LevelInput> createState() => _LevelInputState();
}

class _LevelInputState extends State<_LevelInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.level}');
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_LevelInput old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level && !_focusNode.hasFocus) {
      _controller.text = '${widget.level}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final parsed = int.tryParse(_controller.text);
      final clamped = parsed != null ? parsed.clamp(1, 100) : 1;
      _controller.text = '$clamped';
      widget.onChanged(clamped);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _ClampingFormatter(min: 1, max: 100),
      ],
      decoration: InputDecoration(
        labelText: AppStrings.t('label.level'),
        isDense: true,
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) {
          widget.onChanged(parsed.clamp(1, 100));
        } else if (text.isEmpty) {
          widget.onChanged(50);
        }
      },
    );
  }
}
