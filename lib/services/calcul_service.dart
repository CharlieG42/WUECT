import 'dart:math';

import '../models/projet.dart';
import '../models/pompe.dart';
import 'database_service.dart';

class CalculService {
  final DatabaseService _db = DatabaseService.instance;

  // ====================
  // Calculs de base
  // ====================
  
  /// Calcule le coefficient de perte de rendement (µPerte)
  /// Formule: (1 - µCoef)^(Année en cours - Année d'installation)
  /// µCoef = percentagePerteRendement / 100
  static double calculerMuPerte(double percentagePerteRendement, int anneeInstallation, int anneeEnCours) {
    // Limiter percentagePerteRendement à [0, 100] pour éviter des calculs aberrants
    final percentageClamped = percentagePerteRendement.clamp(0.0, 100.0);
    
    if (percentageClamped >= 100.0) return 0.0; // Si perte >= 100%, rendement = 0
    final muCoef = percentageClamped / 100.0;
    final anneesEcoulees = anneeEnCours - anneeInstallation;
    
    // Si l'année d'installation est dans le futur ou l'année en cours, on considere muPerte = 1 (pas de perte)
    if (anneesEcoulees <= 0) return 1.0;
    
    // Limiter le nombre d'années pour éviter des calculs exponentiels trop grands
    // Au-delà de 15 ans, on considere que le rendement est à 0
    final anneesLimitees = anneesEcoulees.clamp(0, 15);
    
    return pow(1 - muCoef, anneesLimitees).toDouble();
  }

  /// Calcule le rendement corrigé de la pompe
  static double calculerMuPompeCorrige(double rendementInitial, double muPerte) {
    return rendementInitial * muPerte / 100.0; // rendementInitial est en %, on le convertit en facteur (0.0-1.0)
  }

  /// Calcule la puissance par pompe (kW)
  /// Formule: (Débit * HMT) / (367 * µPompeCorrigé * µMoteurCorrigé)
  static double calculerPuissancePompe(
    double debit,
    double hmt,
    double muPompeCorrige,
    double muMoteurCorrige,
  ) {
    if (muPompeCorrige <= 0 || muMoteurCorrige <= 0) return 0.0;
    return (debit * hmt) / (367 * muPompeCorrige * muMoteurCorrige);
  }

  /// Calcule la consommation annuelle d'une pompe (kWh)
  static double calculerConsommationAnnuellePompe(
    double debit,
    double hmt,
    double muPompeCorrige,
    double muMoteurCorrige,
    int heuresFonctionnement,
  ) {
    final puissance = calculerPuissancePompe(debit, hmt, muPompeCorrige, muMoteurCorrige);
    return puissance * heuresFonctionnement;
  }

  // ====================
  // Calculs pour un système
  // ====================
  
  /// Calcule la consommation annuelle totale d'un système (kWh)
  /// en sommant toutes ses pompes
  Future<double> calculerConsommationAnnuelleSysteme(int systemeId, int anneeEnCours, double percentagePerteRendement) async {
    final pompes = await _db.getPompesBySystemeId(systemeId);
    return _calculerConsommationAnnuelleSystemeAvecPompes(pompes, anneeEnCours, percentagePerteRendement);
  }

  /// Calcule la consommation annuelle totale avec les pompes déjà chargées
  static double _calculerConsommationAnnuelleSystemeAvecPompes(
    List<Pompe> pompes,
    int anneeEnCours,
    double percentagePerteRendement,
  ) {
    double consommationTotale = 0.0;

    for (final pompe in pompes) {
      final muPerte = calculerMuPerte(
        percentagePerteRendement,
        pompe.anneeInstallation,
        anneeEnCours,
      );
      final muPompeCorrige = calculerMuPompeCorrige(pompe.rendementInitialPompe, muPerte);
      final muMoteurCorrige = calculerMuPompeCorrige(pompe.rendementInitialMoteur, muPerte);
      
      consommationTotale += calculerConsommationAnnuellePompe(
        pompe.debit,
        pompe.hmt,
        muPompeCorrige,
        muMoteurCorrige,
        pompe.heuresFonctionnement,
      );
    }
    return consommationTotale;
  }

