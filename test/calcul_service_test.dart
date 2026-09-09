import 'package:flutter_test/flutter_test.dart';
import 'package:wu_ect/services/calcul_service.dart';
import 'package:wu_ect/models/pompe.dart';
import 'package:wu_ect/models/projet.dart';

void main() {
  test('calculerDonnees10AnsFromPompes returns 10 years of positive values', () async {
    final projet = Projet(
      id: 1,
      nomSite: 'Test site',
      contactId: 1,
      coutEnergie: 0.2,
      pourcentageAugmentationEnergie: 2.0,
      percentagePerteRendement: 1.0,
    );

    final pompe = Pompe(
      id: 1,
      systemeId: 1,
      marque: 'TestBrand',
      modele: 'T1',
      puissanceNominale: 10.0,
      debit: 100.0,
      hmt: 20.0,
      rendementInitialPompe: 80.0,
      rendementInitialMoteur: 90.0,
      anneeInstallation: DateTime.now().year - 1,
      heuresFonctionnement: 2000,
      coutInvestissement: 1000.0,
      p1Estimee: 0.0,
    );

    final result = await CalculService.calculerDonnees10AnsFromPompes([pompe], projet);

    expect(result, isA<Map<String, List<double>>>());
    expect(result['consommations']!.length, 10);
    expect(result['coutsEnergetiques']!.length, 10);
    for (final c in result['consommations']!) {
      expect(c, greaterThanOrEqualTo(0.0));
    }
    for (final c in result['coutsEnergetiques']!) {
      expect(c, greaterThanOrEqualTo(0.0));
    }
  });
}
