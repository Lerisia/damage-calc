import '../models/room.dart';

/// Compares speed under room conditions and returns the ordering.
///
/// Trick Room reverses speed comparison, but always-last items
/// (Lagging Tail, Full Incense) are unaffected by Trick Room.
///
/// Returns: positive if [mySpeed] acts first, negative if opponent acts first, 0 if tied.
int compareSpeed({
  required int mySpeed,
  required int opponentSpeed,
  required bool myAlwaysLast,
  required bool opponentAlwaysLast,
  RoomConditions room = const RoomConditions(),
}) {
  // Always-last takes priority over Trick Room
  if (myAlwaysLast && !opponentAlwaysLast) return -1;
  if (!myAlwaysLast && opponentAlwaysLast) return 1;
  // Both or neither always-last: compare speed normally (or reversed)

  final diff = mySpeed - opponentSpeed;
  if (room.trickRoom) return -diff;
  return diff;
}

/// Describes the speed comparison result for display.
enum SpeedResult {
  faster,
  slower,
  tied,
  alwaysFirst,
  alwaysLast,
}

/// Returns the display result for speed comparison.
SpeedResult getSpeedResult({
  required int mySpeed,
  required int opponentSpeed,
  required bool myAlwaysLast,
  required bool opponentAlwaysLast,
  RoomConditions room = const RoomConditions(),
}) {
  if (myAlwaysLast && !opponentAlwaysLast) return SpeedResult.alwaysLast;
  if (!myAlwaysLast && opponentAlwaysLast) return SpeedResult.alwaysFirst;

  final cmp = compareSpeed(
    mySpeed: mySpeed,
    opponentSpeed: opponentSpeed,
    myAlwaysLast: myAlwaysLast,
    opponentAlwaysLast: opponentAlwaysLast,
    room: room,
  );

  if (cmp > 0) return SpeedResult.faster;
  if (cmp < 0) return SpeedResult.slower;
  return SpeedResult.tied;
}