  /// Calcule le coût énergétique annuel d'un système (€)
  static double calculerCoutEnergetiqueAnuel(
    double consommationKWh,
    double coutEnergie,
  ) {
    return consommationKWh * coutEnergie;
  }

  // ====================
  // Calculs sur 10 ans
  // ====================
  
  /// Calcule la consommation et le coût énergétique sur 10 ans pour un système
  Future<Map<String, List<double>>> calculerDonnees10Ans(
    int systemeId,
    Projet projet,
  ) async {
    final anneeEnCours = DateTime.now().year;
    final List<double> consommations = [];
    final List<double> coutsEnergetiques = [];
    double coutEnergieActuel = projet.coutEnergie;
    
    // Charger les pompes une seule fois au lieu de 10 fois
    final pompes = await _db.getPompesBySystemeId(systemeId);

    for (int annee = 0; annee < 10; annee++) {
      final anneeCalcul = anneeEnCours + annee;
      
      // Calcul de la consommation pour cette année avec les pompes déjà chargées
      final consommation = _calculerConsommationAnnuelleSystemeAvecPompes(
        pompes,
        anneeCalcul,
        projet.percentagePerteRendement,
      );
      consommations.add(consommation);
      
      // Calcul du coût énergétique pour cette année
      // Le coût de l'énergie augmente chaque année
      final coutEnergie = coutEnergieActuel;
      final cout = calculerCoutEnergetiqueAnuel(consommation, coutEnergie);
      coutsEnergetiques.add(cout);
      
      // Mise à jour du coût de l'énergie pour l'année suivante
      coutEnergieActuel *= (1 + projet.pourcentageAugmentationEnergie / 100.0);
    }
    
    return {
      'consommations': consommations,
      'coutsEnergetiques': coutsEnergetiques,
    };
  }

  /// Calcule le ROI entre deux systèmes sur 10 ans
  Future<Map<String, dynamic>> calculerROI(
    int systemeAncienId,
    int systemeNouveauId,
    Projet projet,
  ) async {
    // Charger les systèmes et leurs pompes en parallèle
    final systemeAncienFuture = _db.getSystemeById(systemeAncienId);
    final systemeNouveauFuture = _db.getSystemeById(systemeNouveauId);
    final pompesAncienFuture = _db.getPompesBySystemeId(systemeAncienId);
    final pompesNouveauFuture = _db.getPompesBySystemeId(systemeNouveauId);
    
    final systemeAncien = await systemeAncienFuture;
    final systemeNouveau = await systemeNouveauFuture;
    final pompesAncien = await pompesAncienFuture;
    final pompesNouveau = await pompesNouveauFuture;
    
    // Calculer les données pour les deux systèmes en parallèle
    final donneesAncien = _calculerDonnees10AnsAvecPompes(
      pompesAncien,
      projet,
    );
    final donneesNouveau = _calculerDonnees10AnsAvecPompes(
      pompesNouveau,
      projet,
    );
    
    // Coûts énergétiques cumulés sur 10 ans
    final coutAncienTotal = donneesAncien['coutsEnergetiques']!.reduce((a, b) => a + b);
    final coutNouveauTotal = donneesNouveau['coutsEnergetiques']!.reduce((a, b) => a + b);
    
    // Économie totale sur 10 ans
    final economieTotale = coutAncienTotal - coutNouveauTotal;
    
    // Différence de coût d'investissement
    final deltaInvestissement = systemeNouveau!.coutInvestissementTotal - systemeAncien!.coutInvestissementTotal;
    
    // ROI (en années)
    double roiAnnee = double.infinity;
    if (deltaInvestissement > 0 && economieTotale > 0) {
      roiAnnee = deltaInvestissement / (economieTotale / 10);
    } else if (deltaInvestissement <= 0 && economieTotale >= 0) {
      roiAnnee = 0.0; // Rentable immédiatement
    }
    
    return {
      'coutAncienTotal': coutAncienTotal,
      'coutNouveauTotal': coutNouveauTotal,
      'economieTotale': economieTotale,
      'deltaInvestissement': deltaInvestissement,
      'roiAnnee': roiAnnee,
      'estRentable': economieTotale >= deltaInvestissement,
    };
  }

