# Résultats vérifiés — Projet 2 Berka (SQL)

**Périmètre :** résultats issus des exécutions MySQL Workbench de ce projet, relevés le 16 novembre 2026. Les chiffres ci-dessous ont été communiqués et/ou montrés dans les tableaux d'exécution. Les 10 analyses principales et les six requêtes complémentaires ont été exécutées ; les tableaux complets fournis par l’utilisateur sont synthétisés sans inventer de valeurs manquantes.

## 1\. Volume et périmètre de la base

|Table métier|Lignes|
|-|-:|
|district|77|
|account|4 500|
|client|5 369|
|disp|5 369|
|card|892|
|loan|682|
|orders|6 471|
|trans|1 056 320|

Périodes : comptes ouverts du **1993-01-01** au **1997-12-29** ; prêts du **1993-07-05** au **1998-12-08** ; transactions du **1993-01-01** au **1998-12-31**.

## 2\. Statut et montants des prêts

|Statut|Sens|Prêts|Part|Montant initial des prêts problématiques|
|-|-|-:|-:|-:|
|A|Terminé, remboursé|203|29,77 %|—|
|B|Terminé, non remboursé|31|4,55 %|4 362 348,00|
|C|En cours, sain|403|59,09 %|—|
|D|En cours, en difficulté|45|6,60 %|11 217 804,00|
|**Total**||**682**|≈100 %|**15 580 152,00** (B + D)|

Le montant initial **total** des 682 prêts vaut **103 261 740,00**. La part B+D est **76 / 682 = 11,14 %** en nombre. Les 15 580 152,00 ne sont **pas** une perte constatée. Les pourcentages affichés sont arrondis.

### Durée et prêts problématiques

|Durée (mois)|Prêts|Montant moyen|Prêts B+D|Taux B+D|
|-:|-:|-:|-:|-:|
|12|131|53 635,51|11|8,40 %|
|24|138|99 217,91|17|12,32 %|
|36|130|144 048,18|15|11,54 %|
|48|138|205 592,70|16|11,59 %|
|60|145|244 450,76|17|11,72 %|

**Lecture :** le montant moyen croît avec la durée, mais le taux B+D n'augmente pas régulièrement. Pas de conclusion causale.

## 3\. Profil des titulaires à la date du prêt

|Sexe|Prêts|Âge moyen (années)|Prêts B+D|Taux B+D|
|-|-:|-:|-:|-:|
|F|348|36,5|41|11,78 %|
|M|334|38,8|35|10,48 %|

L'écart descriptif est de **1,30 point de pourcentage**. Ces deux groupes ne permettent pas, seuls, une évaluation causale ou une politique de crédit.

## 4\. Exposition par région

|Région|Prêts|Montant initial total|B+D|Taux B+D|
|-|-:|-:|-:|-:|
|West Bohemia|57|7 779 384,00|9|15,79 %|
|North Moravia|117|18 081 312,00|18|15,38 %|
|South Bohemia|60|9 374 136,00|9|15,00 %|
|Central Bohemia|90|13 985 304,00|10|11,11 %|
|East Bohemia|84|13 943 724,00|9|10,71 %|
|South Moravia|129|19 678 848,00|13|10,08 %|
|Prague|84|12 932 412,00|7|8,33 %|
|North Bohemia|61|7 486 620,00|1|1,64 %|

Les pourcentages reposent sur des tailles d'échantillons différentes. « West Bohemia la plus élevée » est un classement descriptif, pas une preuve de risque structurel.

## 5\. Soldes connus avant l'octroi des prêts

|Catégorie|Prêts|Sans solde antérieur|Solde moyen avant prêt|Montant moyen du prêt|
|-|-:|-:|-:|-:|
|Non problématique (A/C)|606|0|43 750,89|144 689,09|
|Problématique (B/D)|76|0|30 002,81|205 002,00|

Le solde est la dernière valeur enregistrée lors d'une transaction **strictement antérieure à la date** du prêt, avec départage par `trans\_id` en cas d'égalité de date. L'ordre réel des écritures d'une même journée n'est pas connu : il s'agit d'un **proxy**, non d'un solde bancaire attesté à la minute d'octroi.

## 6\. Flux et activité

* **72 mois** : janvier 1993 à décembre 1998.
* Total des entrées : **3 227 472 424,50**.
* Total des sorties : **3 030 321 135,80**.
* Flux net cumulé sur les comptes observés : **197 151 288,70** (entrées moins sorties).
* Les flux nets de **janvier et juin** sont négatifs chaque année de **1994 à 1998** dans la série exécutée.
* Exemple : **janvier 1998** compte **42 940 transactions** et un flux net de **-33 543 241,60**.

