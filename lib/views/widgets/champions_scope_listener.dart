import 'package:flutter/widgets.dart';

import '../../utils/champions_filter_controller.dart';

/// Rebuilds the host State whenever the global "Champions only" scope
/// flips — pickers filter on it, panels hide non-Champions mechanics on
/// it, and the toggle lives in the settings menu, so it can change
/// while any of them is on screen. Mix in instead of hand-wiring the
/// listener in initState / dispose (five widgets used to).
mixin ChampionsScopeListener<T extends StatefulWidget> on State<T> {
  @override
  void initState() {
    super.initState();
    ChampionsFilterController.instance.championsOnly
        .addListener(_onChampionsScopeChanged);
  }

  @override
  void dispose() {
    ChampionsFilterController.instance.championsOnly
        .removeListener(_onChampionsScopeChanged);
    super.dispose();
  }

  void _onChampionsScopeChanged() {
    if (mounted) setState(() {});
  }
}
