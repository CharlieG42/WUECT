import 'package:hive/hive.dart';
import '../models/contact.dart';
import '../models/projet.dart';
import '../models/systeme.dart';
import '../models/pompe.dart';

// Noms des boxes Hive
class HiveBoxNames {
  static const String contacts = 'contacts';
  static const String projets = 'projets';
  static const String systemes = 'systemes';
  static const String pompes = 'pompes';
}

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  
  // Boxes Hive
  late final Box<Contact> _contactsBox;
  late final Box<Projet> _projetsBox;
  late final Box<Systeme> _systemesBox;
  late final Box<Pompe> _pompesBox;

  DatabaseService._init();

  // Helper method pour générer un nouvel ID auto-incrémenté
  int _generateNewId(Iterable<dynamic> keys) {
    if (keys.isEmpty) return 1;
    
    // Trouver la clé maximum
    // Les clés peuvent être de type int ou dynamic, on les cast en int
    int maxId = 0;
    for (final key in keys) {
      if (key is int && key > maxId) {
        maxId = key;
      }
    }
    
    return maxId + 1;
  }

  // Initialisation des boxes
  static Future<void> init() async {
    // Enregistrer les adapters (fait automatiquement par le code généré)
    
    // Ouvrir les boxes
    instance._contactsBox = await Hive.openBox<Contact>(HiveBoxNames.contacts);
    instance._projetsBox = await Hive.openBox<Projet>(HiveBoxNames.projets);
    instance._systemesBox = await Hive.openBox<Systeme>(HiveBoxNames.systemes);
    instance._pompesBox = await Hive.openBox<Pompe>(HiveBoxNames.pompes);
  }

  // ====================
  // CRUD pour Contact
  // ====================
  
  Future<int> insertContact(Contact contact) async {
    // Utiliser Hive.auto-increment key via `add()` pour éviter les collisions
    final contactToInsert = Contact(
      client: contact.client,
      nom: contact.nom,
      email: contact.email,
      mobile: contact.mobile,
    );

    final key = await _contactsBox.add(contactToInsert);
    final int id = key;

    // Mettre à jour l'objet stocké pour inclure l'ID
    final contactWithId = contactToInsert.copyWith(id: id);
    await _contactsBox.put(id, contactWithId);
    return id;
  }

  Future<List<Contact>> getAllContacts() async {
    return _contactsBox.values.toList();
  }

  Future<Contact?> getContactById(int id) async {
    return _contactsBox.get(id);
  }

  Future<int> updateContact(Contact contact) async {
    if (contact.id == null) return 0;
    await _contactsBox.put(contact.id, contact);
    return 1;
  }

  Future<int> deleteContact(int id) async {
    await _contactsBox.delete(id);
    return 1;
  }

  // ====================
  // CRUD pour Projet
  // ====================
  
  Future<int> insertProjet(Projet projet) async {
    final projetToInsert = Projet(
      nomSite: projet.nomSite,
      contactId: projet.contactId,
      coutEnergie: projet.coutEnergie,
      pourcentageAugmentationEnergie: projet.pourcentageAugmentationEnergie,
      percentagePerteRendement: projet.percentagePerteRendement,
    );

    final key = await _projetsBox.add(projetToInsert);
    final int id = key;

    final projetWithId = projetToInsert.copyWith(id: id);
    await _projetsBox.put(id, projetWithId);
    return id;
  }

  Future<List<Projet>> getAllProjets() async {
    return _projetsBox.values.toList();
  }

  Future<Projet?> getProjetById(int id) async {
    return _projetsBox.get(id);
  }

  Future<int> updateProjet(Projet projet) async {
    if (projet.id == null) return 0;
    await _projetsBox.put(projet.id, projet);
    return 1;
  }

  Future<int> deleteProjet(int id) async {
    await _projetsBox.delete(id);
    return 1;
  }

  // ====================
  // CRUD pour Systeme
  // ====================
  
  Future<int> insertSysteme(Systeme systeme) async {
    final systemeToInsert = Systeme(
      projetId: systeme.projetId,
      nom: systeme.nom,
      coutInvestissementTotal: systeme.coutInvestissementTotal,
    );

    final key = await _systemesBox.add(systemeToInsert);
    final int id = key;

    final systemeWithId = systemeToInsert.copyWith(id: id);
    await _systemesBox.put(id, systemeWithId);
    return id;
  }

  Future<List<Systeme>> getAllSystemes() async {
    return _systemesBox.values.toList();
  }

  Future<List<Systeme>> getSystemesByProjetId(int projetId) async {
    return _systemesBox.values
        .where((s) => s.projetId == projetId)
        .toList();
  }

  Future<Systeme?> getSystemeById(int id) async {
    return _systemesBox.get(id);
  }

  Future<int> updateSysteme(Systeme systeme) async {
    if (systeme.id == null) return 0;
    await _systemesBox.put(systeme.id, systeme);
    return 1;
  }

  Future<int> deleteSysteme(int id) async {
    await _systemesBox.delete(id);
    return 1;
  }

  // ====================
  // CRUD pour Pompe
  // ====================
  
  Future<int> insertPompe(Pompe pompe) async {
    final pompeToInsert = Pompe(
      systemeId: pompe.systemeId,
      marque: pompe.marque,
      modele: pompe.modele,
      puissanceNominale: pompe.puissanceNominale,
      debit: pompe.debit,
      hmt: pompe.hmt,
      rendementInitialPompe: pompe.rendementInitialPompe,
      rendementInitialMoteur: pompe.rendementInitialMoteur,
      anneeInstallation: pompe.anneeInstallation,
      heuresFonctionnement: pompe.heuresFonctionnement,
      coutInvestissement: pompe.coutInvestissement,
      p1Estimee: pompe.p1Estimee,
    );

    final key = await _pompesBox.add(pompeToInsert);
    final int id = key;

    final pompeWithId = pompeToInsert.copyWith(id: id);
    await _pompesBox.put(id, pompeWithId);
    return id;
  }

  Future<List<Pompe>> getAllPompes() async {
    return _pompesBox.values.toList();
  }

  Future<List<Pompe>> getPompesBySystemeId(int systemeId) async {
    return _pompesBox.values
        .where((p) => p.systemeId == systemeId)
        .toList();
  }

  Future<Pompe?> getPompeById(int id) async {
    return _pompesBox.get(id);
  }

  Future<int> updatePompe(Pompe pompe) async {
    if (pompe.id == null) return 0;
    await _pompesBox.put(pompe.id, pompe);
    return 1;
  }

  Future<int> deletePompe(int id) async {
    await _pompesBox.delete(id);
    return 1;
  }

  // ====================
  // Suppression en cascade
  // ====================
  
  Future<void> deleteProjetAndRelatedData(int projetId) async {
    // Supprimer toutes les pompes des systèmes de ce projet
    final systemes = await getSystemesByProjetId(projetId);
    for (final systeme in systemes) {
      await deletePompeBySystemeId(systeme.id!);
    }
    
    // Supprimer tous les systèmes de ce projet
    final systemesToDelete = _systemesBox.values
        .where((s) => s.projetId == projetId)
        .toList();
    for (final systeme in systemesToDelete) {
      await _systemesBox.delete(systeme.id);
    }
    
    // Supprimer le projet
    await deleteProjet(projetId);
  }

  Future<int> deletePompeBySystemeId(int systemeId) async {
    final pompesToDelete = _pompesBox.values
        .where((p) => p.systemeId == systemeId)
        .toList();
    for (final pompe in pompesToDelete) {
      await _pompesBox.delete(pompe.id);
    }
    return pompesToDelete.length;
  }

  // Fermeture de la base de données
  Future<void> close() async {
    await Hive.close();
  }

  // Pour la compatibilité avec l'ancien code
  Future<void> get database async {}
}