Le flux net n'est **pas** le bénéfice de la banque. La série mensuelle complète est fournie dans [`resultats/flux\_mensuels\_1993\_1998.csv`](resultats/flux_mensuels_1993_1998.csv) ; ses 72 lignes ont été vérifiées par recomptage : 1 056 320 transactions, 3 227 472 424,50 d’entrées et 3 030 321 135,80 de sorties.

### Ouvertures de comptes (cohortes annuelles)

|Année|Nouveaux comptes|Cumul|Part du total|
|-|-:|-:|-:|
|1993|1 139|1 139|25,31 %|
|1994|439|1 578|9,76 %|
|1995|661|2 239|14,69 %|
|1996|1 363|3 602|30,29 %|
|1997|898|4 500|19,96 %|

Le cumul décrit les **ouvertures** : il ne garantit pas que les comptes sont encore actifs à la fin de la période.

## 7\. Qualité des données

|Contrôle|Résultat observé|Interprétation prudente|
|-|-:|-|
|Comptes sans titulaire (`OWNER`)|0|Aucun dans la capture|
|Comptes avec plusieurs titulaires|0|Aucun dans la capture|
|Comptes avec plusieurs prêts|0|Aucun dans la capture|
|Prêts antérieurs à l'ouverture|0|Confirmé et historisé dans `quality\_log`|
|Transactions antérieures à l'ouverture|0|Aucun dans la capture|
|Cartes antérieures à l'ouverture|À confirmer|Sixième ligne non visible dans la capture|
|Opération détaillée manquante|183 114|Absence potentiellement structurelle|
|Code `k\_symbol` manquant|535 314|Ne pas imputer systématiquement|
|Banque manquante|782 812|Ne pas imputer systématiquement|
|Compte partenaire manquant|760 931|Ne pas imputer systématiquement|
|Transactions avec solde négatif|2 999|Découvert possible|
|Écarts selon `LAG()`|531 084|**Signaux méthodologiques**, pas erreurs confirmées|
|Opérations sur dates multiples, comparaisons intrajournalières incertaines|241 552|Appuie une limite du tri `trans\_id`|

Le contrôle complémentaire a trouvé **220 112 couples (compte, date)** contenant plusieurs transactions, soit **461 664 transactions** concernées.

## 8\. Montants atypiques (Z-score / IQR)

**Méthode :** analyse par compte, au moins 10 transactions par compte ; anomalies unilatérales de montants élevés (`Z > 3` ; `montant > Q3 + 1,5×IQR`, quartiles *nearest-rank*).

|Indicateur|Nombre|
|-|-:|
|Transactions éligibles|1 056 311|
|Transactions hors population éligible|9|
|Détectées par Z-score|9 293|
|Détectées par IQR|46 423|
|Détectées par les deux|9 025|
|Uniquement par Z-score|268|
|Uniquement par IQR|37 398|
|Détectées par au moins une méthode|**46 691**|

**Point important :** les scores sont relatifs aux distributions de montants des comptes, pas à des signalements de fraude. Aucun jeu de vérité terrain n'a permis de mesurer précision, rappel ou faux positifs.

## 9\. Concordance des vues

|Vérification|Table source|Vue|Statut|
|-|-:|-:|-|
|Nombre de transactions|1 056 320|1 056 320|Conforme|
|Nombre de prêts|682|682|Conforme|
|Somme des prêts|103 261 740,00|103 261 740,00|Conforme|
|Somme des entrées|3 227 472 424,50|3 227 472 424,50|Conforme|
|Somme des sorties|3 030 321 135,80|3 030 321 135,80|Conforme|

La vue `v\_account\_summary` contient 4 500 lignes, la vue `v\_loan\_360` 682 et la vue `v\_monthly\_flows` 72.

## 10\. Questions complémentaires du cahier initial (Q1–Q6)

Six requêtes SQL supplémentaires ont été exécutées depuis MySQL Workbench le 16 novembre 2026. Elles complètent les 10 analyses principales et couvrent explicitement les compétences demandées dans le projet 2.

### Q1 — Comptes et dernier solde connu par district

La requête retourne **77 districts**, sans compte dépourvu de solde connu dans la sortie examinée. Les principaux districts par nombre de comptes :

