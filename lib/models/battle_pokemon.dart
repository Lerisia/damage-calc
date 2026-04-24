import '../data/champions_usage.dart';
import '../data/movedex.dart';
import '../data/pokedex.dart';
import '../utils/app_strings.dart';
import '../utils/stacking_moves.dart';
import 'dynamax.dart';
import 'gender.dart';
import 'nature.dart';
import 'pokemon.dart';
import 'terastal.dart';
import 'move.dart';
import 'nature_profile.dart';
import 'rank.dart';
import 'stats.dart';
import 'status.dart';
import 'type.dart';

/// Holds all configuration state for one side of a battle (attacker or defender)
class BattlePokemonState {
  String pokemonName;
  String pokemonNameKo;
  String pokemonNameJa;
  String? pokemonNameEn;
  int dexNumber;

  String get localizedPokemonName => AppStrings.name(
    nameKo: pokemonNameKo, nameEn: pokemonNameEn, nameJa: pokemonNameJa, name: pokemonName);

  bool finalEvo;
  Gender gender;
  int genderRate;
  PokemonType type1;
  PokemonType? type2;
  double weight; // kg
  Stats baseStats;
  List<String> pokemonAbilities;
  String? selectedAbility;
  int level;
  NatureProfile nature;
  Stats iv;
  Stats ev;
  List<Move?> moves;
  List<PokemonType?> typeOverrides;
  List<MoveCategory?> categoryOverrides;
  List<int?> powerOverrides;
  List<int?> hitOverrides;
  List<bool> criticals;
  List<bool> zMoves;
  String? selectedItem;
  DynamaxState dynamax;
  TerastalState terastal;
  bool canDynamax;
  bool canGmax;
  bool isMega;
  Rank rank;
  int hpPercent;
  StatusCondition status;

  // Self-applied battle conditions
  bool charge; // Charge: next Electric move deals 2x damage
  bool tailwind;
  // Defensive conditions
  bool reflect;
  bool lightScreen;
  bool auroraVeil;
  // ===== Doubles-only scenario flags (ignored in Singles) =====
  /// Attacker's spread move is hitting 2 targets → 0.75× per-target reduction.
  bool spreadTargets;
  /// Ally used Helping Hand this turn → attacker's moves × 1.5.
  bool helpingHand;
  /// Ally has Power Spot → attacker's moves × 1.3.
  bool allyPowerSpot;
  /// Ally has Battery → attacker's special moves × 1.3.
  bool allyBattery;
  /// Ally has Friend Guard → attacker takes 0.75× incoming (defender side).
  bool allyFriendGuard;
  /// Ally has Flower Gift → in Sun, attacker Attack × 1.5, ally SpDef × 1.5.
  bool allyFlowerGift;
  /// Ally has Plus or Minus → attacker with Plus/Minus has SpA × 1.5.
  bool allyPlusMinus;

  BattlePokemonState({
    this.pokemonName = 'Bulbasaur',
    this.pokemonNameKo = '이상해씨',
    this.pokemonNameJa = 'フシギダネ',
    this.pokemonNameEn,
    this.dexNumber = 1,
    this.finalEvo = false,
    this.gender = Gender.unset,
    this.genderRate = 4,
    this.type1 = PokemonType.grass,
    this.type2 = PokemonType.poison,
    this.weight = 6.9,
    Stats? baseStats,
    List<String>? pokemonAbilities,
    this.selectedAbility = 'Overgrow',
    this.level = 50,
    this.nature = NatureProfile.neutral,
    Stats? iv,
    Stats? ev,
    List<Move?>? moves,
    List<PokemonType?>? typeOverrides,
    List<MoveCategory?>? categoryOverrides,
    List<int?>? powerOverrides,
    List<int?>? hitOverrides,
    List<bool>? criticals,
    List<bool>? zMoves,
    this.selectedItem,
    this.dynamax = DynamaxState.none,
    this.terastal = const TerastalState(),
    this.canDynamax = true,
    this.canGmax = false,
    this.isMega = false,
    this.rank = const Rank(),
    this.hpPercent = 100,
    this.status = StatusCondition.none,
    this.charge = false,
    this.tailwind = false,
    this.reflect = false,
    this.lightScreen = false,
    this.auroraVeil = false,
    this.spreadTargets = false,
    this.helpingHand = false,
    this.allyPowerSpot = false,
    this.allyBattery = false,
    this.allyFriendGuard = false,
    this.allyFlowerGift = false,
    this.allyPlusMinus = false,
  })  : baseStats = baseStats ?? const Stats(
            hp: 45, attack: 49, defense: 49,
            spAttack: 65, spDefense: 65, speed: 45),
        pokemonAbilities = pokemonAbilities ?? ['Overgrow', 'Chlorophyll'],
        iv = iv ?? const Stats(
            hp: 31, attack: 31, defense: 31,
            spAttack: 31, spDefense: 31, speed: 31),
        ev = ev ?? const Stats(
            hp: 0, attack: 0, defense: 0,
            spAttack: 0, spDefense: 0, speed: 0),
        moves = moves ?? [null, null, null, null],
        typeOverrides = typeOverrides ?? [null, null, null, null],
        categoryOverrides = categoryOverrides ?? [null, null, null, null],
        powerOverrides = powerOverrides ?? [null, null, null, null],
        hitOverrides = hitOverrides ?? [null, null, null, null],
        criticals = criticals ?? [false, false, false, false],
        zMoves = zMoves ?? [false, false, false, false];

