import '../../utils/app_strings.dart';

/// Format a single modifier-note key emitted by `damage_calculator`
/// or `OffensiveCalculator` into a user-facing localized string.
///
/// Note keys follow a colon-delimited convention:
///   `ability:<EnglishAbilityName>:<detail>`
///   `item:<kebab-item-id>:<detail>`
///   `move:<key>[:<detail>]`
///   `stab:×<value>`, `crit:×<value>`, `burn:×<value>`, …
///
/// Unknown / unhandled keys fall back to the raw note so we never
/// silently drop a multiplier the calc applied.
///
/// [abilityNameMap] and [itemNameMap] are the per-language lookup
/// tables loaded from assets at app start — the screens that hold
/// them pass them in.
///
/// Shared between the Damage tab modifier list and the 결정력
/// breakdown popup — adding a new note key needs a single edit here.
String formatModifierNote(
  String note, {
  required Map<String, String> abilityNameMap,
  required Map<String, String> itemNameMap,
}) {
  final parts = note.split(':');
  if (parts.length < 2) return note;

  switch (parts[0]) {
    case 'gravity':
      if (parts.length >= 2 && parts[1] == 'disabled') {
        return AppStrings.t('note.gravityDisabled');
      }
      return note;
    case 'ability':
      final name = abilityNameMap[parts[1]] ?? parts[1];
      if (parts.length >= 3) {
        if (parts[2] == 'immune') return '$name ${AppStrings.t('note.abilityImmune')}';
        final detail = parts[2];
        if (detail.startsWith('-')) return '$name$detail';
        return '$name $detail';
      }
      return name;
    case 'disguise':
      final name = abilityNameMap[parts[1]] ?? parts[1];
      return '$name: ${AppStrings.t('note.disguiseDamage')}';
    case 'berryDefBoost':
      final itemName = itemNameMap[parts[1]] ?? parts[1];
      final key = parts[1] == 'kee-berry'
          ? 'note.keeBerryBoost' : 'note.marangaBerryBoost';
      return '$itemName: ${AppStrings.t(key)}';
    case 'abilityDefChange':
      final abilityName = abilityNameMap[parts[1]] ?? parts[1];
      final change = parts.length >= 3 ? parts[2] : '+1';
      final noteKey = switch (change) {
        '+2' => 'note.defUp2',
        '-1' => 'note.defDown1',
        _ => 'note.defUp1',
      };
      return '$abilityName: ${AppStrings.t(noteKey)}';
    case 'item':
      final name = itemNameMap[parts[1]] ?? parts[1];
      if (parts.length >= 3) return '$name ${parts[2]}';
      return name;
    case 'screen':
      const screenKeys = {
        'reflect': 'note.reflect',
        'light_screen': 'note.lightScreen',
        'bypass_crit': 'note.critBypass',
        'bypass_infiltrator': 'note.infiltrator',
      };
      final key = screenKeys[parts[1]];
      return key != null ? AppStrings.t(key) : note;
    case 'move':
      const moveKeys = {
        'knock_off': 'note.knockOff',
        'hex': 'note.hex',
        'venoshock': 'note.venoshock',
        'brine': 'note.brine',
        'collision': 'note.collision',
        'solar_halve': 'note.solarHalve',
        'grav_apple': 'note.gravity',
        'wake_up_slap': 'note.sleep',
        'smelling_salts': 'note.paralysis',
        'barb_barrage': 'note.venoshock',
        'bolt_beak': 'note.boltBeak',
        'payback': 'note.payback',
        'spread': 'note.spread',
        'helpingHand': 'note.helpingHand',
        'powerSpot': 'note.powerSpot',
        'battery': 'note.battery',
        'flowerGift': 'note.flowerGift',
        'plusMinus': 'note.plusMinus',
        'friendGuard': 'note.friendGuard',
        'parental_bond': 'note.parentalBond',
        'charge': 'note.charge',
      };
      final key = parts[1];
      final noteKey = moveKeys[key];
      final label = noteKey != null ? AppStrings.t(noteKey) : key;
      if (parts.length >= 3) return '$label ${parts[2]}';
      return label;
    case 'weather_negate':
      final name = abilityNameMap[parts[1]] ?? parts[1];
      return '$name: ${AppStrings.t('note.weatherNegate')}';
    case 'terrain_negate':
      final name = abilityNameMap[parts[1]] ?? parts[1];
      return '$name: ${AppStrings.t('note.terrainNegate')}';
    case 'moldbreaker':
      return abilityNameMap[parts[1]] ?? parts[1];
    case 'moldbreakerBypass':
      final name = abilityNameMap[parts[1]] ?? parts[1];
      return '$name: ${AppStrings.t('note.moldBreakerBypass')}';
    case 'unaware':
      return abilityNameMap['Unaware'] ?? 'Unaware';
    case 'weather':
      // Three shapes:
      //   `weather:strong_winds` — generic strong-winds label.
      //   `weather:harsh_sun_water` / `weather:heavy_rain_fire` —
      //       water-in-harsh-sun / fire-in-heavy-rain immunity.
      //   `weather:offensive:<enumName>:×<value>` — offensive
      //       weather multiplier from OffensiveCalculator. We map
      //       the enum name to the same Korean weather label our
      //       UI uses elsewhere (쾌청, 비, 강한 햇살, 강한 비).
      if (parts.length >= 4 && parts[1] == 'offensive') {
        final name = AppStrings.t('note.weather.${parts[2]}');
        return '$name ${parts[3]}';
      }
      const weatherKeys = {
        'strong_winds': 'note.strongWinds',
        'harsh_sun_water': 'note.harshSunWater',
        'heavy_rain_fire': 'note.heavyRainFire',
      };
      final wKey = weatherKeys[parts[1]];
      return wKey != null ? AppStrings.t(wKey) : note;
    case 'terrain':
      // `terrain:offensive:<enumName>:×<value>`
      if (parts.length >= 4 && parts[1] == 'offensive') {
        final name = AppStrings.t('note.terrain.${parts[2]}');
        return '$name ${parts[3]}';
      }
      return note;
    case 'ground':
      return AppStrings.t('note.groundImmune');
    case 'type':
      return AppStrings.t('note.typeImmune');
    // ─── New keys from OffensiveCalculator (결정력 breakdown). ─────
    case 'stab':
      // `stab:×n`, `stab:tera:matching:×n`, `stab:stellar:matching:×n`
      if (parts.length >= 3 && parts[1] == 'tera') {
        return '${AppStrings.t('note.teraStab')} ${parts.last}';
      }
      if (parts.length >= 3 && parts[1] == 'stellar') {
        return '${AppStrings.t('note.stellarStab')} ${parts.last}';
      }
      return '${AppStrings.t('note.stab')} ${parts[1]}';
    // `tera:min60` is intentionally NOT a breakdown line — the
    // 60-BP floor is already reflected in the slot's displayed
    // power, so OffensiveCalculator stopped emitting it.
    case 'tera':
      return note;
    case 'crit':
      return '${AppStrings.t('note.critical')} ${parts[1]}';
    case 'burn':
      return '${AppStrings.t('note.burn')} ${parts[1]}';
    case 'aura':
      // `aura:fairy:×1.33`, `aura:dark:×1.33`, `aura:break:×0.75`
      if (parts.length >= 3) {
        final name = AppStrings.t('note.aura.${parts[1]}');
        return '$name ${parts[2]}';
      }
      return note;
    case 'ruin':
      // `ruin:tablets:×0.75`, `ruin:vessel:×0.75`
      if (parts.length >= 3) {
        final name = AppStrings.t('note.ruin.${parts[1]}');
        return '$name ${parts[2]}';
      }
      return note;
    default:
      return note;
  }
}
