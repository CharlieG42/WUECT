# WU_ECT - Comparatifs Énergétiques de Systèmes de Pompage

**Version:** 0.0.002  
**Technologie:** Flutter  
**Plateformes cibles:** Windows (prioritaire), Android (prioritaire), iOS (secondaire)  
**Base de données:** SQLite (via sqflite)  

---

## 📋 Table des Matières

- [🎯 Description](#-description)
- [✨ Fonctionnalités](#-fonctionnalités)
- [🏗️ Architecture](#-architecture)
- [📊 Modèles de Données](#-modèles-de-données)
- [🔢 Formules de Calcul](#-formules-de-calcul)
- [📁 Structure du Projet](#-structure-du-projet)
- [🛠️ Prérequis](#-prérequis)
- [🚀 Installation](#-installation)
- [📱 Utilisation](#-utilisation)
- [📈 Exemple de Workflow](#-exemple-de-workflow)
- [🔧 Dépendances](#-dépendances)
- [🎨 Captures d'Écran](#-captures-décran)
- [📝 Journal des Versions](#-journal-des-versions)
- [🔜 Prochaines Étapes](#-prochaines-étapes)

---

## 🎯 Description

**WU_ECT** est une application Flutter conçue pour réaliser des **comparatifs énergétiques** entre différents systèmes de pompage. Elle permet aux utilisateurs de modéliser des projets comporant plusieurs systèmes (ancien et nouveau), chacun constitués d'une ou plusieurs pompes, puis de visualiser les économies potentielles sur 10 ans.

L'application calcule automatiquement :
- La consommation annuelle en kWh de chaque système
- Le coût énergétique annuel en €
- Le ROI (Retour sur Investissement)
- Des graphiques comparatifs sur 10 ans

---

## ✨ Fonctionnalités

### Gestion des Données
- ✅ **Création/Modification/Suppression** de projets
- ✅ **Gestion des contacts** (clients, emails, mobiles)
- ✅ **Ajout de systèmes** (Ancien Système / Nouveau Système)
- ✅ **Ajout de pompes** à un système (1 ou plusieurs)
- ✅ **Base de données SQLite** embarquée avec relations entre tables
- ✅ **Suppression en cascade** des données liées

### Calculs Énergétiques
- ✅ Calcul de la **perte de rendement** en fonction de l'année d'installation
- ✅ Calcul de la **puissance réelle** de chaque pompe
- ✅ Calcul de la **consommation annuelle** par pompe et par système
- ✅ **Projection sur 10 ans** avec augmentation annuelle du coût de l'énergie
- ✅ Calcul du **ROI** entre l'ancien et le nouveau système

### Visualisation
- ✅ Graphique **"Consommation Énergétique (kWh) sur 10 ans"**
- ✅ Graphique **"Coût Énergétique (€) sur 10 ans"**
- ✅ Affichage des données de comparatif (économies, ROI, etc.)

---

## 🏗️ Architecture

L'application suit une architecture **MVVM (Model-View-ViewModel)** simplifiée avec séparation claire des responsabilités :

```
lib/
├── models/          # Modèles de données (entités métiers)
│   ├── contact.dart
│   ├── pompe.dart
│   ├── projet.dart
│   └── systeme.dart
│
├── services/        # Services (logique métier et accès aux données)
│   ├── calcul_service.dart   # Calculs énergétiques et ROI
│   └── database_service.dart # Gestion SQLite (CRUD)
│
└── screens/         # Interface utilisateur (Flutter Widgets)
    ├── contact/
    │   ├── contact_form_screen.dart
    │   └── contact_list_screen.dart
    ├── projet/
    │   ├── projet_create_screen.dart
    │   ├── projet_detail_screen.dart
    │   └── projet_list_screen.dart
    ├── systeme/
    │   ├── pompe_form_screen.dart
    │   └── systeme_form_screen.dart
    ├── resultat/
    │   └── resultat_screen.dart
    └── home_screen.dart
```

---

## 📊 Modèles de Données

### Schéma de la Base de Données

```
┌─────────────────────┐       ┌─────────────────────┐
│      Contacts        │       │       Projets        │
├─────────────────────┤       ├─────────────────────┤
│ id (PK)             │       │ id (PK)             │
│ client              │       │ nomSite            │
│ nom                 │◄──────│ contactId (FK)     │
│ email               │       │ coutEnergie       │
│ mobile              │       │ pourcentageAugmentationEnergie
└─────────────────────┘       │ percentagePerteRendement
                           └────────────┬────────┘
                                            │
                                            ▼
┌─────────────────────┐       ┌─────────────────────┐
│      Systemes        │       │       Pompes         │
├─────────────────────┤       ├─────────────────────┤
│ id (PK)             │       │ id (PK)             │
│ projetId (FK)       │◄──────│ systemeId (FK)     │
│ nom                 │       │ marque              │
│ coutInvestissementTotal │   │ modele              │
└─────────────────────┘       │ puissanceNominale   │
                            │ debitNominal        │
                            │ hmtNominale         │
                            │ rendementInitialPompe
                            │ rendementInitialMoteur
                            │ anneeInstallation   │
                            │ heuresFonctionnement│
                            │ coutInvestissement  │
                            └─────────────────────┘
```

### Détail des Modèles

#### 📌 Contact
| Champ | Type | Description |
|-------|------|-------------|
| id | INTEGER (PK) | Identifiant unique |
| client | TEXT | Nom du client |
| nom | TEXT | Nom du contact |
| email | TEXT | Adresse email du contact |
| mobile | TEXT | Numéro de téléphone du contact |

#### 📌 Projet
| Champ | Type | Description |
|-------|------|-------------|
| id | INTEGER (PK) | Identifiant unique |
| nomSite | TEXT | Nom du site / projet |
| contactId | INTEGER (FK) | Référence au contact associé |
| coutEnergie | REAL | Coût de l'énergie en €/kWh |
| pourcentageAugmentationEnergie | REAL | % d'augmentation annuelle du coût de l'énergie |
| percentagePerteRendement | REAL | µCoef - % de perte de rendement annuel des matériels |

#### 📌 Système
| Champ | Type | Description |
|-------|------|-------------|
| id | INTEGER (PK) | Identifiant unique |
| projetId | INTEGER (FK) | Référence au projet |
| nom | TEXT | "Ancien Système" ou "Nouveau Système" |
| coutInvestissementTotal | REAL | Somme des coûts d'investissement (€) |

#### 📌 Pompe
| Champ | Type | Description |
|-------|------|-------------|
| id | INTEGER (PK) | Identifiant unique |
| systemeId | INTEGER (FK) | Référence au système |
| marque | TEXT | Marque de la pompe |
| modele | TEXT | Modèle de la pompe |
| puissanceNominale | REAL | Puissance nominale en kW |
| debitNominal | REAL | Débit nominal en m³/h |
| hmtNominale | REAL | HMT nominale en mce (mètres colonne d'eau) |
| rendementInitialPompe | REAL | Rendement initial de la pompe (%) |
| rendementInitialMoteur | REAL | Rendement initial du moteur (%) |
| anneeInstallation | INTEGER | Année d'installation |
| heuresFonctionnement | INTEGER | Nombre d'heures de fonctionnement par an |
| coutInvestissement | REAL | Coût d'investissement (€) |

---

## 🔢 Formules de Calcul

### 1. Perte de Rendement (µPerte)
Calcule la dégradation du rendement en fonction du temps :

```
µPerte = (1 - µCoef)^(Année en cours - Année d'installation)
```

Où :
- **µCoef** = `percentagePerteRendement / 100` (ex: 1% → 0.01)
- **Année en cours** = année actuelle
- **Année d'installation** = année de mise en service de la pompe

### 2. Rendements Corrigés
```
µPompeCorrigé = rendementInitialPompe × µPerte / 100
µMoteurCorrigé = rendementInitialMoteur × µPerte / 100
```

### 3. Puissance par Pompe (kW)
```
Puissance = (Débit × HMT) / (367 × µPompeCorrigé × µMoteurCorrigé)
```

### 4. Consommation Annuelle par Pompe (kWh)
```
Consommation = Puissance × heuresFonctionnement
```

### 5. Consommation Annuelle du Système (kWh)
```
ConsommationSystème = Σ(Consommation de toutes les pompes du système)
```

### 6. Coût Énergétique Annuel (€)
```
Coût = ConsommationSystème × coutEnergie
```

### 7. Projection sur 10 Ans
Chaque année, le coût de l'énergie augmente :
```
coutEnergie_Année_N = coutEnergie_Année_N-1 × (1 + pourcentageAugmentationEnergie / 100)
```

### 8. ROI (Retour sur Investissement)
```
ÉconomieTotale = Σ(CoûtAncienSystème) - Σ(CoûtNouveauSystème) sur 10 ans
DeltaInvestissement = coutInvestissementNouveau - coutInvestissementAncien
ROI (années) = DeltaInvestissement / (ÉconomieTotale / 10)
```

---

## 📁 Structure du Projet

```
wu_ect/
├── android/          # Configuration Android
├── ios/              # Configuration iOS
├── windows/          # Configuration Windows
├── web/              # Configuration Web
├── lib/
│   ├── main.dart          # Point d'entrée de l'application
│   ├── models/
│   │   ├── contact.dart    # Modèle Contact
│   │   ├── pompe.dart      # Modèle Pompe
│   │   ├── projet.dart     # Modèle Projet
│   │   └── systeme.dart    # Modèle Système
│   ├── screens/
│   │   ├── contact/
│   │   │   ├── contact_form_screen.dart  # Formulaire Contact
│   │   │   └── contact_list_screen.dart  # Liste Contacts
│   │   ├── projet/
│   │   │   ├── projet_create_screen.dart  # Création Projet
│   │   │   ├── projet_detail_screen.dart  # Détail Projet
│   │   │   └── projet_list_screen.dart   # Liste Projets
│   │   ├── systeme/
│   │   │   ├── pompe_form_screen.dart    # Formulaire Pompe
│   │   │   └── systeme_form_screen.dart  # Formulaire Système
│   │   ├── resultat/
│   │   │   └── resultat_screen.dart       # Résultats & Graphiques
│   │   └── home_screen.dart      # Écran d'accueil
│   └── services/
│       ├── calcul_service.dart    # Service de calculs
│       └── database_service.dart  # Service SQLite (CRUD)
├── pubspec.yaml     # Dépendances et configuration
└── README.md        # Documentation (ce fichier)
```

---

## 🛠️ Prérequis

- **Flutter SDK** : >= 3.0.0 < 4.0.0
- **Dart SDK** : Compatible avec Flutter
- **Environnement de développement** :
  - Android Studio / VS Code avec extension Flutter
  - Emulateur Android ou appareil physique
  - Pour Windows : Configuration Flutter Desktop activée
  - Pour iOS : macOS + Xcode (optionnel pour cette version)

---

## 🚀 Installation

### 1. Cloner le dépôt
```bash
cd /chemin/vers/vos/projets
git clone [URL_DU_DEPOT]
cd wu_ect
```

### 2. Récupérer les dépendances
```bash
flutter pub get
```

### 3. Lancer l'application

#### Sur Android
```bash
flutter run -d android
```

#### Sur Windows
```bash
flutter run -d windows
```

#### Sur iOS
```bash
flutter run -d ios
```

### 4. Générer le build de production

#### Android (APK)
```bash
flutter build apk --release
# Le fichier APK se trouve dans : build/app/outputs/flutter-apk/app-release.apk
```

#### Windows (Exécutable)
```bash
flutter build windows
# L'exécutable se trouve dans : build/windows/runner/Release/
```

---

## 📱 Utilisation

### 1. Écran d'Accueil
- Liste des projets existants
- Bouton pour créer un nouveau projet
- Accès à la gestion des contacts

### 2. Gestion des Contacts
- **Lister** : Voir tous les contacts enregistrés
- **Ajouter** : Créer un nouveau contact (client, nom, email, mobile)
- **Modifier** : Éditer un contact existant
- **Supprimer** : Supprimer un contact (attention : suppression en cascade)

### 3. Gestion des Projets
#### Création d'un Projet
1. Remplir le nom du site
2. Sélectionner un contact existant ou en créer un nouveau
3. Indiquer le coût de l'énergie (€/kWh)
4. Indiquer le pourcentage d'augmentation annuelle de l'énergie
5. Indiquer le pourcentage de perte de rendement annuel (µCoef)

#### Édition d'un Projet
- Modifier les informations du projet
- Accéder à la liste des systèmes associés

### 4. Gestion des Systèmes
#### Ajout d'un Système
1. Sélectionner le type : "Ancien Système" ou "Nouveau Système"
2. Indiquer le coût d'investissement total
3. Ajouter une ou plusieurs pompes au système

#### Ajout d'une Pompe
Pour chaque pompe, renseigner :
- Marque
- Modèle
- Puissance nominale (kW)
- Débit nominal (m³/h)
- HMT nominale (mce)
- Rendement initial pompe (%)
- Rendement initial moteur (%)
- Année d'installation
- Heures de fonctionnement par an
- Coût d'investissement (€)

### 5. Résultats et Comparatifs
Une fois les 2 systèmes (Ancien + Nouveau) créés pour un projet :
- **Graphique 1** : Consommation énergétique (kWh) sur 10 ans
- **Graphique 2** : Coût énergétique (€) sur 10 ans
- **Données calculées** :
  - Consommation annuelle par système
  - Coût énergétique annuel par système
  - Économie totale sur 10 ans
  - ROI (en années)
  - Indication de rentabilité

---

## 📈 Exemple de Workflow

```
1. Créer un contact "Entreprise XYZ" avec le contact "Jean Dupont" (jean@xyz.com, 0612345678)
   
2. Créer un projet "Usine Nord" avec :
   - Contact : Jean Dupont (Entreprise XYZ)
   - Coût énergie : 0.15 €/kWh
   - Augmentation énergie : 5% par an
   - Perte rendement : 1% par an
   
3. Ajouter le système "Ancien Système" :
   - Coût investissement : 10 000 €
   - Pompe 1 : Grundfos MG-200, 20kW, 100m³/h, 50mce, 80%/90%, installée en 2015, 4000h/an
   
4. Ajouter le système "Nouveau Système" :
   - Coût investissement : 25 000 €
   - Pompe 1 : Grundfos EFF-300, 15kW, 100m³/h, 50mce, 90%/95%, installée en 2025, 4000h/an
   
5. Accéder à la vue Résultat :
   → Visualisation des graphiques sur 10 ans
   → ROI calculé : ~3.5 ans
   → Économie totale : ~12 000 € sur 10 ans
```

---

## 🔧 Dépendances

| Package | Version | Usage |
|---------|---------|------|
| flutter | SDK | Framework principal |
| sqflite | ^2.3.0 | Gestion de la base de données SQLite |
| path_provider | ^2.1.1 | Accès aux chemins de fichiers |
| path | ^1.8.3 | Manipulation des chemins |
| fl_chart | ^0.63.0 | Création des graphiques |
| intl | ^0.18.1 | Formatage international (dates, nombres) |
| provider | ^6.1.1 | Gestion d'état (State Management) |
| cupertino_icons | ^1.0.2 | Icônes iOS |

---

## 🎨 Captures d'Écran

*À ajouter lors des tests utilisateurs.*

---

## 📝 Journal des Versions

| Version | Date | Modifications |
|---------|------|----------------|
| **0.0.002** | 27/08/2026 | Mise à jour du README.md - Documentation complète du projet |
| **0.0.001** | 27/08/2026 | Version initiale - Structure de base, modèles, services, écrans |

---

## 🔜 Prochaines Étapes

### Version 0.0.003 (Priorité Élevée)
- [ ] Tests unitaires pour les services de calcul
- [ ] Tests d'intégration pour la base de données
- [ ] Validation des formulaires (champs obligatoires, formats)
- [ ] Gestion des erreurs (try/catch, messages utilisateur)

### Version 0.0.004 (Priorité Moyenne)
- [ ] Export des résultats en PDF
- [ ] Sauvegarde/Restoration de la base de données
- [ ] Recherche et filtrage dans les listes
- [ ] Tri des listes (par nom, date, etc.)

### Version 0.0.005 (Priorité Basse)
- [ ] Support iOS complet
- [ ] Thème sombre/clair
- [ ] Internationalisation (FR/EN)
- [ ] Notifications pour les rappels

### Améliorations Futures
- [ ] Import de données depuis Excel/CSV
- [ ] Synchronisation cloud (Firebase)
- [ ] Mode hors-ligne avancé
- [ ] Historique des modifications

---

## 📄 Licence

Ce projet est la propriété de [Votre Entreprise]. Tous droits réservés.

---

## 🤝 Contribution

Pour contribuer à ce projet :
1. Forker le dépôt
2. Créer une branche de fonctionnalité (`git checkout -b feature/nouvelle-fonctionnalité`)
3. Commiter vos modifications (`git commit -m 'Ajout de la fonctionnalité X'`)
4. Pousser vers la branche (`git push origin feature/nouvelle-fonctionnalité`)
5. Ouvrir une Pull Request

---

## 📞 Support

Pour toute question ou problème, contactez :
- [Votre Email]
- [Votre Téléphone]

---

*Documentation générée pour la version 0.0.002 - 27/08/2026*

