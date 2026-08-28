import 'package:hive/hive.dart';

part 'systeme.g.dart';

@HiveType(typeId: 2)
class Systeme {
  @HiveField(0)
  final int? id;
  
  @HiveField(1)
  final int projetId; // Référence au projet
  
  @HiveField(2)
  final String nom; // "Ancien Système" ou "Nouveau Système"
  
  @HiveField(3)
  final double coutInvestissementTotal; // €

  Systeme({
    this.id,
    required this.projetId,
    required this.nom,
    this.coutInvestissementTotal = 0.0,
  });

  // Conversion en Map pour SQLite (gardé pour compatibilité)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'projetId': projetId,
      'nom': nom,
      'coutInvestissementTotal': coutInvestissementTotal,
    };
  }

  // Création depuis un Map (SQLite) (gardé pour compatibilité)
  factory Systeme.fromMap(Map<String, dynamic> map) {
    return Systeme(
      id: map['id'],
      projetId: map['projetId'] ?? 0,
      nom: map['nom'] ?? '',
      coutInvestissementTotal: (map['coutInvestissementTotal'] ?? 0.0).toDouble(),
    );
  }

  // Copie avec modification
  Systeme copyWith({
    int? id,
    int? projetId,
    String? nom,
    double? coutInvestissementTotal,
  }) {
    return Systeme(
      id: id ?? this.id,
      projetId: projetId ?? this.projetId,
      nom: nom ?? this.nom,
      coutInvestissementTotal: coutInvestissementTotal ?? this.coutInvestissementTotal,
    );
  }
}
