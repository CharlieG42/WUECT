// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'projet.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProjetAdapter extends TypeAdapter<Projet> {
  @override
  final int typeId = 1;

  @override
  Projet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Projet(
      id: fields[0] as int?,
      nomSite: fields[1] as String,
      contactId: fields[2] as int,
      coutEnergie: fields[3] as double,
      pourcentageAugmentationEnergie: fields[4] as double,
      percentagePerteRendement: fields[5] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Projet obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nomSite)
      ..writeByte(2)
      ..write(obj.contactId)
      ..writeByte(3)
      ..write(obj.coutEnergie)
      ..writeByte(4)
      ..write(obj.pourcentageAugmentationEnergie)
      ..writeByte(5)
      ..write(obj.percentagePerteRendement);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProjetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
