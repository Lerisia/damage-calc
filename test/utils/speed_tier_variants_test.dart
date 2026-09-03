import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/champions_usage.dart';
import 'package:damage_calc/data/pokedex.dart';
import 'package:damage_calc/models/pokemon.dart';
import 'package:damage_calc/utils/champions_format_controller.dart';
import 'package:damage_calc/utils/speed_tier_variants.dart';

/// Realized-speed variants for the Champions speed tier sheet.
///
/// Every Pokémon lands on three speeds — no investment, full SP, and
/// full SP with a boosting nature. Pokémon that actually run a Choice
/// Scarf (40%+ adoption in the format being viewed) add a Scarf line
/// for each of the two invested spreads.
void main() {
  late final Map<String, Pokemon> byName;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dex = await loadPokedex();
    byName = {for (final p in dex) p.name: p};
    await loadChampionsUsage(format: ChampionsFormat.singles);
    await loadChampionsUsage(format: ChampionsFormat.doubles);
  });

  List<SpeedVariant> variantsOf(String species,
          {ChampionsFormat format = ChampionsFormat.singles}) =>
      speedVariantsFor(byName[species]!, format: format);

  test('a Pokémon without a Scarf gets the three base tiers', () {
    final v = variantsOf('Blissey');
    expect(v.map((e) => e.kind), [
      SpeedVariantKind.neutral,
      SpeedVariantKind.invested,
      SpeedVariantKind.boosted,
    ]);
  });

  test('speeds rise across the three tiers', () {
    final v = variantsOf('Blissey');
    expect(v[0].speed, lessThan(v[1].speed));
    expect(v[1].speed, lessThan(v[2].speed));
  });

  test('uses the real Lv50 formula, not an approximation', () {
    // Garchomp, base 102 speed, Lv50, IV 31.
    //   0 SP  neutral  floor((2*102+31+0)*50/100)+5   = 122
    //   32 SP neutral  floor((2*102+31+63)*50/100)+5  = 154
    //   32 SP +nature  floor(154 * 1.1)               = 169
    final v = variantsOf('Garchomp');
    expect(v[0].speed, equals(122));
    expect(v[1].speed, equals(154));
    expect(v[2].speed, equals(169));
  });

  group('Choice Scarf lines', () {
    /// The first Champions Pokémon that actually runs a Scarf.
    Pokemon scarfUser(ChampionsFormat f) => byName.values.firstWhere((p) =>
        speedVariantsFor(p, format: f)
            .any((v) => v.kind == SpeedVariantKind.scarfBoosted));

    test('add one line per invested spread', () {
      final v = speedVariantsFor(scarfUser(ChampionsFormat.singles),
          format: ChampionsFormat.singles);
      expect(v.map((e) => e.kind), [
        SpeedVariantKind.neutral,
        SpeedVariantKind.invested,
        SpeedVariantKind.boosted,
        SpeedVariantKind.scarfInvested,
        SpeedVariantKind.scarfBoosted,
      ]);
    });

    test('each is 1.5x its unscarfed spread', () {
      final v = speedVariantsFor(scarfUser(ChampionsFormat.singles),
          format: ChampionsFormat.singles);
      int of(SpeedVariantKind k) =>
          v.firstWhere((e) => e.kind == k).speed;
      expect(of(SpeedVariantKind.scarfInvested),
          equals((of(SpeedVariantKind.invested) * 1.5).floor()));
      expect(of(SpeedVariantKind.scarfBoosted),
          equals((of(SpeedVariantKind.boosted) * 1.5).floor()));
    });

    test('follow the format being viewed', () {
      // A Pokémon can run a Scarf in one format and not the other; the
      // sheet must not carry a singles habit into doubles.
      bool hasScarf(String n, ChampionsFormat f) => speedVariantsFor(
            byName[n]!,
            format: f,
          ).any((v) => v.kind == SpeedVariantKind.scarfBoosted);

      final differing = byName.values
          .map((p) => p.name)
          .where((n) =>
              championsUsageFor(n, format: ChampionsFormat.singles) != null &&
              championsUsageFor(n, format: ChampionsFormat.doubles) != null)
          .where((n) =>
              hasScarf(n, ChampionsFormat.singles) !=
              hasScarf(n, ChampionsFormat.doubles))
          .toList();
      expect(differing, isNotEmpty,
          reason: 'the two formats should not agree on every Scarf user');
    });

    test('require real adoption, not merely a listed item', () {
      // The bar is the adoption rate, not the item's rank: Scarf is
      // listed on half the roster at a median under 5%.
      for (final p in byName.values) {
        final v = speedVariantsFor(p, format: ChampionsFormat.singles);
        if (!v.any((e) => e.kind == SpeedVariantKind.scarfBoosted)) continue;
        final usage =
            championsUsageFor(p.name, format: ChampionsFormat.singles);
        final scarf =
            usage!.items.firstWhere((i) => i.name == 'choice-scarf');
        expect(scarf.pct, isNotNull, reason: p.name);
        expect(scarf.pct!, greaterThanOrEqualTo(40.0), reason: p.name);
      }
    });

    test('stay a short list — the tail is excluded', () {
      final withScarf = byName.values
          .where((p) => speedVariantsFor(p, format: ChampionsFormat.singles)
              .any((v) => v.kind == SpeedVariantKind.scarfBoosted))
          .length;
      expect(withScarf, lessThan(20),
          reason: 'a loose cut let 113 species through');
      expect(withScarf, greaterThan(3),
          reason: 'the obvious Scarf users must survive');
    });
  });

  test('a Pokémon with no usage entry still gets its three tiers', () {
    final unlisted = byName.values.firstWhere(
      (p) => championsUsageFor(p.name, format: ChampionsFormat.singles) == null,
    );
    expect(speedVariantsFor(unlisted, format: ChampionsFormat.singles).length,
        equals(3));
  });
}
