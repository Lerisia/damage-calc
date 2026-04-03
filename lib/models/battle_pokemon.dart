import '../utils/app_strings.dart';
import 'dynamax.dart';
import 'gender.dart';
import 'pokemon.dart';
import 'terastal.dart';
import 'move.dart';
import 'nature.dart';
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
  Nature nature;
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

  BattlePokemonState({
    this.pokemonName = 'bulbasaur',
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
    this.nature = Nature.hardy,
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
    'nature': nature.name,
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
      nature: Nature.values.byName(json['nature'] as String),
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
    );
  }

  void reset() {
    pokemonName = 'bulbasaur';
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
    nature = Nature.hardy;
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
    selectedAbility = firstAbility == 'Supreme Overlord'
        ? 'Supreme Overlord 0'
        : firstAbility == 'Rivalry'
        ? 'Rivalry Same' : firstAbility;
    if (pokemon.requiredItem != null) {
      selectedItem = pokemon.requiredItem;
    }
    if (pokemon.name == 'terapagos-stellar') {
      terastal = TerastalState(active: true, teraType: PokemonType.stellar);
    }
  }
}
