import '../models/battle_pokemon.dart';
import '../models/dynamax.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/weather.dart';
import 'ability_effects.dart';
import 'item_effects.dart';

/// Status condition speed modifier constants.
const double paralysisSpeedModifier = 0.5;

/// Field effect speed modifier constants.
const double tailwindSpeedModifier = 2.0;
/// Calculates the effective speed after all modifiers.
///
/// Modifier application order: ability → item → paralysis → tailwind.
/// Choice Scarf is nullified during Dynamax.
/// Paralysis is negated by Quick Feet.
int calcEffectiveSpeed({
  required int baseSpeed,
  String? ability,
  String? item,
  String? pokemonName,
  StatusCondition status = StatusCondition.none,
  Weather weather = Weather.none,
  Terrain terrain = Terrain.none,
  bool isDynamaxed = false,
  bool tailwind = false,
}) {
  double speed = baseSpeed.toDouble();

  // Ability modifier
  if (ability != null) {
    speed *= getSpeedAbilityModifier(ability,
        weather: weather, terrain: terrain, status: status, heldItem: item);
  }

  // Item modifier (Klutz negates item effects; Choice Scarf nullified during Dynamax)
  if (item != null && ability != 'Klutz') {
    if (!(isDynamaxed && item == 'choice-scarf')) {
      speed *= getSpeedItemEffect(item, pokemonName: pokemonName).speedModifier;
    }
  }

  // Paralysis (Quick Feet negates this)
  if (status == StatusCondition.paralysis && ability != 'Quick Feet') {
    speed *= paralysisSpeedModifier;
  }

  // Tailwind
  if (tailwind) {
    speed *= tailwindSpeedModifier;
  }

  return speed.floor();
}

/// Whether [state] has an always-last item effect (Lagging Tail, Full Incense).
/// Dynamax and Klutz negate this.
bool isAlwaysLast(BattlePokemonState state) {
  return checkAlwaysLast(
    item: state.selectedItem,
    ability: state.selectedAbility,
    isDynamaxed: state.dynamax != DynamaxState.none,
  );
}

/// Parameter-based version for contexts without full [BattlePokemonState].
bool checkAlwaysLast({
  String? item,
  String? ability,
  String? pokemonName,
  bool isDynamaxed = false,
}) {
  if (item == null) return false;
  if (isDynamaxed) return false;
  if (ability == 'Klutz') return false;
  return getSpeedItemEffect(item, pokemonName: pokemonName).alwaysLast;
}
