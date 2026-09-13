import 'package:flutter/material.dart';

import '../../models/type.dart';
import '../../i18n/localization.dart';

/// A type badge: type colour, white bold name. [dense] is the smaller
/// variant used inside slot cards; the default is the dex header size.
class TypeChip extends StatelessWidget {
  final PokemonType type;
  final bool dense;

  const TypeChip(this.type, {super.key, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KoStrings.getTypeColor(type),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        KoStrings.getTypeName(type),
        style: TextStyle(
            fontSize: dense ? 11 : 12,
            color: Colors.white,
            fontWeight: FontWeight.bold),
      ),
    );
  }
}
