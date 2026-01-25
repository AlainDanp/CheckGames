// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player_stats.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PlayerStatsAdapter extends TypeAdapter<PlayerStats> {
  @override
  final int typeId = 0;

  @override
  PlayerStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlayerStats(
      playerName: fields[0] as String,
      gamesPlayed: fields[1] as int,
      wins: fields[2] as int,
      podiums: fields[3] as int,
      positionCounts: (fields[4] as Map).cast<int, int>(),
      lastPlayed: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PlayerStats obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.playerName)
      ..writeByte(1)
      ..write(obj.gamesPlayed)
      ..writeByte(2)
      ..write(obj.wins)
      ..writeByte(3)
      ..write(obj.podiums)
      ..writeByte(4)
      ..write(obj.positionCounts)
      ..writeByte(5)
      ..write(obj.lastPlayed);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
