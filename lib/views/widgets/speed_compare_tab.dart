import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../../data/abilitydex.dart';
import '../../data/itemdex.dart';
import '../../models/ability.dart';
import '../../models/battle_pokemon.dart';
import '../../models/item.dart';
import '../../models/nature.dart';
import '../../models/status.dart';
import '../../utils/korean_search.dart';
import '../../utils/app_strings.dart';
import '../../models/room.dart';
import '../../models/terrain.dart';
import '../../models/weather.dart';
import '../../utils/battle_facade.dart';
import '../../utils/speed_calculator.dart';
import '../../utils/speed_tier.dart';
import 'typeahead_helpers.dart';
import '../../utils/champions_mode.dart';
import '../../utils/stat_calculator.dart';
import '../../utils/room_effects.dart';
import '../widgets/pokemon_selector.dart';

/// Self-contained speed comparison tab with keep-alive.
class SpeedCompareTab extends StatefulWidget {
  final BattlePokemonState attacker;
  final BattlePokemonState defender;
  final Weather weather;
  final Terrain terrain;
  final RoomConditions room;
  final VoidCallback onChanged;
  final int resetCounter;
  final Map<String, String> abilityNameMap;
  final Map<String, String> itemNameMap;
  final bool useSpMode;
  final ValueChanged<bool>? onSpModeChanged;

  const SpeedCompareTab({
    super.key,
    required this.attacker,
    required this.defender,
    required this.weather,
    required this.terrain,
    required this.room,
    required this.onChanged,
    required this.resetCounter,
    required this.abilityNameMap,
    required this.itemNameMap,
    this.useSpMode = false,
    this.onSpModeChanged,
  });

  @override
  State<SpeedCompareTab> createState() => SpeedCompareTabState();
}

