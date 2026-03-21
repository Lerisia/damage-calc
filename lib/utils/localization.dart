import '../models/move.dart';
import '../models/room.dart';
import '../models/status.dart';
import '../models/terrain.dart';
import '../models/type.dart';
import '../models/weather.dart';

/// Centralized Korean localization strings used across the app.
class KoStrings {
  KoStrings._();

  static const Map<PokemonType, String> typeKo = {
    PokemonType.normal: '노말',
    PokemonType.fire: '불꽃',
    PokemonType.water: '물',
    PokemonType.electric: '전기',
    PokemonType.grass: '풀',
    PokemonType.ice: '얼음',
    PokemonType.fighting: '격투',
    PokemonType.poison: '독',
    PokemonType.ground: '땅',
    PokemonType.flying: '비행',
    PokemonType.psychic: '에스퍼',
    PokemonType.bug: '벌레',
    PokemonType.rock: '바위',
    PokemonType.ghost: '고스트',
    PokemonType.dragon: '드래곤',
    PokemonType.dark: '악',
    PokemonType.steel: '강철',
    PokemonType.fairy: '페어리',
    PokemonType.stellar: '스텔라',
  };

  static const Map<MoveCategory, String> categoryKo = {
    MoveCategory.physical: '물리',
    MoveCategory.special: '특수',
    MoveCategory.status: '변화',
  };

  static const Map<Weather, String> weatherKo = {
    Weather.none: '없음',
    Weather.sun: '쾌청',
    Weather.rain: '비',
    Weather.sandstorm: '모래바람',
    Weather.snow: '눈',
    Weather.harshSun: '강한 햇살',
    Weather.heavyRain: '강한 비',
    Weather.strongWinds: '난기류',
  };

  static const Map<Weather, String> weatherIcon = {
    Weather.none: '☁️',
    Weather.sun: '☀️',
    Weather.rain: '🌧️',
    Weather.sandstorm: '🏜️',
    Weather.snow: '❄️',
    Weather.harshSun: '🔥',
    Weather.heavyRain: '🌊',
    Weather.strongWinds: '🌪️',
  };

  /// Weather Korean names with emoji prefix (for capture headers).
  static const Map<Weather, String> weatherKoWithIcon = {
    Weather.none: '',
    Weather.sun: '☀️쾌청',
    Weather.rain: '🌧️비',
    Weather.sandstorm: '🏜️모래바람',
    Weather.snow: '❄️눈',
    Weather.harshSun: '🔥강한 햇살',
    Weather.heavyRain: '🌊강한 비',
    Weather.strongWinds: '🌪️난기류',
  };

  static const Map<Terrain, String> terrainKo = {
    Terrain.none: '없음',
    Terrain.electric: '일렉트릭필드',
    Terrain.grassy: '그래스필드',
    Terrain.psychic: '사이코필드',
    Terrain.misty: '미스트필드',
  };

  static const Map<Terrain, String> terrainIcon = {
    Terrain.none: '🌍',
    Terrain.electric: '⚡',
    Terrain.grassy: '🌿',
    Terrain.psychic: '🔮',
    Terrain.misty: '💫',
  };

  /// Terrain Korean names with emoji prefix (for capture headers).
  static const Map<Terrain, String> terrainKoWithIcon = {
    Terrain.none: '',
    Terrain.electric: '⚡일렉트릭필드',
    Terrain.grassy: '🌿그래스필드',
    Terrain.psychic: '🔮사이코필드',
    Terrain.misty: '💫미스트필드',
  };

  static const Map<Room, String> roomKo = {
    Room.none: '없음',
    Room.trickRoom: '트릭룸',
    Room.magicRoom: '매직룸',
    Room.wonderRoom: '원더룸',
  };

  static const Map<Room, String> roomIcon = {
    Room.none: '🚪',
    Room.trickRoom: '🔄',
    Room.magicRoom: '✨',
    Room.wonderRoom: '❓',
  };

  /// Room Korean names with emoji prefix (for capture headers).
  static const Map<Room, String> roomKoWithIcon = {
    Room.none: '',
    Room.trickRoom: '🔄트릭룸',
    Room.magicRoom: '✨매직룸',
    Room.wonderRoom: '❓원더룸',
  };

  static const Map<StatusCondition, String> statusKo = {
    StatusCondition.none: '없음',
    StatusCondition.burn: '화상',
    StatusCondition.poison: '독',
    StatusCondition.badlyPoisoned: '맹독',
    StatusCondition.paralysis: '마비',
    StatusCondition.sleep: '잠듦',
    StatusCondition.freeze: '얼음',
  };

  static const Map<StatusCondition, String> statusIcon = {
    StatusCondition.none: '✅',
    StatusCondition.burn: '🔥',
    StatusCondition.poison: '☠️',
    StatusCondition.badlyPoisoned: '💀',
    StatusCondition.paralysis: '⚡',
    StatusCondition.sleep: '😴',
    StatusCondition.freeze: '🧊',
  };

  /// Helper to get a type's Korean name with fallback.
  static String getTypeKo(PokemonType t) => typeKo[t] ?? t.name;

  /// Helper to get a category's Korean name.
  static String getCategoryKo(MoveCategory c) => categoryKo[c] ?? c.name;
}
