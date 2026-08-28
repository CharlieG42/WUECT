import 'package:hive/hive.dart';

part 'projet.g.dart';

@HiveType(typeId: 1)
class Projet {
  @HiveField(0)
  final int? id;
  
  @HiveField(1)
  final String nomSite;
  
  @HiveField(2)
  final int contactId; // Référence au contact associé
  
  @HiveField(3)
  final double coutEnergie; // €/kWh
  
  @HiveField(4)
  final double pourcentageAugmentationEnergie; // % par an (ex: 5.0 pour 5%)
  
  @HiveField(5)
  final double percentagePerteRendement; // µCoef (ex: 0.01 pour 1%)

  Projet({
    this.id,
    required this.nomSite,
    required this.contactId,
    required this.coutEnergie,
    required this.pourcentageAugmentationEnergie,
    required this.percentagePerteRendement,
  });

  // Conversion en Map pour SQLite (gardé pour compatibilité)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nomSite': nomSite,
      'contactId': contactId,
      'coutEnergie': coutEnergie,
      'pourcentageAugmentationEnergie': pourcentageAugmentationEnergie,
      'percentagePerteRendement': percentagePerteRendement,
    };
  }

  // Création depuis un Map (SQLite) (gardé pour compatibilité)
  factory Projet.fromMap(Map<String, dynamic> map) {
    return Projet(
      id: map['id'],
      nomSite: map['nomSite'] ?? '',
      contactId: map['contactId'] ?? 0,
      coutEnergie: (map['coutEnergie'] ?? 0.0).toDouble(),
      pourcentageAugmentationEnergie: (map['pourcentageAugmentationEnergie'] ?? 0.0).toDouble(),
      percentagePerteRendement: (map['percentagePerteRendement'] ?? 0.0).toDouble(),
    );
  }

  // Copie avec modification
  Projet copyWith({
    int? id,
    String? nomSite,
    int? contactId,
    double? coutEnergie,
    double? pourcentageAugmentationEnergie,
    double? percentagePerteRendement,
  }) {
    return Projet(
      id: id ?? this.id,
      nomSite: nomSite ?? this.nomSite,
      contactId: contactId ?? this.contactId,
      coutEnergie: coutEnergie ?? this.coutEnergie,
      pourcentageAugmentationEnergie: pourcentageAugmentationEnergie ?? this.pourcentageAugmentationEnergie,
      percentagePerteRendement: percentagePerteRendement ?? this.percentagePerteRendement,
    );
  }
}
