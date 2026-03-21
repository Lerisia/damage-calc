import 'dynamax.dart';
import 'gender.dart';
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
  bool finalEvo;
  Gender gender;
  int genderRate;
  PokemonType type1;
  PokemonType? type2;
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
  List<bool> criticals;
  String? selectedItem;
  DynamaxState dynamax;
  TerastalState terastal;
  bool canDynamax;
  bool canGmax;
  Rank rank;
  int hpPercent;
  StatusCondition status;

  // Speed boosts
  bool tailwind;

  // Defensive conditions
  bool reflect;
  bool lightScreen;
  bool auroraVeil;
  bool friendGuard;

  BattlePokemonState({
    this.pokemonName = 'bulbasaur',
    this.pokemonNameKo = '이상해씨',
    this.finalEvo = false,
    this.gender = Gender.unset,
    this.genderRate = 4,
    this.type1 = PokemonType.grass,
    this.type2 = PokemonType.poison,
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
    List<bool>? criticals,
    this.selectedItem,
    this.dynamax = DynamaxState.none,
    this.terastal = const TerastalState(),
    this.canDynamax = true,
    this.canGmax = false,
    this.rank = const Rank(),
    this.hpPercent = 100,
    this.status = StatusCondition.none,
    this.tailwind = false,
    this.reflect = false,
    this.lightScreen = false,
    this.auroraVeil = false,
    this.friendGuard = false,
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
        criticals = criticals ?? [false, false, false, false];

  void reset() {
    pokemonName = 'bulbasaur';
    pokemonNameKo = '이상해씨';
    finalEvo = false;
    gender = Gender.unset;
    genderRate = 4;
    type1 = PokemonType.grass;
    type2 = PokemonType.poison;
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
    criticals = [false, false, false, false];
    selectedItem = null;
    dynamax = DynamaxState.none;
    terastal = const TerastalState();
    canDynamax = true;
    canGmax = false;
    rank = const Rank();
    hpPercent = 100;
    status = StatusCondition.none;
    tailwind = false;
    reflect = false;
    lightScreen = false;
    auroraVeil = false;
    friendGuard = false;
  }
}