  Map<String, dynamic> toJson() => {
    'pokemonName': pokemonName,
    'pokemonNameKo': pokemonNameKo,
    'pokemonNameJa': pokemonNameJa,
    'pokemonNameEn': pokemonNameEn,
    'dexNumber': dexNumber,
    'finalEvo': finalEvo,
    'gender': gender.name,
    'genderRate': genderRate,
    'type1': type1.name,
    'type2': type2?.name,
    'weight': weight,
    'baseStats': baseStats.toJson(),
    'pokemonAbilities': pokemonAbilities,
    'selectedAbility': selectedAbility,
    'level': level,
    'nature': nature.toJson(),
    'iv': iv.toJson(),
    'ev': ev.toJson(),
    'moves': moves.map((m) => m?.toJson()).toList(),
    'typeOverrides': typeOverrides.map((t) => t?.name).toList(),
    'categoryOverrides': categoryOverrides.map((c) => c?.name).toList(),
    'powerOverrides': powerOverrides,
    'hitOverrides': hitOverrides,
    'criticals': criticals,
    'zMoves': zMoves,
    'selectedItem': selectedItem,
    'dynamax': dynamax.name,
    'terastal': terastal.toJson(),
    'canDynamax': canDynamax,
    'canGmax': canGmax,
    'isMega': isMega,
    'rank': rank.toJson(),
    'hpPercent': hpPercent,
    'status': status.name,
    'charge': charge,
    'tailwind': tailwind,
    'reflect': reflect,
    'lightScreen': lightScreen,
    'auroraVeil': auroraVeil,
    'spreadTargets': spreadTargets,
    'helpingHand': helpingHand,
    'allyPowerSpot': allyPowerSpot,
    'allyBattery': allyBattery,
    'allyFriendGuard': allyFriendGuard,
    'allyFlowerGift': allyFlowerGift,
    'allyPlusMinus': allyPlusMinus,
  };

