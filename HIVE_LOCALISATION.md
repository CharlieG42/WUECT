# Localisation de la base de données Hive

Ce fichier explique où se trouvent les données Hive selon la plateforme utilisée.

## 📁 **Localisation par plateforme**

### Windows (Desktop)
```
%LOCALAPPDATA%\<package_name>\app_data\hive\<box_name>
```
Exemple pour votre application :
```
C:\Users\<VotreUtilisateur>\AppData\Local\wu_ect\app_data\hive\contacts
C:\Users\<VotreUtilisateur>\AppData\Local\wu_ect\app_data\hive\projets
C:\Users\<VotreUtilisateur>\AppData\Local\wu_ect\app_data\hive\systemes
C:\Users\<VotreUtilisateur>\AppData\Local\wu_ect\app_data\hive\pompes
```

> **Note** : Le dossier `app_data` peut varier selon la version de Hive. Cherchez simplement un dossier `hive` dans le répertoire de l'application.

### macOS
```
~/Library/Application Support/<package_name>/hive/<box_name>
```

### Linux
```
~/.local/share/<package_name>/hive/<box_name>
```

### Android
```
/data/data/<package_name>/app_flutter/hive/<box_name>
```

> **Note** : Ce dossier n'est accessible que via un appareil rooté ou via Android Studio Device File Explorer.

### iOS
```
<Application Documents Directory>/hive/<box_name>
```

### Web (Chrome/Firefox/Edge)
**⚠️ ATTENTION : Les données sont stockées dans IndexedDB du navigateur et peuvent être SUPPRIMÉES quand l'onglet est fermé !**

#### Pour voir les données dans Chrome :
1. Ouvrez Chrome DevTools (**F12** ou **Ctrl+Shift+I**)
2. Allez dans l'onglet **Application**
3. Dans le menu de gauche, sélectionnez **IndexedDB**
4. Vous verrez une base de données nommée quelque chose comme `hive_<hash>`
5. Développez-la pour voir les différentes `object stores` (contacts, projets, systemes, pompes)

> **⚠️ PROBLÈME CONNU** : Chrome peut nettoyer IndexedDB quand :
> - L'onglet est fermé
> - Le navigateur est redémarré
> - L'espace de stockage est insuffisant
> - L'utilisateur utilise le mode navigation privée

#### Solution pour le Web :
- **Ne fermez pas l'onglet** pendant votre session de travail
- Utilisez `flutter run -d windows` ou `flutter run -d macos` pour le développement (les données seront persistantes)
- Implémentez un système d'export/import JSON (disponible via l'écran Debug)

---

## 🔧 **Accéder à l'écran Debug dans l'application**

Dans l'application, vous pouvez accéder à un écran de visualisation de la base de données :

1. Sur l'écran d'accueil, cliquez sur l'icône **💾** (Storage) en haut à droite
2. Vous verrez un tableau récapitulatif de toutes les données
3. Utilisez le bouton **"Forcer sauvegarde test"** pour tester l'écriture
4. Utilisez le bouton **🔄** pour rafraîchir les données

---

## 🛠 **Dépannage**

### "Les contacts ne sont pas sauvegardés sur Chrome"
→ C'est normal. Chrome nettoie IndexedDB. Utilisez Windows/ macOS/Linux pour le développement.

### "Le DropdownButton affiche une erreur"
→ Vérifiez que le contact sélectionné existe toujours dans la base via l'écran Debug.

### "L'application demande de sélectionner un contact alors qu'il est déjà sélectionné"
→ Rechargez la page ou vérifiez que `_selectedContactId` est bien dans la liste des contacts.

---

## 📊 **Structure des boxes Hive**

| Box Name | Type | Contenu |
|----------|------|---------|
| `contacts` | `Contact` | Liste des clients et contacts |
| `projets` | `Projet` | Liste des projets avec référence au contact |
| `systemes` | `Systeme` | Systèmes de pompage liés à un projet |
| `pompes` | `Pompe` | Pompes liées à un système |

Chaque box contient des objets sérialisés avec leurs champs respectifs.
