/// Active room/field conditions (can stack)
class RoomConditions {
  final bool trickRoom;
  final bool magicRoom;
  final bool wonderRoom;
  final bool gravity;

  const RoomConditions({
    this.trickRoom = false,
    this.magicRoom = false,
    this.wonderRoom = false,
    this.gravity = false,
  });

  bool get hasAny => trickRoom || magicRoom || wonderRoom || gravity;

  RoomConditions copyWith({
    bool? trickRoom,
    bool? magicRoom,
    bool? wonderRoom,
    bool? gravity,
  }) {
    return RoomConditions(
      trickRoom: trickRoom ?? this.trickRoom,
      magicRoom: magicRoom ?? this.magicRoom,
      wonderRoom: wonderRoom ?? this.wonderRoom,
      gravity: gravity ?? this.gravity,
    );
  }
}

/// Legacy Room enum for backward compatibility during migration
enum Room {
  none,
  trickRoom,
  magicRoom,
  wonderRoom,
}
