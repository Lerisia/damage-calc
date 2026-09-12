import 'package:flutter_test/flutter_test.dart';
import 'package:damage_calc/data/champions_moves.dart';

/// The Champions move allowlist loader and its fail-open rule: before
/// the asset is loaded nothing is filtered, and once loaded a move is
/// legal iff the ROM roster lists it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fails open before the allowlist is loaded', () {
    // Runs first in this file: the cache is still empty.
    expect(isChampionsMove('Return'), isTrue);
  });

  test('once loaded, legal moves pass and mainline-only moves are cut', () async {
    final set = await loadChampionsMoves();
    expect(set.length, greaterThan(400));
    expect(isChampionsMove('Earthquake'), isTrue);
    expect(isChampionsMove('Pyro Ball'), isTrue);
    expect(isChampionsMove('Return'), isFalse);
    expect(isChampionsMove('Hidden Power'), isFalse);
  });
}
