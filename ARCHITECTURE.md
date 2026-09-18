# WUECT - Architecture du Code

> **Guide de référence pour les contributeurs et forks**
> *Dernière mise à jour : 17/09/2026*

Ce document référence les **fonctions essentielles** du projet WUECT, organisées par module, pour faciliter la compréhension et la maintenance du code.

---

## 📁 Structure du Projet

```
lib/
├── main.dart                          # Point d'entrée de l'application
├── models/                           # Modèles de données (Hive)
│   ├── pompe.dart                    # Modèle Pompe
│   ├── systeme.dart                  # Modèle Système
│   ├── projet.dart                   # Modèle Projet
│   └── contact.dart                  # Modèle Contact
├── services/                         # Services (logique métier)
│   ├── calcul_service.dart           # Calculs principaux
│   ├── database_service.dart         # Gestion de la base Hive
│   └── settings_service.dart         # Paramètres globaux
├── screens/                          # Écrans de l'application
│   ├── home_screen.dart              # Écran d'accueil
│   ├── resultat/resultat_screen.dart # Comparatifs et graphiques
│   └── ...
├── utils/                            # Utilitaires
│   ├── error_handler.dart            # Gestion des erreurs
│   ├── decimation.dart               # Optimisation des graphiques
│   └── ...
└── widgets/                          # Composants réutilisables
    └── settings_dialog.dart           # Dialogue des paramètres
```

---

## 🏗️ Fonctions Essentielles par Module

---

## 📊 **SERVICES** (Logique métier et persistance)

### 1. `lib/services/settings_service.dart`
**Rôle** : Gestion des paramètres globaux de l'application (persistance via Hive)

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `SettingsService.init()` | 29-32 | Initialisation du service et de la box Hive |
| `SettingsService.instance` | 6 | Singleton pour accéder au service |
| `maxAnneesPerteRendement` | 21, 51-52 | Nombre max d'années pour la dégradation du rendement |
| `coutEnergieDefault` | 22, 53 | Coût de l'énergie par défaut (€/kWh) |
| `perteRendementDefault` | 23, 54 | Perte de rendement annuelle par défaut (%) |
| `useDefaultParams` | 24, 55 | Booléen pour utiliser les paramètres par défaut |

---

### 2. `lib/services/database_service.dart`
**Rôle** : Gestion de la base de données Hive (CRUD pour tous les modèles)

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `DatabaseService.init()` | 18-25 | Initialisation de la base Hive |
| `getProjetById()` | ~45 | Récupère un projet par son ID |
| `getSystemesByProjetId()` | ~65 | Récupère les systèmes d'un projet |
| `getPompesBySystemeId()` | ~85 | Récupère les pompes d'un système |
| `insertProjet()` / `updateProjet()` | ~105-130 | Création/Mise à jour d'un projet |
| `deleteProjet()` | ~150 | Suppression d'un projet (cascade) |

---

### 3. `lib/services/calcul_service.dart`
**Rôle** : Calculs principaux de consommation et d'économies

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `calculerDonnees10AnsAvecPompes()` | ~15-100 | **Calcul principal** : consommation, coûts, économies sur 10 ans |
| `calculerConsommationAnnuel()` | ~20 | Consommation annuelle d'une pompe |
| `calculerCoutAnnuel()` | ~35 | Coût énergétique annuel |
| `calculerROI()` | ~80 | Retour sur investissement |

---

## 🎨 **ÉCRANS** (UI et interactions)

### 4. `lib/screens/home_screen.dart`
**Rôle** : Écran d'accueil avec navigation vers les projets

| Fonction/Éléments | Lignes | Description |
|-------------------|--------|-------------|
| `HomeScreen` | 6-12 | Widget principal |
| `_HomeScreenState` | 14-106 | État de l'écran |
| `build()` | 17-105 | Construction de l'UI (boutons projets, debug, settings) |
| Bouton Settings | 22-30 | Accès aux paramètres via `SettingsDialog.show()` |

---

