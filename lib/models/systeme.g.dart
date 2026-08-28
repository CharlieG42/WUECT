// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'systeme.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SystemeAdapter extends TypeAdapter<Systeme> {
  @override
  final int typeId = 2;

  @override
  Systeme read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Systeme(
      id: fields[0] as int?,
      projetId: fields[1] as int,
      nom: fields[2] as String,
      coutInvestissementTotal: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Systeme obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.projetId)
      ..writeByte(2)
      ..write(obj.nom)
      ..writeByte(3)
      ..write(obj.coutInvestissementTotal);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SystemeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
