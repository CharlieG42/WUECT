// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pompe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PompeAdapter extends TypeAdapter<Pompe> {
  @override
  final int typeId = 3;

  @override
  Pompe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Pompe(
      id: fields[0] as int?,
      systemeId: fields[1] as int,
      marque: fields[2] as String,
      modele: fields[3] as String,
      puissanceNominale: fields[4] as double,
      debit: fields[5] as double,
      hmt: fields[6] as double,
      rendementInitialPompe: fields[7] as double,
      rendementInitialMoteur: fields[8] as double,
      anneeInstallation: fields[9] as int,
      heuresFonctionnement: fields[10] as int,
      coutInvestissement: fields[11] as double,
      p1Estimee: fields[12] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Pompe obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.systemeId)
      ..writeByte(2)
      ..write(obj.marque)
      ..writeByte(3)
      ..write(obj.modele)
      ..writeByte(4)
      ..write(obj.puissanceNominale)
      ..writeByte(5)
      ..write(obj.debit)
      ..writeByte(6)
      ..write(obj.hmt)
      ..writeByte(7)
      ..write(obj.rendementInitialPompe)
      ..writeByte(8)
      ..write(obj.rendementInitialMoteur)
      ..writeByte(9)
      ..write(obj.anneeInstallation)
      ..writeByte(10)
      ..write(obj.heuresFonctionnement)
      ..writeByte(11)
      ..write(obj.coutInvestissement)
      ..writeByte(12)
      ..write(obj.p1Estimee);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PompeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