  /// Calcule les données sur 10 ans avec les pompes déjà chargées
  static Map<String, List<double>> _calculerDonnees10AnsAvecPompes(
    List<Pompe> pompes,
    Projet projet,
  ) {
    final anneeEnCours = DateTime.now().year;
    final List<double> consommations = [];
    final List<double> coutsEnergetiques = [];
    double coutEnergieActuel = projet.coutEnergie;

    for (int annee = 0; annee < 10; annee++) {
      final anneeCalcul = anneeEnCours + annee;
      
      // Calcul de la consommation pour cette année
      final consommation = _calculerConsommationAnnuelleSystemeAvecPompes(
        pompes,
        anneeCalcul,
        projet.percentagePerteRendement,
      );
      consommations.add(consommation);
      
      // Calcul du coût énergétique pour cette année
      final coutEnergie = coutEnergieActuel;
      final cout = calculerCoutEnergetiqueAnuel(consommation, coutEnergie);
      coutsEnergetiques.add(cout);
      
      // Mise à jour du coût de l'énergie pour l'année suivante
      coutEnergieActuel *= (1 + projet.pourcentageAugmentationEnergie / 100.0);
    }
    
    return {
      'consommations': consommations,
      'coutsEnergetiques': coutsEnergetiques,
    };
  }

  /// Calcule les données sur 10 ans avec les pompes déjà chargées (version publique)
  static Map<String, List<double>> calculerDonnees10AnsAvecPompes(
    List<Pompe> pompes,
    Projet projet,
  ) {
    return _calculerDonnees10AnsAvecPompes(pompes, projet);
  }

  /// Calcule toutes les données pour le comparatif
  Future<Map<String, dynamic>> calculerComparatifComplet(int projetId) async {
    final projet = await _db.getProjetById(projetId);
    if (projet == null) {
      throw Exception('Projet non trouvé');
    }
    
    final systemes = await _db.getSystemesByProjetId(projetId);
    if (systemes.length != 2) {
      throw Exception('Un projet doit avoir exactement 2 systèmes (Ancien et Nouveau)');
    }
    
    // Identifier les systèmes Ancien et Nouveau
    final systemeAncien = systemes.firstWhere((s) => s.nom.toLowerCase().contains('ancien'));
    final systemeNouveau = systemes.firstWhere((s) => s.nom.toLowerCase().contains('nouveau'));
    
    // Calcul des données sur 10 ans
    final donneesAncien = await calculerDonnees10Ans(systemeAncien.id!, projet);
    final donneesNouveau = await calculerDonnees10Ans(systemeNouveau.id!, projet);
    
    // Calcul du ROI
    final roiData = await calculerROI(
      systemeAncien.id!,
      systemeNouveau.id!,
      projet,
    );
    
    return {
      'projet': projet,
      'systemeAncien': systemeAncien,
      'systemeNouveau': systemeNouveau,
      'annees': List.generate(10, (i) => DateTime.now().year + i),
      'consommationsAncien': donneesAncien['consommations'],
      'consommationsNouveau': donneesNouveau['consommations'],
      'coutsEnergetiquesAncien': donneesAncien['coutsEnergetiques'],
      'coutsEnergetiquesNouveau': donneesNouveau['coutsEnergetiques'],
      'roiData': roiData,
    };
  }

  // Fermeture
  Future<void> close() async {
    await _db.close();
  }
}