### 5. `lib/screens/resultat/resultat_screen.dart` ⭐ **Cœur de l'application**
**Rôle** : Écran de comparatif avec graphiques et calculs détaillés

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `_ResultatScreenState` | 32-... | État principal |
| `_loadData()` | 253-460 | **Chargement des données** : projets, systèmes, pompes, calculs |
| `_buildSystemeCard()` | 916-940 | **Carte de résumé** : Ancien/Nouveau système avec moyennes |
| `_getConsommationScale()` | 567-578 | **Scaling automatique** : détermine le multiplicateur (1000 max) |
| `_buildGraphiqueConsommationAvecScale()` | 590-616 | **Graphique consommation** : applique le scaling aux spots |
| `_buildGraphiqueFromSpots()` | 103-250 | Construction générique d'un graphique LineChart |
| `_buildDataTable()` | 968-1100 | **Tableau comparatif** : données année par année |
| `_calculerP1TotaleSystemeAvecDetail()` | 569-656 | Calcul détaillé de P1 avec rendements pompe/moteur |
| `_calculerMuMoyenSysteme()` | 664-690 | **Calcul du rendement global** (produit des rendements) |
| `_buildRoiCard()` | 1102-1130 | Carte du Retour sur Investissement |

> **⚠️ Points clés modifiés récemment** :
> - Ligne **573-578** : `_getConsommationScale()` - multiplicateur max = 1000
> - Ligne **916-940** : `_buildSystemeCard()` - consommation cumulée + moyennes
> - Ligne **395-413** : Calcul des consommations cumulées

---

### 6. `lib/screens/projet/projet_*.dart`
**Rôle** : Gestion des projets (CRUD)

| Fichier | Lignes | Description |
|---------|--------|-------------|
| `projet_list_screen.dart` | - | Liste des projets |
| `projet_detail_screen.dart` | ~347 | Détails d'un projet (utilise `Table.fromTextArray` - *déprécié*) |
| `projet_create_screen.dart` | - | Création d'un projet |

---

### 7. `lib/screens/systeme/systeme_form_screen.dart`
**Rôle** : Formulaire de système

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `SystemeFormScreen` | - | Formulaire de création/édition |
| Validation | ~ | Vérification des champs |

---

### 8. `lib/screens/systeme/pompe_form_screen.dart`
**Rôle** : Formulaire de pompe

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `PompeFormScreen` | - | Formulaire avec champs techniques (débit, HMT, etc.) |

---

## 🧩 **WIDGETS** (Composants réutilisables)

### 9. `lib/widgets/settings_dialog.dart`
**Rôle** : Dialogue unifié pour les paramètres de l'application

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `SettingsDialog.show()` | 5-100 | **Affiche le dialogue** avec paramètres globaux |
| Paramètres gérés | - | Limite années, coût énergie, perte rendement |

> **✨ Bonnes pratiques** : Ce widget centralise la logique UI des paramètres, évitant la duplication (anciennement dans `home_screen.dart` et `resultat_screen.dart`).

---

## 🛠️ **UTILITAIRES** (Helpers et outils)

### 10. `lib/utils/error_handler.dart`
**Rôle** : Gestion centralisée des erreurs

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `showSnackBar()` | ~15 | Affiche une notification (SnackBar) |
| `showAlert()` | ~30 | Affiche une alerte (AlertDialog) |

---

### 11. `lib/utils/decimation.dart`
**Rôle** : Optimisation des graphiques (réduction du nombre de points)

| Fonction | Lignes | Description |
|----------|--------|-------------|
| `computeDownsampleSerialized()` | - | Algorithme LTTB pour réduire les points des graphiques |

---

### 12. `lib/utils/app_variables.dart`
**Rôle** : Variables globales et constantes

| Variable | Type | Description |
|----------|------|-------------|
| `kPrimaryColor` | `Color` | Couleur principale de l'app |
| `kSecondaryColor` | `Color` | Couleur secondaire |

---

### 13. `lib/utils/hive_init*.dart`
**Rôle** : Initialisation de Hive pour différentes plateformes

| Fichier | Plateforme | Description |
|---------|-----------|-------------|
| `hive_init.dart` | - | Initialisation générique |
| `hive_init_io.dart` | Android/iOS | Initialisation pour mobile |
| `hive_init_stub.dart` | Web | Stub pour le web |

---

## 📚 **MODÈLES** (Modèles de données Hive)

### 14-18. `lib/models/*.dart` (et fichiers `.g.dart` générés)

| Fichier | Rôle | Champs principaux |
|---------|------|-------------------|
| `pompe.dart` | Modèle Pompe | `id`, `debit`, `hmt`, `rendementInitialPompe/Moteur`, `heuresFonctionnement`, `energieSpecifique` |
| `systeme.dart` | Modèle Système | `id`, `nom`, `coutInvestissementTotal`, `anneeInstallation` |
| `projet.dart` | Modèle Projet | `id`, `nomSite`, `dateCreation`, `description` |
| `contact.dart` | Modèle Contact | `id`, `nom`, `email`, `telephone` |

> **⚠️ Note** : Les fichiers `.g.dart` sont générés automatiquement par Hive. **Ne pas modifier manuellement**.

