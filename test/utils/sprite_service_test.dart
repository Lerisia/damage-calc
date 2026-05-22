import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/utils/sprite_service.dart';

void main() {
  group('spriteKeyFor', () {
    test('plain species name', () {
      expect(spriteKeyFor('Pikachu'), 'pikachu');
    });

    test('Mega form', () {
      expect(spriteKeyFor('Mega Abomasnow'), 'mega-abomasnow');
    });

    test('Mega X / Y forms', () {
      expect(spriteKeyFor('Mega Charizard X'), 'mega-charizard-x');
      expect(spriteKeyFor('Mega Charizard Y'), 'mega-charizard-y');
    });

    test('regional form', () {
      expect(spriteKeyFor('Alolan Raichu'), 'alolan-raichu');
      expect(spriteKeyFor('Hisuian Decidueye'), 'hisuian-decidueye');
    });

    test('parenthesised forme', () {
      expect(spriteKeyFor('Terapagos (Stellar Form)'),
          'terapagos-stellar-form');
      expect(spriteKeyFor('Tornadus (Therian Forme)'),
          'tornadus-therian-forme');
    });

    test('gender symbols map distinctly (no collision)', () {
      expect(spriteKeyFor('Nidoran♀'), 'nidoran-f');
      expect(spriteKeyFor('Nidoran♂'), 'nidoran-m');
      expect(spriteKeyFor('Nidoran♀') == spriteKeyFor('Nidoran♂'), isFalse);
    });

    test('punctuation collapses, no leading/trailing dashes', () {
      expect(spriteKeyFor("Farfetch'd"), 'farfetch-d');
      expect(spriteKeyFor('  Mega  Gengar  '), 'mega-gengar');
    });
  });

  group('SpriteService', () {
    test('icon returns null while the pack is not ready', () {
      SpriteService.instance.packReady = false;
      expect(SpriteService.instance.iconFor('Pikachu'), isNull);
    });

    test('battle sprite returns null while the pack is not ready', () {
      SpriteService.instance.packReady = false;
      expect(SpriteService.instance.battleSpriteFor('Pikachu'), isNull);
    });
  });
}