  factory BattlePokemonState.fromJson(Map<String, dynamic> json) {
    return BattlePokemonState(
      pokemonName: json['pokemonName'] as String,
      pokemonNameKo: json['pokemonNameKo'] as String,
      pokemonNameJa: json['pokemonNameJa'] as String? ?? '',
      pokemonNameEn: json['pokemonNameEn'] as String?,
      dexNumber: json['dexNumber'] as int? ?? 1,
      finalEvo: json['finalEvo'] as bool? ?? false,
      gender: Gender.values.byName(json['gender'] as String),
      genderRate: json['genderRate'] as int? ?? 4,
      type1: PokemonType.values.byName(json['type1'] as String),
      type2: json['type2'] != null
          ? PokemonType.values.byName(json['type2'] as String)
          : null,
      weight: (json['weight'] as num).toDouble(),
      baseStats: Stats.fromJson(json['baseStats'] as Map<String, dynamic>),
      pokemonAbilities: List<String>.from(json['pokemonAbilities'] as List),
      selectedAbility: json['selectedAbility'] as String?,
      level: json['level'] as int? ?? 50,
      nature: NatureProfile.fromAny(json['nature']),
      iv: Stats.fromJson(json['iv'] as Map<String, dynamic>),
      ev: Stats.fromJson(json['ev'] as Map<String, dynamic>),
      moves: (json['moves'] as List).map((m) =>
          m != null ? Move.fromJson(m as Map<String, dynamic>) : null).toList(),
      typeOverrides: (json['typeOverrides'] as List).map((t) =>
          t != null ? PokemonType.values.byName(t as String) : null).toList(),
      categoryOverrides: (json['categoryOverrides'] as List).map((c) =>
          c != null ? MoveCategory.values.byName(c as String) : null).toList(),
      powerOverrides: List<int?>.from(json['powerOverrides'] as List),
      hitOverrides: json['hitOverrides'] != null
          ? List<int?>.from(json['hitOverrides'] as List)
          : null,
      criticals: List<bool>.from(json['criticals'] as List),
      zMoves: json['zMoves'] != null
          ? List<bool>.from(json['zMoves'] as List)
          : null,
      selectedItem: json['selectedItem'] as String?,
      dynamax: DynamaxState.values.byName(json['dynamax'] as String),
      terastal: TerastalState.fromJson(json['terastal'] as Map<String, dynamic>),
      canDynamax: json['canDynamax'] as bool? ?? true,
      canGmax: json['canGmax'] as bool? ?? false,
      isMega: json['isMega'] as bool? ?? false,
      rank: Rank.fromJson(json['rank'] as Map<String, dynamic>),
      hpPercent: json['hpPercent'] as int? ?? 100,
      status: StatusCondition.values.byName(json['status'] as String),
      charge: json['charge'] as bool? ?? false,
      tailwind: json['tailwind'] as bool? ?? false,
      reflect: json['reflect'] as bool? ?? false,
      lightScreen: json['lightScreen'] as bool? ?? false,
      auroraVeil: json['auroraVeil'] as bool? ?? false,
      spreadTargets: json['spreadTargets'] as bool? ?? false,
      helpingHand: json['helpingHand'] as bool? ?? false,
      allyPowerSpot: json['allyPowerSpot'] as bool? ?? false,
      allyBattery: json['allyBattery'] as bool? ?? false,
      allyFriendGuard: json['allyFriendGuard'] as bool? ?? false,
      allyFlowerGift: json['allyFlowerGift'] as bool? ?? false,
      allyPlusMinus: json['allyPlusMinus'] as bool? ?? false,
    );
  }

  void reset() {
    pokemonName = 'Bulbasaur';
    pokemonNameKo = '이상해씨';
    pokemonNameJa = 'フシギダネ';
    pokemonNameEn = null;
    dexNumber = 1;
    finalEvo = false;
    gender = Gender.unset;
    genderRate = 4;
    type1 = PokemonType.grass;
    type2 = PokemonType.poison;
    weight = 6.9;
    baseStats = const Stats(
        hp: 45, attack: 49, defense: 49,
        spAttack: 65, spDefense: 65, speed: 45);
    pokemonAbilities = ['Overgrow', 'Chlorophyll'];
    selectedAbility = 'Overgrow';
    level = 50;
    nature = NatureProfile.neutral;
    iv = const Stats(
        hp: 31, attack: 31, defense: 31,
        spAttack: 31, spDefense: 31, speed: 31);
    ev = const Stats(
        hp: 0, attack: 0, defense: 0,
        spAttack: 0, spDefense: 0, speed: 0);
    moves = [null, null, null, null];
    typeOverrides = [null, null, null, null];
    categoryOverrides = [null, null, null, null];
    powerOverrides = [null, null, null, null];
    hitOverrides = [null, null, null, null];
    criticals = [false, false, false, false];
    zMoves = [false, false, false, false];
    selectedItem = null;
    dynamax = DynamaxState.none;
    terastal = const TerastalState();
    canDynamax = true;
    canGmax = false;
    isMega = false;
    rank = const Rank();
    hpPercent = 100;
    status = StatusCondition.none;
    charge = false;
    tailwind = false;
    reflect = false;
    lightScreen = false;
    auroraVeil = false;
    spreadTargets = false;
    helpingHand = false;
    allyPowerSpot = false;
    allyBattery = false;
    allyFriendGuard = false;
    allyFlowerGift = false;
    allyPlusMinus = false;
  }

