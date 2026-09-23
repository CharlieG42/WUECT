# WUECT - Référence des Tags pour Template de Rapport

> **Version** : 1.1  
> **Date** : 22/09/2026  
> **Format** : PDF avec tags à remplacer

---

## ⚠️ **État actuel de l'implémentation**

Ce fichier documente un **format de tags prévu**, mais **aucun mécanisme de remplacement de tags n'est implémenté dans le code actuellement**. Ni `PdfExportService` (`lib/utils/exportPDF.dart`, utilisé par l'écran Résultats) ni `RapportService` (`lib/services/rapport_service.dart`, non appelé depuis aucun écran) ne lisent `template_ec.pptx`/`template_ec.pdf` ni ne remplacent de tags `{{...}}` : les deux construisent le PDF "en dur" avec des widgets `pw.*`, exactement comme le recommande la section *Limitations* plus bas dans ce document.

Concrètement :
- Le contenu ci-dessous doit être vu comme un **cahier des charges / une liste de correspondance** pour quelqu'un qui implémenterait un jour le remplacement de tags — pas comme une fonctionnalité disponible aujourd'hui.
- `rapport_service.dart` a l'air d'être une ébauche parallèle à `exportPDF.dart` : les deux génèrent un rapport PDF complet, avec un contenu différent, mais aucun des deux ne lit de template. Vaut le coup de vérifier si l'un des deux est encore utile, ou si `RapportService` peut être supprimé pour éviter la confusion.

---

## 📌 **Instructions d'utilisation**

1. **Créer votre template** dans `assets/templates/template_ec.pptx` (ou .docx)
2. **Insérer les tags** là où les données doivent apparaître (ex: `{{PROJET_NOM}}`)
3. **Pour les images** : Utiliser des placeholders nommés (ex: un rectangle nommé "GRAPHIQUE_COUT")
4. **Exporter en PDF** afin que le code flutter puisse modifier les tags
5. **Le code Flutter** remplacera automatiquement les tags par les valeurs réelles

---

## 📊 **Tags Disponibles**

### 🏢 **Projet**
| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{PROJET_NOM}}` | Nom du projet | Texte | "Projet WUECT 2026" |
| `{{PROJET_DATE}}` | Date de création | Date (DD/MM/YYYY) | "22/09/2026" |
| `{{PROJET_COUT_ENERGIE}}` | Coût de l'énergie | €/kWh (2 décimales) | "0,15 €/kWh" |
| `{{PROJET_AUGMENTATION_ENERGIE}}` | Taux d'augmentation annuel | % (1 décimale) | "3,5 %" |
| `{{PROJET_PERTE_RENDEMENT}}` | Taux de perte de rendement | % (1 décimale) | "2,0 %" |
| `{{PROJET_DUREE_ETUDE}}` | Durée de l'étude | Années | "15" |

---

### 👤 **Client & Contact**
| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{CLIENT_NOM}}` | Nom du client (raison sociale / site) | Texte | "Camping Les Pins" |
| `{{CONTACT_NOM}}` | Nom de la personne contact chez le client | Texte | "Jean Dupont" |
| `{{CONTACT_EMAIL}}` | Email du contact | Texte | "j.dupont@example.com" |
| `{{CONTACT_MOBILE}}` | Téléphone mobile du contact | Texte | "06 12 34 56 78" |

---

### 🏭 **Systèmes**

#### Système Ancien
| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{SYSTEME_ANCIEN_NOM}}` | Nom du système ancien | Texte | "Système Existant" |
| `{{SYSTEME_ANCIEN_INVESTISSEMENT}}` | Coût d'investissement | € (0 décimales) | "100 000 €" |

#### Système Nouveau
| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{SYSTEME_NOUVEAU_NOM}}` | Nom du système nouveau | Texte | "Système Optimisé" |
| `{{SYSTEME_NOUVEAU_INVESTISSEMENT}}` | Coût d'investissement | € (0 décimales) | "150 000 €" |
| `{{SYSTEME_NOUVEAU_ECONOMIE_INVESTISSEMENT}}` | Économie d'investissement | € (0 décimales) | "-50 000 €" |

---

### 🔧 **Pompes (caractéristiques par système)**

> Un système peut contenir plusieurs pompes. Comme pour les données année par
> année, utilisez un index **j** (1 à N) pour désigner la j-ième pompe du
> système Ancien ou Nouveau (ex: `{{POMPE_ANCIEN_1_MARQUE}}`,
> `{{POMPE_NOUVEAU_2_HMT}}`...).

| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_MARQUE}}` | Marque de la pompe j | Texte | "Grundfos" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_MODELE}}` | Modèle de la pompe j | Texte | "CR 32-4" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_PUISSANCE_NOMINALE}}` | Puissance nominale plaque moteur | kW (2 décimales) | "11,00 kW" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_DEBIT}}` | Débit nominal | m³/h (2 décimales) | "45,00 m³/h" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_HMT}}` | Hauteur manométrique totale | mCE (2 décimales) | "32,00 mCE" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_RENDEMENT_POMPE}}` | Rendement initial de la pompe | % (1 décimale) | "78,0 %" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_RENDEMENT_MOTEUR}}` | Rendement initial du moteur | % (1 décimale) | "91,0 %" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_ANNEE_INSTALLATION}}` | Année d'installation | Entier | "2015" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_HEURES_FONCTIONNEMENT}}` | Heures de fonctionnement / an | h (0 décimale) | "6 000 h" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_P1_CALCULEE}}` | Puissance utile P1 calculée (débit×HMT/rendements) | kW (2 décimales) | "9,80 kW" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_P1_ESTIMEE}}` | Puissance P1 corrigée manuellement (si renseignée) | kW (2 décimales) | "10,20 kW" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_ENERGIE_SPECIFIQUE}}` | Énergie spécifique (puissance utilisée / débit) | kW/(m³/h) (4 décimales) | "0,2178" |
| `{{POMPE_[ANCIEN\|NOUVEAU]_j_COUT_INVESTISSEMENT}}` | Coût d'investissement de la pompe | € (0 décimale) | "8 500 €" |

---

### 📈 **Données Années par Année**

> ⚠️ **Important** : Pour les données annuelles, utilisez l'index de l'année (1 à N)

#### Pour chaque année **i** (de 1 à `{{PROJET_DUREE_ETUDE}}`)

| Tag | Description | Format | Exemple (Année 1) |
|-----|-------------|--------|------------------|
| `{{ANNEE_i}}` | Numéro de l'année | Entier | "1" |
| `{{CONSOMMATION_ANCIEN_i}}` | Consommation ancienne année i | kWh (0 décimales) | "50 000 kWh" |
| `{{CONSOMMATION_NOUVEAU_i}}` | Consommation nouvelle année i | kWh (0 décimales) | "45 000 kWh" |
| `{{ECONOMIE_KWH_i}}` | Économie en kWh année i | kWh (0 décimales) | "5 000 kWh" |
| `{{COUT_ANCIEN_i}}` | Coût ancien année i | € (2 décimales) | "7 500,00 €" |
| `{{COUT_NOUVEAU_i}}` | Coût nouveau année i | € (2 décimales) | "6 750,00 €" |
| `{{ECONOMIE_EURO_i}}` | Économie en € année i | € (2 décimales) | "750,00 €" |
| `{{CUMUL_KWH_i}}` | Économie cumulée kWh année i | kWh (0 décimales) | "5 000 kWh" |
| `{{CUMUL_EURO_i}}` | Économie cumulée € année i | € (2 décimales) | "750,00 €" |

#### Exemple de tableau dans le template :
```
| Année | Conso Ancien | Conso Nouveau | Économie kWh | Coût Ancien | Coût Nouveau | Économie € | Cumul € |
|-------|--------------|--------------|--------------|-------------|--------------|------------|---------|
| {{ANNEE_1}} | {{CONSOMMATION_ANCIEN_1}} | {{CONSOMMATION_NOUVEAU_1}} | {{ECONOMIE_KWH_1}} | {{COUT_ANCIEN_1}} | {{COUT_NOUVEAU_1}} | {{ECONOMIE_EURO_1}} | {{CUMUL_EURO_1}} |
| {{ANNEE_2}} | {{CONSOMMATION_ANCIEN_2}} | {{CONSOMMATION_NOUVEAU_2}} | {{ECONOMIE_KWH_2}} | {{COUT_ANCIEN_2}} | {{COUT_NOUVEAU_2}} | {{ECONOMIE_EURO_2}} | {{CUMUL_EURO_2}} |
...
```

---

### 💰 **Données Globales (Totaux)**

| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{TOTAL_COUT_ANCIEN}}` | Coût total ancien (invest + énergie) | € (0 décimales) | "250 000 €" |
| `{{TOTAL_COUT_NOUVEAU}}` | Coût total nouveau (invest + énergie) | € (0 décimales) | "200 000 €" |
| `{{TOTAL_ECONOMIE}}` | Économie totale | € (0 décimales) | "50 000 €" |
| `{{SEUIL_RENTABILITE}}` | Année de basculement | Année | "5" |
| `{{TAUX_RENTABILITE}}` | Taux de rentabilité | % (2 décimales) | "12,50 %" |

---

### 📊 **Graphiques (Images)**

Les graphiques sont capturés comme images et peuvent être insérés dans le rapport.

| Placeholder | Description | Format |
|-------------|-------------|--------|
| `GRAPHIQUE_CONSOMMATION` | Graphique de consommation énergétique | Image PNG |
| `GRAPHIQUE_COUT` | Graphique de coût sur N ans | Image PNG |

#### Comment intégrer les images dans PowerPoint :
1. Créer un rectangle ou une zone de texte avec le nom exact du placeholder
2. Le code remplaceras cette zone par l'image du graphique
3. **Alternative** : Utiliser un tag comme `{{IMAGE_GRAPHIQUE_COUT}}` et le code insérera l'image

---

### 📅 **Date et Métadonnées**

| Tag | Description | Format | Exemple |
|-----|-------------|--------|---------|
| `{{DATE_RAPPORT}}` | Date de génération du rapport | DD/MM/YYYY | "22/09/2026" |
| `{{HEURE_RAPPORT}}` | Heure de génération | HH:MM | "15:30" |
| `{{NOM_UTILISATEUR}}` | Nom de l'utilisateur | Texte | "Jean Dupont" |

---

## 🎨 **Exemple de Structure de Rapport**

### Page 1 : Page de garde
```
{{PROJET_NOM}}
Étude Comparative Économique
{{DATE_RAPPORT}}
```

### Page 2 : Synthèse
```
Projet : {{PROJET_NOM}}
Client : {{CLIENT_NOM}}
Contact : {{CONTACT_NOM}} ({{CONTACT_EMAIL}} / {{CONTACT_MOBILE}})
Durée : {{PROJET_DUREE_ETUDE}} ans

Système Ancien : {{SYSTEME_ANCIEN_NOM}}
Investissement : {{SYSTEME_ANCIEN_INVESTISSEMENT}}
Pompe 1 : {{POMPE_ANCIEN_1_MARQUE}} {{POMPE_ANCIEN_1_MODELE}} ({{POMPE_ANCIEN_1_PUISSANCE_NOMINALE}})

Système Nouveau : {{SYSTEME_NOUVEAU_NOM}}
Investissement : {{SYSTEME_NOUVEAU_INVESTISSEMENT}}
Pompe 1 : {{POMPE_NOUVEAU_1_MARQUE}} {{POMPE_NOUVEAU_1_MODELE}} ({{POMPE_NOUVEAU_1_PUISSANCE_NOMINALE}})

Économie sur {{PROJET_DUREE_ETUDE}} ans : {{TOTAL_ECONOMIE}}
Seuil de rentabilité : Année {{SEUIL_RENTABILITE}}
```

### Page 3 : Détails Annuels
```
| Année | Coût Ancien | Coût Nouveau | Économie |
|-------|-------------|--------------|----------|
| {{ANNEE_1}} | {{COUT_ANCIEN_1}} | {{COUT_NOUVEAU_1}} | {{ECONOMIE_EURO_1}} |
| {{ANNEE_2}} | {{COUT_ANCIEN_2}} | {{COUT_NOUVEAU_2}} | {{ECONOMIE_EURO_2}} |
...
```

### Page 4 : Graphiques
```
[Insérer image : GRAPHIQUE_CONSOMMATION]
[Insérer image : GRAPHIQUE_COUT]
```

---

## 🔧 **Implémentation Technique**

### Prérequis
1. Placer votre template dans : `assets/templates/template_ec.pptx`
2. Utiliser les tags exacts (respecter la casse)
3. Pour les images, prévoir des zones dédiées

### Limitations
- **PPTX** : Flutter n'a pas de support natif pour modifier les fichiers PowerPoint
- **Solution recommandée** : Utiliser un format compatible comme PDF ou DOCX
- **Alternative** : Générer le rapport directement en PDF depuis Flutter

### Recommandation
Pour une intégration fluide avec Flutter, nous recommandons :
1. **Créer un template PowerPoint** pour le design
2. **Exporter en PDF** 
3. **Utiliser la library `pdf`** de Flutter pour générer le rapport final avec les tags remplacés

---

## 📞 **Support**

Pour toute question sur les tags ou l'implémentation, contacter l'équipe de développement.

---

*Généré automatiquement par WUECT - V1.1*