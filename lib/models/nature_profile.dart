import '../utils/app_strings.dart';
import 'nature.dart';

/// One of the six possible nature slots: the five battle stats that
/// a nature can boost/drop.
enum NatureStat {
  atk,
  def,
  spa,
  spd,
  spe;

  /// Localized short label used in symbolic display fallbacks
  /// ("공↑", "특공↓" etc.).
  String get shortLabel {
    switch (this) {
      case NatureStat.atk:
        return AppStrings.name(nameKo: '공', nameEn: 'Atk', nameJa: '攻');
      case NatureStat.def:
        return AppStrings.name(nameKo: '방', nameEn: 'Def', nameJa: '防');
      case NatureStat.spa:
        return AppStrings.name(nameKo: '특공', nameEn: 'SpA', nameJa: '特攻');
      case NatureStat.spd:
        return AppStrings.name(nameKo: '특방', nameEn: 'SpD', nameJa: '特防');
      case NatureStat.spe:
        return AppStrings.name(nameKo: '스피', nameEn: 'Spe', nameJa: '素早');
    }
  }
}

/// The nature model the app now uses: an independent ↑ slot and ↓
/// slot, each optional. This replaces the original 25-value [Nature]
/// enum so users can express any ↑/↓ combo, including Atk↑ with no
/// ↓, or asymmetric combos. The [Nature] enum still exists purely
/// as a display-name lookup for the 25 valid combinations.
class NatureProfile {
  final NatureStat? up;
  final NatureStat? down;
  const NatureProfile({this.up, this.down});

  static const neutral = NatureProfile();

  NatureProfile copyWith({NatureStat? up, NatureStat? down, bool clearUp = false, bool clearDown = false}) {
    return NatureProfile(
      up: clearUp ? null : (up ?? this.up),
      down: clearDown ? null : (down ?? this.down),
    );
  }

  double _mod(NatureStat s) {
    final isUp = up == s;
    final isDown = down == s;
    if (isUp && !isDown) return 1.1;
    if (isDown && !isUp) return 0.9;
    return 1.0;
  }

  double get attackModifier => _mod(NatureStat.atk);
  double get defenseModifier => _mod(NatureStat.def);
  double get spAttackModifier => _mod(NatureStat.spa);
  double get spDefenseModifier => _mod(NatureStat.spd);
  double get speedModifier => _mod(NatureStat.spe);

  /// Display name for the profile. Falls back to a symbolic
  /// representation for asymmetric combos that don't correspond to
  /// any of the 25 canonical natures.
  String get localizedName {
    final known = _matchingNature();
    if (known != null) return known.localizedName;
    // No canonical match — build symbolic text. Up/down may be null.
    final parts = <String>[];
    if (up != null) parts.add('${up!.shortLabel}↑');
    if (down != null) parts.add('${down!.shortLabel}↓');
    if (parts.isEmpty) return Nature.hardy.localizedName;
    return parts.join(' ');
  }

  /// Map to one of the 25 canonical [Nature] enums when possible.
  /// - Neutral (no ↑, no ↓) → Hardy.
  /// - Same-stat ↑↓ → the corresponding neutral (Hardy/Docile/
  ///   Serious/Bashful/Quirky).
  /// - Distinct cross-stat pairs → their named nature.
  /// - Asymmetric (only ↑ or only ↓) → null.
  Nature? _matchingNature() {
    if (up == null && down == null) return Nature.hardy;
    if (up == null || down == null) return null;
    if (up == down) {
      switch (up!) {
        case NatureStat.atk: return Nature.hardy;
        case NatureStat.def: return Nature.docile;
        case NatureStat.spe: return Nature.serious;
        case NatureStat.spa: return Nature.bashful;
        case NatureStat.spd: return Nature.quirky;
      }
    }
    return _pairTable[(up!, down!)];
  }

