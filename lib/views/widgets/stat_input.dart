import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/abilitydex.dart';
import '../../data/itemdex.dart';
import '../../models/nature.dart';
import '../../models/rank.dart';
import '../../models/stats.dart';
import '../../models/status.dart';
import '../../utils/localization.dart';
import '../../models/room.dart';
import '../../models/terrain.dart';
import '../../models/weather.dart';
import '../../utils/ability_effects.dart';
import '../../utils/item_effects.dart';
import '../../utils/speed_calculator.dart';
import '../../utils/room_effects.dart';
import '../../utils/stat_calculator.dart';

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

class StatInput extends StatefulWidget {
  final int level;
  final Nature nature;
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
  final ValueChanged<Nature> onNatureChanged;
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
  });

  final VoidCallback? onItemTap;

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
  List<String> _cachedSortedAbilities = [];
  List<String> _lastPokemonAbilities = [];
  int _evResetCounter = 0;
  Timer? _debounceTimer;

  static final List<DropdownMenuItem<Nature>> _natureItems = Nature.values
      .map((n) => DropdownMenuItem(
            value: n,
            child: Text(
              _natureLabelStatic(n),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ))
      .toList();

  static String _natureLabelStatic(Nature n) {
    final ko = n.nameKo;
    String buff = '', nerf = '';
    if (n.attackModifier > 1.0) buff = '공격';
    if (n.defenseModifier > 1.0) buff = '방어';
    if (n.spAttackModifier > 1.0) buff = '특공';
    if (n.spDefenseModifier > 1.0) buff = '특방';
    if (n.speedModifier > 1.0) buff = '스피드';
    if (n.attackModifier < 1.0) nerf = '공격';
    if (n.defenseModifier < 1.0) nerf = '방어';
    if (n.spAttackModifier < 1.0) nerf = '특공';
    if (n.spDefenseModifier < 1.0) nerf = '특방';
    if (n.speedModifier < 1.0) nerf = '스피드';
    if (buff.isEmpty) return '$ko (무보정)';
    return '$ko (+$buff -$nerf)';
  }

  Map<String, String> _itemNameMap = {};

  @override
  @override
  void initState() {
    super.initState();
    _loadAbilities();
    _loadItems();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _debounce(VoidCallback fn) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 150), fn);
  }

  static Map<String, String>? _abilityCache;
  static Map<String, String>? _itemCache;

  Future<void> _loadAbilities() async {
    if (_abilityCache != null) {
      setState(() {
        _abilityNameMap = _abilityCache!;
        _rebuildSortedAbilities();
      });
      return;
    }
    try {
      final dex = await loadAbilitydex();
      final map = <String, String>{};
      for (final entry in dex.entries) {
        map[entry.key] = entry.value.nameKo;
      }
      _abilityCache = map;
      setState(() {
        _abilityNameMap = map;
        _rebuildSortedAbilities();
      });
    } catch (_) {}
  }

  Future<void> _loadItems() async {
    if (_itemCache != null) {
      setState(() { _itemNameMap = _itemCache!; });
      return;
    }
    try {
      final dex = await loadItemdex();
      final map = <String, String>{};
      for (final entry in dex.entries) {
        if (entry.value.battle) {
          map[entry.key] = entry.value.nameKo;
        }
      }
      _itemCache = map;
      setState(() {
        _itemNameMap = map;
      });
    } catch (_) {}
  }

  String _abilityKo(String englishName) {
    return _abilityNameMap[englishName] ?? englishName;
  }

  static bool _hasKorean(String s) =>
      s.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3);

  void _rebuildSortedAbilities() {
    final all = _abilityNameMap.keys
        .where((a) => _hasKorean(_abilityKo(a)))
        .toList();
    final pokemon = widget.pokemonAbilities;
    final rest = all.where((a) => !pokemon.contains(a)).toList();
    rest.sort((a, b) => _abilityKo(a).compareTo(_abilityKo(b)));
    _cachedSortedAbilities = [...pokemon, ...rest];
    _lastPokemonAbilities = List.of(pokemon);
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
                  : const InputDecorator(
                      decoration: InputDecoration(labelText: '특성', isDense: true),
                      child: Text('-', style: TextStyle(color: Colors.grey)),
                    ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 1,
              child: PopupMenuButton<StatusCondition>(
                initialValue: widget.status,
                tooltip: '상태이상',
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '상태이상',
                    isDense: true,
                  ),
                  child: Text(
                    '${KoStrings.statusIcon[widget.status]!} ${KoStrings.statusKo[widget.status]!}',
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
                            Text(KoStrings.statusKo[st]!),
                          ],
                        )))
                    .toList(),
                onSelected: (v) => widget.onStatusChanged(v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Nature + Item (searchable)
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<Nature>(
                value: widget.nature,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '성격', isDense: true),
                items: _natureItems,
                onChanged: (v) => widget.onNatureChanged(v!),
              ),
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
        _statRow(context, '공격', widget.baseStats.attack, widget.iv.attack,
            widget.ev.attack, actualStats.attack, widget.nature.attackModifier,
            widget.rank.attack, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(atkVal: newIv));
          widget.onEvChanged(_copyEv(atkVal: newEv));
          if (newRank != null) _updateRank(atkVal: newRank);
        }, rankIndex: 0),
        _statRow(context, '방어', widget.baseStats.defense, widget.iv.defense,
            widget.ev.defense, actualStats.defense, widget.nature.defenseModifier,
            widget.rank.defense, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(defVal: newIv));
          widget.onEvChanged(_copyEv(defVal: newEv));
          if (newRank != null) _updateRank(defVal: newRank);
        }, rankIndex: 1),
        _statRow(context, '특공', widget.baseStats.spAttack, widget.iv.spAttack,
            widget.ev.spAttack, actualStats.spAttack, widget.nature.spAttackModifier,
            widget.rank.spAttack, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(spaVal: newIv));
          widget.onEvChanged(_copyEv(spaVal: newEv));
          if (newRank != null) _updateRank(spaVal: newRank);
        }, rankIndex: 2),
        _statRow(context, '특방', widget.baseStats.spDefense, widget.iv.spDefense,
            widget.ev.spDefense, actualStats.spDefense, widget.nature.spDefenseModifier,
            widget.rank.spDefense, (newIv, newEv, newRank) {
          widget.onIvChanged(_copyIv(spdVal: newIv));
          widget.onEvChanged(_copyEv(spdVal: newEv));
          if (newRank != null) _updateRank(spdVal: newRank);
        }, rankIndex: 3),
        _statRow(context, '스피드', widget.baseStats.speed, widget.iv.speed,
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

  Widget _abilityAutocomplete() {
    final sorted = _sortedAbilities();
    final initialText = widget.selectedAbility != null
        ? _abilityKo(widget.selectedAbility!)
        : '';

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: (a) => _abilityKo(a),
      optionsBuilder: (textEditingValue) {
        if (!kIsWeb && textEditingValue.composing != TextRange.empty) return sorted;
        if (textEditingValue.text.isEmpty ||
            textEditingValue.text == initialText) {
          return sorted;
        }
        final query = textEditingValue.text.toLowerCase();
        return sorted.where((a) =>
            _abilityKo(a).contains(query) ||
            a.toLowerCase().contains(query));
      },
      onSelected: (v) => widget.onAbilityChanged(v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '특성',
            isDense: true,
          ),
          onTap: () => controller.clear(),
        );
      },
    );
  }

  String _itemDisplayName(String? key) {
    if (key == null || key.isEmpty) return '없음';
    return _itemNameMap[key] ?? key;
  }

  Widget _itemAutocomplete() {
    final allItems = ['', ..._itemNameMap.keys];
    if (widget.selectedItem != null && allItems.contains(widget.selectedItem)) {
      allItems.remove(widget.selectedItem);
      allItems.insert(0, widget.selectedItem!);
    }

    final initialText = _itemDisplayName(widget.selectedItem);

    return KeyedSubtree(
      key: ValueKey('item_${widget.selectedItem}'),
      child: Autocomplete<String>(
      initialValue: TextEditingValue(text: initialText),
      displayStringForOption: (key) => _itemDisplayName(key.isEmpty ? null : key),
      optionsBuilder: (textEditingValue) {
        if (!kIsWeb && textEditingValue.composing != TextRange.empty) return allItems;
        if (textEditingValue.text.isEmpty ||
            textEditingValue.text == initialText) {
          return allItems;
        }
        final query = textEditingValue.text.toLowerCase();
        return allItems.where((key) {
          final ko = _itemDisplayName(key.isEmpty ? null : key);
          return ko.contains(query) || key.toLowerCase().contains(query);
        });
      },
      onSelected: (v) => widget.onItemChanged(v.isEmpty ? null : v),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: '아이템',
            isDense: true,
          ),
          onTap: () {
            controller.clear();
            widget.onItemTap?.call();
          },
        );
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
    final evTotal = ev.hp + ev.attack + ev.defense + ev.spAttack + ev.spDefense + ev.speed;
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
          speedText = '확정 후공';
          speedColor = Colors.red;
        case SpeedResult.alwaysFirst:
          speedText = '확정 선공';
          speedColor = Colors.green;
        case SpeedResult.faster:
          speedText = '상대보다 빠름 ▲';
          speedColor = Colors.green;
        case SpeedResult.slower:
          speedText = '상대보다 느림 ▼';
          speedColor = Colors.red;
        case SpeedResult.tied:
          speedText = '동속';
        speedColor = Colors.orange;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Container()),
          Expanded(flex: 2, child: Text('$baseTotal', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Container()),
          Expanded(flex: 6, child: Text('$evTotal/510', style: style.copyWith(
            color: evTotal > 510 ? Colors.red : null,
          ), textAlign: TextAlign.center)),
          Expanded(flex: 7, child: Text(speedText, style: style.copyWith(
            color: speedColor, fontSize: 14,
          ), textAlign: TextAlign.center)),
        ],
      ),
    );
  }

  Widget _statHeader(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('', style: style)),
          Expanded(flex: 2, child: Text('종족', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('개체', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 6, child: Text('노력', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('랭크', style: style, textAlign: TextAlign.center)),
          Expanded(flex: 3, child: Text('실수치', style: style, textAlign: TextAlign.center)),
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
    Color? actualColor;
    if (natureModifier != null && natureModifier > 1.0) actualColor = Colors.red;
    if (natureModifier != null && natureModifier < 1.0) actualColor = Colors.blue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: const TextStyle(fontSize: 14))),
          Expanded(flex: 2, child: Text('$base', textAlign: TextAlign.center, style: const TextStyle(fontSize: 14))),
          Expanded(flex: 3, child: _miniInput(ivVal, 0, 31, (v) => onChanged(v, evVal, null))),
          Expanded(
            flex: 6,
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
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _flexButton('0', () {
            setState(() => _evResetCounter++);
            onChanged(0);
          }),
        ),
        Expanded(
          flex: 3,
          child: SizedBox(
            height: 28,
            child: TextFormField(
              key: ValueKey('ev_$_evResetCounter'),
              initialValue: '$value',
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                _ClampingFormatter(min: 0, max: 252),
              ],
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
              ),
              onChanged: (text) {
                final parsed = int.tryParse(text);
                if (parsed != null) {
                  _debounce(() => onChanged(parsed.clamp(0, 252)));
                }
              },
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _flexButton('max', () {
            setState(() => _evResetCounter++);
            onChanged(252);
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
    return SizedBox(
      height: 28,
      child: TextFormField(
        key: const ValueKey('rank_input'),
        initialValue: '$value',
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        inputFormatters: [
          _ClampingFormatter(min: -6, max: 6, allowNegative: true),
        ],
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: value > 0 ? Colors.red : value < 0 ? Colors.blue : null,
        ),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        ),
        onChanged: (text) {
          if (text.isEmpty || text == '-') return;
          final parsed = int.tryParse(text);
          if (parsed != null) {
            onChanged(parsed.clamp(-6, 6));
          }
        },
      ),
    );
  }

  Widget _miniInput(int value, int min, int max, ValueChanged<int> onChanged) {
    return SizedBox(
      height: 32,
      child: TextFormField(
        initialValue: '$value',
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
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
            _debounce(() => onChanged(parsed));
          }
        },
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
      decoration: const InputDecoration(
        labelText: '레벨',
        isDense: true,
      ),
      onChanged: (text) {
        final parsed = int.tryParse(text);
        if (parsed != null) {
          widget.onChanged(parsed.clamp(1, 100));
        }
      },
    );
  }
}