  /// Apply a Pokemon species selection, updating all relevant fields.
  void applyPokemon(Pokemon pokemon) {
    pokemonName = pokemon.name;
    pokemonNameKo = pokemon.nameKo;
    pokemonNameJa = pokemon.nameJa;
    pokemonNameEn = pokemon.nameEn;
    dexNumber = pokemon.dexNumber;
    finalEvo = pokemon.finalEvo;
    canDynamax = pokemon.canDynamax;
    canGmax = pokemon.canGmax;
    isMega = pokemon.isMega;
    dynamax = DynamaxState.none;
    terastal = const TerastalState();
    if (isMega) {
      zMoves = [false, false, false, false];
    }
    genderRate = pokemon.genderRate;
    if (pokemon.genderRate == -1) {
      gender = Gender.genderless;
    } else if (pokemon.genderRate == 0) {
      gender = Gender.male;
    } else if (pokemon.genderRate == 8) {
      gender = Gender.female;
    } else {
      gender = Gender.unset;
    }
    type1 = pokemon.type1;
    type2 = pokemon.type2;
    weight = pokemon.weight;
    baseStats = pokemon.baseStats;
    pokemonAbilities = pokemon.abilities;
    final firstAbility = pokemon.abilities.isNotEmpty ? pokemon.abilities.first : null;
    selectedAbility = expandAbilityKey(firstAbility);
    if (pokemon.requiredItem != null) {
      selectedItem = pokemon.requiredItem;
    } else {
      selectedItem = null;
    }
    if (pokemon.name == 'terapagos-stellar') {
      terastal = const TerastalState(active: true, teraType: PokemonType.stellar);
    }

    _applyChampionsUsageDefaults(pokemon);
  }

  /// Hydrate the freshly-loaded species with curator-chosen defaults
  /// (ability/item/nature/moves) pulled from the Champions Singles
  /// usage snapshot. Silently no-ops when the species is uncurated or
  /// the cache hasn't loaded yet — in either case the earlier
  /// [applyPokemon] body has already set sane fallbacks.
  void _applyChampionsUsageDefaults(Pokemon pokemon) {
    final usage = championsUsageFor(pokemon.name);
    if (usage == null) {
      // Uncurated → wipe the moveset so we don't carry stale slots
      // over from the previous species.
      _resetMoveSlots();
      return;
    }

    // Ability: only override if the curated top pick is actually one
    // the species can legally run (protects against data drift).
    if (usage.abilities.isNotEmpty) {
      final curated = usage.abilities.first.name;
      if (pokemon.abilities.contains(curated)) {
        selectedAbility = expandAbilityKey(curated);
      }
    }

    // Item: mega forms already pinned their stone above; for base
    // forms, prefer the top non-megastone pick so we don't auto-
    // transform the species the moment it's loaded.
    if (pokemon.requiredItem == null && usage.items.isNotEmpty) {
      final stones = megaStoneItemIds();
      for (final row in usage.items) {
        if (!stones.contains(row.name)) {
          selectedItem = row.name;
          break;
        }
      }
    }

    if (usage.natures.isNotEmpty) {
      final natName = usage.natures.first.name.toLowerCase();
      try {
        nature = NatureProfile.fromNature(Nature.values.byName(natName));
      } catch (_) {
        // Unknown / non-canonical name — keep the current nature.
      }
    }

    _resetMoveSlots();
    final defaults = usage.defaultMoves;
    for (int i = 0; i < defaults.length && i < 4; i++) {
      final m = findMoveByName(defaults[i].name);
      moves[i] = m;
      // Stacking-power moves (Last Respects, Rage Fist) need a
      // powerOverride pre-set to match the ×N chip's default tier,
      // otherwise the UI shows e.g. ×3 while the calc uses base 50.
      if (m != null && isStackingPower(m)) {
        powerOverrides[i] = stackingPower(m, stackingDefaultTier(m));
      }
    }
  }

  void _resetMoveSlots() {
    moves = [null, null, null, null];
    typeOverrides = [null, null, null, null];
    categoryOverrides = [null, null, null, null];
    powerOverrides = [null, null, null, null];
    hitOverrides = [null, null, null, null];
    criticals = [false, false, false, false];
    zMoves = [false, false, false, false];
  }

  /// Map an ability group key (as stored in `pokemon.abilities`) to the
  /// expanded variant the ability picker / damage calc expects.
  static String? expandAbilityKey(String? key) {
    if (key == null) return null;
    if (key == 'Supreme Overlord') return 'Supreme Overlord 0';
    if (key == 'Rivalry') return 'Rivalry Same';
    return key;
  }
}