class SpeedCompareTabState extends State<SpeedCompareTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _screenshotController = ScreenshotController();
  final _scrollController = ScrollController();
  final _atkPanelKey = GlobalKey();
  final _defPanelKey = GlobalKey();
  final _atkAbilityRowKey = GlobalKey();
  final _atkItemRowKey = GlobalKey();
  final _defAbilityRowKey = GlobalKey();
  final _defItemRowKey = GlobalKey();
  final _atkAbilityController = TextEditingController();
  final _atkItemController = TextEditingController();
  final _atkNatureController = TextEditingController();
  final _defAbilityController = TextEditingController();
  final _defItemController = TextEditingController();
  final _defNatureController = TextEditingController();
  final _atkAbilityFocus = FocusNode();
  final _atkItemFocus = FocusNode();
  final _atkNatureFocus = FocusNode();
  final _defAbilityFocus = FocusNode();
  final _defItemFocus = FocusNode();
  final _defNatureFocus = FocusNode();

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _atkAbilityController.dispose();
    _atkItemController.dispose();
    _atkNatureController.dispose();
    _defAbilityController.dispose();
    _defItemController.dispose();
    _defNatureController.dispose();
    _atkAbilityFocus.dispose();
    _atkItemFocus.dispose();
    _atkNatureFocus.dispose();
    _defAbilityFocus.dispose();
    _defItemFocus.dispose();
    _defNatureFocus.dispose();
    super.dispose();
  }


  Future<Uint8List?> captureScreenshot() async {
    try {
      return await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
        pixelRatio: 2.0,
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, String> get _abilityNameMap => widget.abilityNameMap;
  Map<String, String> get _itemNameMap => widget.itemNameMap;
  Map<String, Ability> _abilityDataMap = {};
  Map<String, Item> _itemDataMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final abilities = await loadAbilitydex();
    final items = await loadItemdex();
    if (mounted) setState(() { _abilityDataMap = abilities; _itemDataMap = items; });
  }

  int _calcEffectiveSpeed(BattlePokemonState s) {
    return BattleFacade.calcSpeed(
      state: s,
      weather: widget.weather,
      terrain: widget.terrain,
      room: widget.room,
    );
  }

  bool _isAlwaysLast(BattlePokemonState s) => isAlwaysLast(s);

  void _notify() {
    widget.onChanged();
  }

  String _speedTierDescription(int level, int effSpeed) {
    final table = getSpeedTierTable(level);
    return table.describe(effSpeed);
  }

  String _itemKo(String? key) {
    if (key == null || key.isEmpty) return AppStrings.t('label.none');
    if (_itemNameMap.isEmpty) return '...';
    return _itemNameMap[key] ?? key;
  }

  String _abilityKo(String key) {
    if (_abilityNameMap.isEmpty) return '...';
    return _abilityNameMap[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final atk = widget.attacker;
    final def = widget.defender;
    final atkEffSpeed = _calcEffectiveSpeed(atk);
    final defEffSpeed = _calcEffectiveSpeed(def);
    final atkAlwaysLast = _isAlwaysLast(atk);
    final defAlwaysLast = _isAlwaysLast(def);
    final result = getSpeedResult(
      mySpeed: atkEffSpeed,
      opponentSpeed: defEffSpeed,
      myAlwaysLast: atkAlwaysLast,
      opponentAlwaysLast: defAlwaysLast,
      room: widget.room,
    );
    final diff = (atkEffSpeed - defEffSpeed).abs();

    String resultText;
    Color resultColor;
    switch (result) {
      case SpeedResult.faster:
        resultText = '▲ ${AppStrings.t('speed.atkFasterBy').replaceAll('{n}', '$diff')}';
        resultColor = Colors.red;
      case SpeedResult.slower:
        resultText = '▼ ${AppStrings.t('speed.defFasterBy').replaceAll('{n}', '$diff')}';
        resultColor = Colors.blue;
      case SpeedResult.tied:
        resultText = '⚡ ${AppStrings.t('speed.tie')}';
        resultColor = Colors.orange;
      case SpeedResult.alwaysFirst:
        resultText = '▲ ${AppStrings.t('speed.atkGuaranteedFirst')}';
        resultColor = Colors.red;
      case SpeedResult.alwaysLast:
        resultText = '▼ ${AppStrings.t('speed.defGuaranteedFirst')}';
        resultColor = Colors.blue;
    }

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 120),
      child: Screenshot(
        controller: _screenshotController,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            children: [
              KeyedSubtree(key: _atkPanelKey, child: _speedPanel(label: AppStrings.t('tab.attacker'), color: Colors.red, state: atk, effSpeed: atkEffSpeed, abilityRowKey: _atkAbilityRowKey, itemRowKey: _atkItemRowKey, abilityController: _atkAbilityController, itemController: _atkItemController, natureController: _atkNatureController, abilityFocus: _atkAbilityFocus, itemFocus: _atkItemFocus, natureFocus: _atkNatureFocus)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    Text(resultText, style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600, color: resultColor,
                    )),
                    if (widget.room.trickRoom)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('🔄 트릭룸 적용 중', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              KeyedSubtree(key: _defPanelKey, child: _speedPanel(label: AppStrings.t('tab.defender'), color: Colors.blue, state: def, effSpeed: defEffSpeed, abilityRowKey: _defAbilityRowKey, itemRowKey: _defItemRowKey, abilityController: _defAbilityController, itemController: _defItemController, natureController: _defNatureController, abilityFocus: _defAbilityFocus, itemFocus: _defItemFocus, natureFocus: _defNatureFocus)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _speedPanel({
    required String label,
    required Color color,
    required BattlePokemonState state,
    required int effSpeed,
    required GlobalKey abilityRowKey,
    required GlobalKey itemRowKey,
    required TextEditingController abilityController,
    required TextEditingController itemController,
    required TextEditingController natureController,
    required FocusNode abilityFocus,
    required FocusNode itemFocus,
    required FocusNode natureFocus,
  }) {
    final rawSpeed = StatCalculator.calculate(
      baseStats: state.baseStats, iv: state.iv, ev: state.ev,
      nature: state.nature, level: state.level, rank: state.rank,
    ).speed;
    final speedBase = state.baseStats.speed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$label ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
              Expanded(child: PokemonSelector(
                key: ValueKey('speed_pokemon_${widget.resetCounter}_${state.pokemonName}'),
                initialPokemonName: state.pokemonName,
                onSelected: (pokemon) {
                  setState(() => state.applyPokemon(pokemon));
                  _notify();
                },
              )),
              const SizedBox(width: 8),
              Text('${AppStrings.t('speed.baseValue')} $speedBase', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${AppStrings.t('speed.actual')} ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text('$rawSpeed', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text('  →  ', style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              Text('${AppStrings.t('speed.final')} ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Text('$effSpeed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          if (effSpeed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                _speedTierDescription(state.level, effSpeed),
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('${AppStrings.t('stat.iv')} ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Expanded(flex: 2, child: _SpeedNumInput(
                value: state.iv.speed,
                min: 0, max: 31,
                onChanged: (val) {
                  setState(() => state.iv = state.iv.copyWith(speed: val));
                  _notify();
                },
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: widget.onSpModeChanged != null
                    ? () => widget.onSpModeChanged!(!widget.useSpMode)
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.useSpMode ? 'SP ' : '${AppStrings.t('stat.ev')} ',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600,
                            fontWeight: FontWeight.bold)),
                    Icon(Icons.swap_horiz, size: 12, color: Colors.grey.shade600),
                  ],
                ),
              ),
              Expanded(flex: 3, child: _SpeedNumInput(
                value: widget.useSpMode
                    ? ChampionsMode.evToSp(state.ev.speed)
                    : state.ev.speed,
                min: 0,
                max: widget.useSpMode ? ChampionsMode.maxPerStat : 252,
                onChanged: (val) {
                  final ev = widget.useSpMode ? ChampionsMode.spToEv(val) : val;
                  setState(() => state.ev = state.ev.copyWith(speed: ev));
                  _notify();
                },
              )),
              _miniButton('0', () {
                setState(() => state.ev = state.ev.copyWith(speed: 0));
                _notify();
              }),
              _miniButton('max', () {
                final maxEv = widget.useSpMode
                    ? ChampionsMode.spToEv(ChampionsMode.maxPerStat) : 252;
                setState(() => state.ev = state.ev.copyWith(speed: maxEv));
                _notify();
              }),
              const SizedBox(width: 8),
              Text('${AppStrings.t('stat.rank')} ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              Expanded(flex: 2, child: _SpeedNumInput(
                value: state.rank.speed,
                min: -6, max: 6,
                signed: true,
                onChanged: (val) {
                  setState(() => state.rank = state.rank.copyWith(speed: val));
                  _notify();
                },
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            key: abilityRowKey,
            children: [
              SizedBox(width: 56, child: _SpeedNumInput(
                value: state.level,
                min: 1, max: 100,
                label: AppStrings.t('label.level'),
                onChanged: (val) {
                  setState(() => state.level = val);
                  _notify();
                },
              )),
              const SizedBox(width: 8),
              Expanded(flex: 3, child: _abilityAutocomplete(state, abilityController, abilityFocus)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: PopupMenuButton<StatusCondition>(
                initialValue: state.status,
                tooltip: AppStrings.t('label.status'),
                popUpAnimationStyle: AnimationStyle(duration: const Duration(milliseconds: 100)),
                child: InputDecorator(
                  decoration: InputDecoration(labelText: AppStrings.t('label.status'), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 4)),
                  child: Text(state.status.localizedName,
                    style: const TextStyle(fontSize: 14)),
                ),
                itemBuilder: (_) => StatusCondition.values.map((st) =>
                  PopupMenuItem(value: st, child: Text(st.localizedName)),
                ).toList(),
                onSelected: (v) { setState(() => state.status = v); _notify(); },
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            key: itemRowKey,
            children: [
              Expanded(flex: 3, child: _natureAutocomplete(state, natureController, natureFocus)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _itemAutocomplete(state, itemController, itemFocus)),
            ],
          ),
          // 순풍 - hidden for simplicity
          // const SizedBox(height: 6),
          // Row(children: [InkWell(
          //   onTap: () { setState(() => state.tailwind = !state.tailwind); _notify(); },
          //   child: Padding(padding: const EdgeInsets.symmetric(vertical: 4),
          //     child: Row(mainAxisSize: MainAxisSize.min, children: [
          //       SizedBox(width: 22, height: 22, child: Checkbox(
          //         value: state.tailwind,
          //         onChanged: (v) { setState(() => state.tailwind = v ?? false); _notify(); },
          //         materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          //         visualDensity: VisualDensity.compact,
          //       )),
          //       const SizedBox(width: 4),
          //       const Text('순풍', style: TextStyle(fontSize: 14)),
          //     ])))]),
        ],
      ),
    );
  }

  Widget _miniButton(String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Colors.grey.shade200,
          ),
          child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
        ),
      ),
    );
  }

  /// Returns all abilities sorted: pokemon's own abilities first, then the rest
  /// alphabetically by Korean name. Only includes abilities with Korean names.
  List<String> _sortedAbilities(BattlePokemonState state) {
    if (_abilityNameMap.isEmpty) return state.pokemonAbilities;
    // Expand Supreme Overlord → Supreme Overlord 0~5
    final pokemon = <String>[];
    for (final a in state.pokemonAbilities) {
      if (a == 'Supreme Overlord') {
        for (int i = 0; i <= 5; i++) {
          final key = 'Supreme Overlord $i';
          if (_abilityNameMap.containsKey(key)) pokemon.add(key);
        }
      } else if (_abilityNameMap.containsKey(a)) {
        pokemon.add(a);
      }
    }
    final pokemonSet = state.pokemonAbilities.toSet();
    final rest = _abilityNameMap.keys
        .where((a) => !pokemonSet.contains(a) && !pokemon.contains(a))
        .where((a) { final data = _abilityDataMap[a]; return data != null && data.nameKo.runes.any((c) => c >= 0xAC00 && c <= 0xD7A3); })
        .toList();
    rest.sort((a, b) => _abilityKo(a).compareTo(_abilityKo(b)));
    return [...pokemon, ...rest];
  }

  String _speedNatureLabel(Nature n) {
    final ko = n.localizedName;
    final isBuff = n.speedModifier > 1.0;
    final isNerf = n.speedModifier < 1.0;
    if (isBuff) return '$ko (↑${AppStrings.t('stat.speed')})';
    if (isNerf) return '$ko (↓${AppStrings.t('stat.speed')})';
    return ko;
  }

  Widget _natureAutocomplete(BattlePokemonState state, TextEditingController controller, FocusNode focusNode) {
    final initialText = _speedNatureLabel(state.nature);
    if (!focusNode.hasFocus) controller.text = initialText;

    List<Nature> sorted = [...sortedNatures];
    sorted.remove(state.nature);
    sorted.insert(0, state.nature);

    return buildTypeAhead<Nature>(
      controller: controller,
      focusNode: focusNode,
      maxHeight: 250,
      suggestionsCallback: (query) {
        if (query.isEmpty || query == initialText) return sorted;
        final qLower = query.toLowerCase();
        return sorted.where((n) {
          return n.nameKo.toLowerCase().contains(qLower) ||
              n.name.toLowerCase().contains(qLower) ||
              n.nameJa.toLowerCase().contains(qLower);
        }).toList();
      },
      decoration: InputDecoration(labelText: AppStrings.t('label.nature'), isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 4)),
      itemBuilder: (context, nature) {
        final isBuff = nature.speedModifier > 1.0;
        final isNerf = nature.speedModifier < 1.0;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(_speedNatureLabel(nature),
              style: TextStyle(fontSize: 14,
                  color: isBuff ? Colors.red : isNerf ? Colors.blue : null)),
        );
      },
      onSelected: (v) {
        controller.text = _speedNatureLabel(v);
        focusNode.unfocus();
        setState(() => state.nature = v);
        _notify();
      },
      onSubmittedPick: (text) {
        if (text.isEmpty) return null;
        final tLower = text.toLowerCase();
        final match = sorted.where((n) =>
            n.nameKo.toLowerCase().contains(tLower) ||
            n.name.toLowerCase().contains(tLower) ||
            n.nameJa.toLowerCase().contains(tLower)).toList();
        return match.isNotEmpty ? match.first : null;
      },
    );
  }

  Widget _abilityAutocomplete(BattlePokemonState state, TextEditingController controller, FocusNode focusNode) {
    final sorted = _sortedAbilities(state);
    final initialText = state.selectedAbility != null ? _abilityKo(state.selectedAbility!) : '';
    if (!focusNode.hasFocus) controller.text = initialText;

    return KeyedSubtree(
      key: ValueKey('speed_ability_${state.selectedAbility}_${state.pokemonName}'),
      child: buildTypeAhead<String>(
        controller: controller,
        focusNode: focusNode,
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
          controller.text = _abilityKo(v);
          focusNode.unfocus();
          setState(() => state.selectedAbility = v);
          _notify();
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
      ),
    );
  }

  Widget _itemAutocomplete(BattlePokemonState state, TextEditingController controller, FocusNode focusNode) {
    final allKeys = ['', ..._itemNameMap.keys];
    final allItems = state.selectedItem != null
        ? [state.selectedItem!, ...allKeys.where((k) => k != state.selectedItem)]
        : allKeys;
    final initialText = _itemKo(state.selectedItem);
    if (!focusNode.hasFocus) controller.text = initialText;

    return KeyedSubtree(
      key: ValueKey('speed_item_${state.selectedItem}'),
      child: buildTypeAhead<String>(
        controller: controller,
        focusNode: focusNode,
        suggestionsCallback: (text) {
          if (text.isEmpty || text == initialText) return allItems;
          return allItems.where((key) {
            final data = _itemDataMap[key];
            return triLanguageScore(text,
              nameKo: data?.nameKo ?? _itemKo(key.isEmpty ? null : key),
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
            child: Text(_itemKo(key.isEmpty ? null : key), style: const TextStyle(fontSize: 14)),
          );
        },
        onSelected: (v) {
          controller.text = _itemKo(v.isEmpty ? null : v);
          focusNode.unfocus();
          setState(() => state.selectedItem = v.isEmpty ? null : v);
          _notify();
        },
        onSubmittedPick: (text) {
          if (text.isEmpty) return null;
          final scored = <(String, int)>[];
          for (final key in allItems) {
            final ko = _itemKo(key.isEmpty ? null : key);
            final s = koreanMatchScore(text, ko);
            final e = key.isNotEmpty && key.toLowerCase().contains(text.toLowerCase()) ? 20 : 0;
            final best = s > e ? s : e;
            if (best > 0) scored.add((key, best));
          }
          scored.sort((a, b) => b.$2.compareTo(a.$2));
          return scored.isNotEmpty ? scored.first.$1 : null;
        },
      ),
    );
  }
}

/// Numeric input that maintains its own controller so parent rebuilds
/// don't steal focus. External value changes (e.g. button press) update
/// the displayed text without recreating the widget.
class _SpeedNumInput extends StatefulWidget {
  final int value;
  final int min;
  final int max;
  final bool signed;
  final String? label;
  final ValueChanged<int> onChanged;

  const _SpeedNumInput({
    required this.value,
    required this.min,
    required this.max,
    this.signed = false,
    this.label,
    required this.onChanged,
  });

  @override
  State<_SpeedNumInput> createState() => _SpeedNumInputState();
}

class _SpeedNumInputState extends State<_SpeedNumInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Normalize display on blur: strip leading zeros, show current value
      _controller.text = '${widget.value}';
    }
  }

  @override
  void didUpdateWidget(_SpeedNumInput old) {
    super.didUpdateWidget(old);
    // Update text when value changes externally (button press, pokemon change)
    // but not while the user is typing (empty text or focused = user editing)
    if (_focusNode.hasFocus) return;
    final text = _controller.text;
    if (text.isEmpty) return;
    final currentParsed = int.tryParse(text);
    if (currentParsed != widget.value) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.label != null ? null : 32,
      child: TextFormField(
        controller: _controller,
        focusNode: _focusNode,
        keyboardType: widget.signed
            ? TextInputType.text
            : TextInputType.number,
        textInputAction: TextInputAction.next,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.label,
          contentPadding: widget.label != null ? null : const EdgeInsets.symmetric(vertical: 6),
        ),
        onChanged: (text) {
          final parsed = int.tryParse(text);
          if (parsed != null) {
            widget.onChanged(parsed.clamp(widget.min, widget.max));
          } else if (text.isEmpty) {
            widget.onChanged(widget.min);
          }
        },
      ),
    );
  }
}
