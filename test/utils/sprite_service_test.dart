import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/sprite_service.dart';

void main() {
  group('spriteKeyFor — plain species', () {
    test('simple name', () {
      expect(spriteKeyFor('Pikachu'), 'pikachu');
    });

    test('punctuation stripped (no separators kept)', () {
      // Showdown's convention drops apostrophes / hyphens / dots
      // entirely on plain species names.
      expect(spriteKeyFor("Farfetch'd"), 'farfetchd');
      expect(spriteKeyFor('Mr. Mime'), 'mrmime');
      expect(spriteKeyFor('Ho-Oh'), 'hooh');
      expect(spriteKeyFor('Porygon-Z'), 'porygonz');
    });

    test('diacritics normalised', () {
      // Flabébé → flabebe (each é → e), not "flabb".
      expect(spriteKeyFor('Flabébé'), 'flabebe');
    });

    test('gender symbols map to letter, no collision', () {
      expect(spriteKeyFor('Nidoran♀'), 'nidoranf');
      expect(spriteKeyFor('Nidoran♂'), 'nidoranm');
      expect(spriteKeyFor('Nidoran♀') == spriteKeyFor('Nidoran♂'), isFalse);
    });

    test('whitespace collapsed', () {
      expect(spriteKeyFor('  Mr.  Mime  '), 'mrmime');
    });
  });

  group('spriteKeyFor — Mega and Primal forms', () {
    test('Mega <Species>', () {
      expect(spriteKeyFor('Mega Abomasnow'), 'abomasnow-mega');
      expect(spriteKeyFor('Mega Garchomp'), 'garchomp-mega');
    });

    test('Mega <Species> X/Y — qualifier concatenated, no separator', () {
      expect(spriteKeyFor('Mega Charizard X'), 'charizard-megax');
      expect(spriteKeyFor('Mega Charizard Y'), 'charizard-megay');
      expect(spriteKeyFor('Mega Mewtwo X'), 'mewtwo-megax');
      expect(spriteKeyFor('Mega Mewtwo Y'), 'mewtwo-megay');
    });

    test('Primal <Species>', () {
      expect(spriteKeyFor('Primal Groudon'), 'groudon-primal');
      expect(spriteKeyFor('Primal Kyogre'), 'kyogre-primal');
    });
  });

  group('spriteKeyFor — regional forms', () {
    test('Alolan / Hisuian / Galarian / Paldean — form word last', () {
      expect(spriteKeyFor('Alolan Raichu'), 'raichu-alola');
      expect(spriteKeyFor('Hisuian Decidueye'), 'decidueye-hisui');
      expect(spriteKeyFor('Galarian Slowking'), 'slowking-galar');
      expect(spriteKeyFor('Paldean Tauros'), 'tauros-paldea');
    });

    test('nested regional + forme — "Galarian Darmanitan (Zen Mode)"', () {
      expect(spriteKeyFor('Galarian Darmanitan (Zen Mode)'),
          'darmanitan-galarzen');
    });
  });

  group('spriteKeyFor — Rotom, Calyrex, Necrozma, Kyurem', () {
    test('Rotom appliance forms', () {
      expect(spriteKeyFor('Heat Rotom'), 'rotom-heat');
      expect(spriteKeyFor('Wash Rotom'), 'rotom-wash');
      expect(spriteKeyFor('Frost Rotom'), 'rotom-frost');
      expect(spriteKeyFor('Fan Rotom'), 'rotom-fan');
      expect(spriteKeyFor('Mow Rotom'), 'rotom-mow');
    });

    test('Calyrex steeds', () {
      expect(spriteKeyFor('Ice Rider Calyrex'), 'calyrex-ice');
      expect(spriteKeyFor('Shadow Rider Calyrex'), 'calyrex-shadow');
    });

    test('Necrozma fusions + Ultra', () {
      expect(spriteKeyFor('Dawn Wings Necrozma'), 'necrozma-dawnwings');
      expect(spriteKeyFor('Dusk Mane Necrozma'), 'necrozma-duskmane');
      expect(spriteKeyFor('Ultra Necrozma'), 'necrozma-ultra');
    });

    test('Black / White Kyurem', () {
      expect(spriteKeyFor('Black Kyurem'), 'kyurem-black');
      expect(spriteKeyFor('White Kyurem'), 'kyurem-white');
    });

    test('Hoopa Unbound', () {
      expect(spriteKeyFor('Hoopa Unbound'), 'hoopa-unbound');
    });
  });

  group('spriteKeyFor — parenthesised formes', () {
    test('single forme word — drops noise suffixes (Forme/Mode/etc.)', () {
      expect(spriteKeyFor('Deoxys (Attack Forme)'), 'deoxys-attack');
      expect(spriteKeyFor('Tornadus (Therian Forme)'), 'tornadus-therian');
      expect(spriteKeyFor('Darmanitan (Zen Mode)'), 'darmanitan-zen');
      expect(spriteKeyFor('Shaymin (Sky Forme)'), 'shaymin-sky');
      expect(spriteKeyFor('Aegislash (Blade Forme)'), 'aegislash-blade');
      expect(spriteKeyFor('Lycanroc (Dusk Form)'), 'lycanroc-dusk');
      expect(spriteKeyFor('Palafin (Hero Form)'), 'palafin-hero');
    });

    test('multi-word forme — concatenated without separator', () {
      expect(spriteKeyFor('Toxtricity (Low Key Form)'), 'toxtricity-lowkey');
      expect(spriteKeyFor('Urshifu (Rapid Strike Style)'),
          'urshifu-rapidstrike');
      expect(spriteKeyFor('Ursaluna (Blood Moon)'), 'ursaluna-bloodmoon');
    });

    test('gender parens — Female → -f, Male → bare', () {
      expect(spriteKeyFor('Indeedee (Female)'), 'indeedee-f');
      expect(spriteKeyFor('Meowstic (Female)'), 'meowstic-f');
      // Male is the default; Showdown serves it under the bare species
      // slug without a -m suffix.
    });

    test('forme word collapses internal spaces', () {
      expect(spriteKeyFor('Pumpkaboo (Large Size)'), 'pumpkaboo-large');
      expect(spriteKeyFor('Oricorio (Pom-Pom Style)'), 'oricorio-pompom');
      expect(spriteKeyFor('Oricorio (Sensu Style)'), 'oricorio-sensu');
    });

    test('overrides: Crowned forms drop the weapon word', () {
      expect(spriteKeyFor('Zacian (Crowned Sword)'), 'zacian-crowned');
      expect(spriteKeyFor('Zamazenta (Crowned Shield)'), 'zamazenta-crowned');
    });

    test('overrides: Minior collapses to default sprite', () {
      expect(spriteKeyFor('Minior (Core Form)'), 'minior');
    });
  });

  group('baseSpeciesName — form → base species fallback', () {
    test('Mega forms strip the prefix word', () {
      expect(baseSpeciesName('Mega Baxcalibur'), 'Baxcalibur');
      expect(baseSpeciesName('Mega Garchomp'), 'Garchomp');
      expect(baseSpeciesName('Mega Charizard X'), 'Charizard');
      expect(baseSpeciesName('Mega Mewtwo Y'), 'Mewtwo');
    });

    test('Champions-original Z-suffix Megas strip both ends', () {
      expect(baseSpeciesName('Mega Absol Z'), 'Absol');
      expect(baseSpeciesName('Mega Garchomp Z'), 'Garchomp');
      expect(baseSpeciesName('Mega Lucario Z'), 'Lucario');
    });

    test('Primal / Ultra / Hoopa', () {
      expect(baseSpeciesName('Primal Groudon'), 'Groudon');
      expect(baseSpeciesName('Primal Kyogre'), 'Kyogre');
      expect(baseSpeciesName('Ultra Necrozma'), 'Necrozma');
      expect(baseSpeciesName('Hoopa Unbound'), 'Hoopa');
    });

    test('Kyurem / Necrozma / Calyrex compound prefixes', () {
      expect(baseSpeciesName('Black Kyurem'), 'Kyurem');
      expect(baseSpeciesName('White Kyurem'), 'Kyurem');
      expect(baseSpeciesName('Dawn Wings Necrozma'), 'Necrozma');
      expect(baseSpeciesName('Dusk Mane Necrozma'), 'Necrozma');
      expect(baseSpeciesName('Ice Rider Calyrex'), 'Calyrex');
      expect(baseSpeciesName('Shadow Rider Calyrex'), 'Calyrex');
    });

    test('Rotom appliance forms collapse to Rotom', () {
      expect(baseSpeciesName('Heat Rotom'), 'Rotom');
      expect(baseSpeciesName('Wash Rotom'), 'Rotom');
      expect(baseSpeciesName('Mow Rotom'), 'Rotom');
    });

    test('Regional variants', () {
      expect(baseSpeciesName('Alolan Raichu'), 'Raichu');
      expect(baseSpeciesName('Hisuian Decidueye'), 'Decidueye');
      expect(baseSpeciesName('Galarian Slowking'), 'Slowking');
      expect(baseSpeciesName('Paldean Tauros'), 'Tauros');
    });

    test('Regional + nested forme strips both layers', () {
      expect(baseSpeciesName('Galarian Darmanitan (Zen Mode)'), 'Darmanitan');
    });

    test('Parenthesised formes strip the parens block', () {
      expect(baseSpeciesName('Deoxys (Attack Forme)'), 'Deoxys');
      expect(baseSpeciesName('Tornadus (Therian Forme)'), 'Tornadus');
      expect(baseSpeciesName('Indeedee (Female)'), 'Indeedee');
      expect(baseSpeciesName('Toxtricity (Low Key Form)'), 'Toxtricity');
    });

    test('Base species names return null (no fallback needed)', () {
      expect(baseSpeciesName('Pikachu'), isNull);
      expect(baseSpeciesName('Baxcalibur'), isNull);
      expect(baseSpeciesName('Mr. Mime'), isNull);
    });
  });

  group('SpriteService', () {
    test('default style is bw', () {
      expect(SpriteService.instance.style, SpriteStyle.bw);
    });

    test('SpriteStyle.dir / .ext for each enum value', () {
      expect(SpriteStyle.bw.dir, 'gen5');
      expect(SpriteStyle.bw.ext, 'png');
      expect(SpriteStyle.ani.dir, 'ani');
      expect(SpriteStyle.ani.ext, 'gif');
      expect(SpriteStyle.dex.dir, 'dex');
      expect(SpriteStyle.dex.ext, 'png');
    });

    test('spriteFor returns null on mobile (v1 — pack import not wired)',
        () {
      // The test runner reports kIsWeb == false; spriteFor must keep
      // that contract so the placeholder code path stays exercised.
      expect(SpriteService.instance.spriteFor('Pikachu'), isNull);
    });
  });
}
