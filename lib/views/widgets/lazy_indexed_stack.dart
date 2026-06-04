import 'package:flutter/widgets.dart';

/// IndexedStack variant that only builds slots after their first
/// activation. Unbuilt slots render a `SizedBox.shrink()` placeholder
/// so the stack still has stable child positions for index lookup,
/// but no real widget tree is constructed until the tab is opened.
///
/// Used by [RootShell] to lazy-init non-Calc tabs: cold-start cost
/// stays low (only Calc is mounted), and once a tab has been
/// activated its full widget State survives every subsequent index
/// switch — IndexedStack keeps non-current children mounted but
/// unpainted.
class LazyIndexedStack extends StatelessWidget {
  final int index;
  final List<bool> built;
  final List<WidgetBuilder> builders;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.built,
    required this.builders,
  })  : assert(built.length == builders.length);

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: [
        for (int i = 0; i < builders.length; i++)
          built[i] ? builders[i](context) : const SizedBox.shrink(),
      ],
    );
  }
}
