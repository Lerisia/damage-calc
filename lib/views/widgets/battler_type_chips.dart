import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../models/battle_pokemon.dart';
import '../../models/type.dart';
import 'type_chip.dart';

/// The types a battler has right now, for the damage headers: the Tera
/// type alone (tagged "테라") while Terastallized into a normal type,
/// otherwise its own types.
///
/// Shared by the Extended Mode damage tab and the result panel, which
/// each carried a copy of this as coloured text.
class BattlerTypeChips extends StatelessWidget {
  final BattlePokemonState state;

  const BattlerTypeChips(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final tera = state.terastal;
    if (tera.active &&
        tera.teraType != null &&
        tera.teraType != PokemonType.stellar) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TypeChip.dense(tera.teraType!),
          Text(
            ' (${AppStrings.t('label.terastalShort')})',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypeChip.dense(state.type1),
        if (state.type2 != null) ...[
          const SizedBox(width: 3),
          TypeChip.dense(state.type2!),
        ],
      ],
    );
  }
}