  static const Map<(NatureStat, NatureStat), Nature> _pairTable = {
    (NatureStat.atk, NatureStat.def): Nature.lonely,
    (NatureStat.atk, NatureStat.spe): Nature.brave,
    (NatureStat.atk, NatureStat.spa): Nature.adamant,
    (NatureStat.atk, NatureStat.spd): Nature.naughty,
    (NatureStat.def, NatureStat.atk): Nature.bold,
    (NatureStat.def, NatureStat.spe): Nature.relaxed,
    (NatureStat.def, NatureStat.spa): Nature.impish,
    (NatureStat.def, NatureStat.spd): Nature.lax,
    (NatureStat.spe, NatureStat.atk): Nature.timid,
    (NatureStat.spe, NatureStat.def): Nature.hasty,
    (NatureStat.spe, NatureStat.spa): Nature.jolly,
    (NatureStat.spe, NatureStat.spd): Nature.naive,
    (NatureStat.spa, NatureStat.atk): Nature.modest,
    (NatureStat.spa, NatureStat.def): Nature.mild,
    (NatureStat.spa, NatureStat.spe): Nature.quiet,
    (NatureStat.spa, NatureStat.spd): Nature.rash,
    (NatureStat.spd, NatureStat.atk): Nature.calm,
    (NatureStat.spd, NatureStat.def): Nature.gentle,
    (NatureStat.spd, NatureStat.spe): Nature.sassy,
    (NatureStat.spd, NatureStat.spa): Nature.careful,
  };

  /// Invert the mapping in [_pairTable] + the 5 neutrals so an old
  /// save's nature name ("adamant" etc.) can be hydrated into a
  /// [NatureProfile] with the right ↑/↓ slots.
  factory NatureProfile.fromNature(Nature n) {
    const reverse = <Nature, (NatureStat?, NatureStat?)>{
      Nature.hardy: (null, null),
      Nature.docile: (NatureStat.def, NatureStat.def),
      Nature.serious: (NatureStat.spe, NatureStat.spe),
      Nature.bashful: (NatureStat.spa, NatureStat.spa),
      Nature.quirky: (NatureStat.spd, NatureStat.spd),
      Nature.lonely: (NatureStat.atk, NatureStat.def),
      Nature.brave: (NatureStat.atk, NatureStat.spe),
      Nature.adamant: (NatureStat.atk, NatureStat.spa),
      Nature.naughty: (NatureStat.atk, NatureStat.spd),
      Nature.bold: (NatureStat.def, NatureStat.atk),
      Nature.relaxed: (NatureStat.def, NatureStat.spe),
      Nature.impish: (NatureStat.def, NatureStat.spa),
      Nature.lax: (NatureStat.def, NatureStat.spd),
      Nature.timid: (NatureStat.spe, NatureStat.atk),
      Nature.hasty: (NatureStat.spe, NatureStat.def),
      Nature.jolly: (NatureStat.spe, NatureStat.spa),
      Nature.naive: (NatureStat.spe, NatureStat.spd),
      Nature.modest: (NatureStat.spa, NatureStat.atk),
      Nature.mild: (NatureStat.spa, NatureStat.def),
      Nature.quiet: (NatureStat.spa, NatureStat.spe),
      Nature.rash: (NatureStat.spa, NatureStat.spd),
      Nature.calm: (NatureStat.spd, NatureStat.atk),
      Nature.gentle: (NatureStat.spd, NatureStat.def),
      Nature.sassy: (NatureStat.spd, NatureStat.spe),
      Nature.careful: (NatureStat.spd, NatureStat.spa),
    };
    final pair = reverse[n]!;
    return NatureProfile(up: pair.$1, down: pair.$2);
  }

  Map<String, dynamic> toJson() => {
        if (up != null) 'up': up!.name,
        if (down != null) 'down': down!.name,
      };

  /// Reads either the new `{up, down}` format or the old `"adamant"`
  /// string format (via [fromNature]) so existing saved samples keep
  /// working untouched.
  static NatureProfile fromAny(dynamic raw) {
    if (raw == null) return const NatureProfile();
    if (raw is String) {
      try {
        return NatureProfile.fromNature(Nature.values.byName(raw));
      } catch (_) {
        return const NatureProfile();
      }
    }
    if (raw is Map) {
      final upRaw = raw['up'] as String?;
      final downRaw = raw['down'] as String?;
      NatureStat? parse(String? v) {
        if (v == null) return null;
        try {
          return NatureStat.values.byName(v);
        } catch (_) {
          return null;
        }
      }
      return NatureProfile(up: parse(upRaw), down: parse(downRaw));
    }
    return const NatureProfile();
  }

  @override
  bool operator ==(Object other) =>
      other is NatureProfile && other.up == up && other.down == down;

  @override
  int get hashCode => Object.hash(up, down);
}
