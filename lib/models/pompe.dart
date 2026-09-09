import 'package:hive/hive.dart';

part 'pompe.g.dart';

@HiveType(typeId: 3)
class Pompe {
  @HiveField(0)
  final int? id;
  
  @HiveField(1)
  final int systemeId; // Référence au système auquel cette pompe appartient
  
  @HiveField(2)
  final String marque;
  
  @HiveField(3)
  final String modele;
  
  @HiveField(4)
  final double puissanceNominale; // kW
  
  @HiveField(5)
  final double debit; // m3/h
  
  @HiveField(6)
  final double hmt; // mce (mètres colonne d'eau)
  
  @HiveField(7)
  final double rendementInitialPompe; // % (ex: 85.0 pour 85%)
  
  @HiveField(8)
  final double rendementInitialMoteur; // % (ex: 90.0 pour 90%)
  
  @HiveField(9)
  final int anneeInstallation;
  
  @HiveField(10)
  final int heuresFonctionnement; // heures par an
  
  @HiveField(11)
  final double coutInvestissement; // €
  
  @HiveField(12)
  final double p1Estimee; // kW - Puissance estimée par l'utilisateur

  Pompe({
    this.id,
    required this.systemeId,
    required this.marque,
    required this.modele,
    required this.puissanceNominale,
    required this.debit,
    required this.hmt,
    required this.rendementInitialPompe,
    required this.rendementInitialMoteur,
    required this.anneeInstallation,
    required this.heuresFonctionnement,
    required this.coutInvestissement,
    this.p1Estimee = 0.0,
  });

  // Calcul de P1 (Puissance utile) en kW
  double get p1Calculee {
    if (debit <= 0 || hmt <= 0 || rendementInitialPompe <= 0 || rendementInitialMoteur <= 0) {
      return 0.0;
    }
    return (debit * hmt) / (367 * (rendementInitialPompe / 100) * (rendementInitialMoteur / 100));
  }

  // Puissance à utiliser pour les calculs
  double get puissanceUtilisee {
    if (p1Estimee > 0) {
      // Calculer p1Calculee une seule fois pour la comparaison
      final p1Calc = (debit <= 0 || hmt <= 0 || rendementInitialPompe <= 0 || rendementInitialMoteur <= 0) 
          ? 0.0 
          : (debit * hmt) / (367 * (rendementInitialPompe / 100) * (rendementInitialMoteur / 100));
      if (p1Estimee != p1Calc) {
        return p1Estimee;
      }
      return p1Calc;
    }
    return p1Calculee;
  }

  // Énergie Spécifique en kW/m3/h
  double get energieSpecifique {
    if (debit <= 0) return 0.0;
    return puissanceUtilisee / debit;
  }

  // Calcul de la consommation annuelle de cette pompe (kWh)
  double calculerConsommationAnnuelle(double muPompeCorrige, double muMoteurCorrige) {
    if (muPompeCorrige <= 0 || muMoteurCorrige <= 0) return 0.0;
    final puissance = (debit * hmt) / (367 * muPompeCorrige * muMoteurCorrige);
    return puissance * heuresFonctionnement;
  }

  // Conversion en Map pour SQLite (gardé pour compatibilité)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'systemeId': systemeId,
      'marque': marque,
      'modele': modele,
      'puissanceNominale': puissanceNominale,
      'debit': debit,
      'hmt': hmt,
      'rendementInitialPompe': rendementInitialPompe,
      'rendementInitialMoteur': rendementInitialMoteur,
      'anneeInstallation': anneeInstallation,
      'heuresFonctionnement': heuresFonctionnement,
      'coutInvestissement': coutInvestissement,
      'p1Estimee': p1Estimee,
    };
  }

  // Création depuis un Map (SQLite) (gardé pour compatibilité)
  factory Pompe.fromMap(Map<String, dynamic> map) {
    return Pompe(
      id: map['id'],
      systemeId: map['systemeId'] ?? 0,
      marque: map['marque'] ?? '',
      modele: map['modele'] ?? '',
      puissanceNominale: (map['puissanceNominale'] ?? 0.0).toDouble(),
      debit: (map['debit'] ?? map['debitNominal'] ?? 0.0).toDouble(),
      hmt: (map['hmt'] ?? map['hmtNominale'] ?? 0.0).toDouble(),
      rendementInitialPompe: (map['rendementInitialPompe'] ?? 0.0).toDouble(),
      rendementInitialMoteur: (map['rendementInitialMoteur'] ?? 0.0).toDouble(),
      anneeInstallation: map['anneeInstallation'] ?? 0,
      heuresFonctionnement: map['heuresFonctionnement'] ?? 0,
      coutInvestissement: (map['coutInvestissement'] ?? 0.0).toDouble(),
      p1Estimee: (map['p1Estimee'] ?? 0.0).toDouble(),
    );
  }

  // Copie avec modification
  Pompe copyWith({
    int? id,
    int? systemeId,
    String? marque,
    String? modele,
    double? puissanceNominale,
    double? debit,
    double? hmt,
    double? rendementInitialPompe,
    double? rendementInitialMoteur,
    int? anneeInstallation,
    int? heuresFonctionnement,
    double? coutInvestissement,
    double? p1Estimee,
  }) {
    return Pompe(
      id: id ?? this.id,
      systemeId: systemeId ?? this.systemeId,
      marque: marque ?? this.marque,
      modele: modele ?? this.modele,
      puissanceNominale: puissanceNominale ?? this.puissanceNominale,
      debit: debit ?? this.debit,
      hmt: hmt ?? this.hmt,
      rendementInitialPompe: rendementInitialPompe ?? this.rendementInitialPompe,
      rendementInitialMoteur: rendementInitialMoteur ?? this.rendementInitialMoteur,
      anneeInstallation: anneeInstallation ?? this.anneeInstallation,
      heuresFonctionnement: heuresFonctionnement ?? this.heuresFonctionnement,
      coutInvestissement: coutInvestissement ?? this.coutInvestissement,
      p1Estimee: p1Estimee ?? this.p1Estimee,
    );
  }
}