|District|Comptes|Dernier solde moyen connu|
|-|-:|-:|
|Hl.m. Praha|554|44 939,82|
|Karvina|152|46 066,27|
|Ostrava - mesto|135|43 502,01|
|Brno - mesto|128|42 446,14|
|Zlin|92|43 020,83|

**Limite :** ce n'est pas le solde moyen historique du district ; l'identification du dernier solde par compte dépend notamment de l'ordre `trans\_date, trans\_id`.

### Q2 — Prêts problématiques par district avec `HAVING`

La requête retient **65 districts** disposant d'au moins **5 prêts**. Les 12 autres sont exclus par un critère d'effectif, pas par absence de risque.

|District|Prêts|Prêts B/D|Taux B/D|
|-|-:|-:|-:|
|Strakonice|6|3|50,00 %|
|Bruntal|6|3|50,00 %|
|Opava|8|3|37,50 %|
|Kutna Hora|9|3|33,33 %|
|Beroun|6|2|33,33 %|
|Tabor|7|2|28,57 %|
|Svitavy|12|3|25,00 %|
|Brno - mesto|24|5|20,83 %|
|Hl.m. Praha|84|7|8,33 %|

Les taux les plus élevés sont calculés sur des effectifs réduits : ne pas les interpréter comme des risques régionaux établis.

### Q3 — Clients sans carte avec `LEFT JOIN`

|Sexe|Clients sans carte|
|-|-:|
|F|2 222|
|M|2 255|
|**Total**|**4 477**|

Sur les 5 369 clients, **83,39 %** ne possèdent aucune carte répertoriée ; **892** clients ont donc au moins une carte enregistrée d'après cette requête. Aucune explication sur les motifs d'absence de carte n'est disponible.

### Q4 — Top 3 des comptes de chaque district (`ROW\_NUMBER`)

**231 lignes** retournées (77 districts × 3 comptes). Exemple du district de Prague :

|Rang|Compte|Transactions|Flux brut cumulé|
|-:|-:|-:|-:|
|1|1132|414|7 386 440,30|
|2|2486|534|6 910 402,40|
|3|11013|571|6 376 283,80|

Le flux brut représente la somme des montants indépendamment du sens entrant ou sortant : ce n'est ni un solde ni un bénéfice.

### Q5 — Activité mensuelle et variation par rapport au mois précédent (`LAG`)

**72 mois**, de janvier 1993 à décembre 1998. Le premier mois n'a pas de taux de variation faute de mois antérieur. Exemples :

|Mois|Transactions|Mois précédent|Variation absolue|Variation relative|
|-|-:|-:|-:|-:|
|1994-01|9 139|5 669|+3 470|+61,21 %|
|1994-02|5 601|9 139|−3 538|−38,71 %|
|1995-01|15 493|9 795|+5 698|+58,17 %|
|1996-01|21 405|13 774|+7 631|+55,40 %|
|1997-01|33 060|21 460|+11 600|+54,05 %|
|1998-01|42 940|28 269|+14 671|+51,90 %|
|1998-02|23 995|42 940|−18 945|−44,12 %|

La répétition d'une hausse en janvier et d'une baisse en février **suggère** une saisonnalité ; sans correction des jours ouvrés et analyse des types d'opération, ce n'est pas une explication causale.

### Q6 — Cohortes mensuelles d'ouverture (`SUM() OVER`)

**60 mois** d'ouvertures recensés, de **1993-01** à **1997-12**. Le cumul progresse sans rupture et atteint **4 500 comptes** à la fin de décembre 1997. La somme des ouvertures mensuelles a été recoupée avec les effectifs annuels :

|Année|Nouveaux comptes|Cumul fin d'année|
|-|-:|-:|
|1993|1 139|1 139|
|1994|439|1 578|
|1995|661|2 239|
|1996|1 363|3 602|
|1997|898|4 500|

Le maximum mensuel observé est **juillet 1996 : 137 ouvertures** ; le minimum est **janvier 1994 : 24 ouvertures**. **1996** concentre le plus d'ouvertures annuelles (1 363, soit 30,29 % du total), mais aucune ouverture n'est enregistrée dans les données en 1998, année où des transactions continuent d'être observées.

La série complète a été retranscrite et contrôlée (chaque cumul = cumul précédent + ouvertures du mois) : [`resultats/cohortes\_mensuelles\_1993\_1997.csv`](resultats/cohortes_mensuelles_1993_1997.csv).