---

## 🎯 **Fonctions Clés par Fonctionnalité**

### Calculs Principaux
| Besoin | Fonction | Fichier | Lignes |
|--------|----------|--------|--------|
| Consommation annuelle | `calculerConsommationAnnuel()` | `calcul_service.dart` | ~20 |
| Coût énergétique | `calculerCoutAnnuel()` | `calcul_service.dart` | ~35 |
| P1 avec détails | `_calculerP1TotaleSystemeAvecDetail()` | `resultat_screen.dart` | 569-656 |
| Rendement global | `_calculerMuMoyenSysteme()` | `resultat_screen.dart` | 664-690 |

### Graphiques
| Besoin | Fonction | Fichier | Lignes |
|--------|----------|--------|--------|
| Graphique générique | `_buildGraphiqueFromSpots()` | `resultat_screen.dart` | 103-250 |
| Graphique consommation | `_buildGraphiqueConsommationAvecScale()` | `resultat_screen.dart` | 590-616 |
| Scaling automatique | `_getConsommationScale()` | `resultat_screen.dart` | 567-578 |

### UI Réutilisable
| Besoin | Widget | Fichier | Lignes |
|--------|--------|--------|--------|
| Dialogue paramètres | `SettingsDialog.show()` | `widgets/settings_dialog.dart` | 5-100 |

---

## 🔧 **Récentes Modifications Importantes**

| Date | Fichier | Modification | Lignes |
|------|---------|--------------|--------|
| 17/09/2026 | `resultat_screen.dart` | **Rendement global = produit** (pas moyenne) | 676-677 |
| 17/09/2026 | `resultat_screen.dart` | **Consommations cumulées** dans les graphiques | 395-450 |
| 17/09/2026 | `resultat_screen.dart` | **Scaling automatique** des graphiques | 567-616 |
| 17/09/2026 | `resultat_screen.dart` | **Cartes système** : moyennes sur 10 ans | 916-940 |
| 17/09/2026 | `settings_dialog.dart` | **Création** : dialogue centralisé | - |
| 17/09/2026 | `home_screen.dart` | Suppression duplication code | 103-217 |
| 17/09/2026 | `resultat_screen.dart` | Suppression duplication code | 644-759 |
| 18/09/2026 | `resultat_screen.dart` | **Scaling automatique** des coûts sur 10 ans (même logique que consommation) | 618-665 |
| 18/09/2026 | `resultat_screen.dart` | **Padding des labels Y** : écart de 8px pour meilleure lisibilité | 178-199 |
| 18/09/2026 | `resultat_screen.dart` | **Origine Y à 0** pour graphique consommation (`forceMinYToZero`) | 103-142 |

---

## 💡 **Conseils pour les Contributeurs**

### 1. **Architecture à respecter**
- ✅ **Services** : Logique métier et persistance
- ✅ **Screens** : UI et interactions utilisateur
- ✅ **Widgets** : Composants réutilisables
- ✅ **Models** : Définition des données (Hive)
- ✅ **Utils** : Fonctions utilitaires génériques

### 2. **Bonnes pratiques déjà en place**
- Utilisation de **`SettingsService`** comme singleton pour les paramètres globaux
- **Séparation des responsabilités** : calculs dans `CalculService`, UI dans les screens
- **Centralisation du code** : évitez la duplication (ex: `SettingsDialog`)

### 3. **À éviter**
- ❌ **Duplication de code** : Exemple corrigé : `SettingsDialog` remplaçant les fonctions dupliquées dans `home_screen.dart` et `resultat_screen.dart`
- ❌ **Calculs dans l'UI** : Préférez les services (`CalculService`) pour la logique
- ❌ **Variables globales brutes** : Utilisez `SettingsService` pour la persistance

### 4. **Points d'attention**
- ⚠️ **`Table.fromTextArray`** est déprécié (ligne 347 de `projet_detail_screen.dart`) → À remplacer par `TableHelper.fromTextArray()`
- ⚠️ **`_calculerP1TotaleSysteme`** n'est pas utilisé (ligne 688 de `resultat_screen.dart`) → Peut être supprimé
- ⚠️ **`_generateNewId`** n'est pas utilisé (ligne 31 de `database_service.dart`) → Peut être supprimé

---

## 📞 **Contact & Support**

Pour toute question ou suggestion concernant cette architecture, n'hésitez pas à ouvrir une **Issue** ou un **Pull Request** sur le dépôt.

---

*Document généré pour faciliter le fork et la maintenance du projet WUECT*
