# Analyse SQL d'une base bancaire — Berka (PKDD'99)

**Projet 2 — Portfolio Data Analyst | MySQL 8 · MySQL Workbench · SQL avancé**

> **Question métier :** comment structurer une base bancaire relationnelle, vérifier la qualité de ses données et produire des indicateurs fiables sur les prêts, les comptes et les flux financiers ?

Ce dépôt documente un projet SQL réalisé sur le jeu de données historique **Berka / PKDD'99**. Le travail comprend la construction d'un schéma relationnel contraint, le chargement de **1 056 320 transactions**, les contrôles de qualité, **10 analyses SQL principales et 6 requêtes complémentaires exécutées** et **3 vues de synthèse**. **Le tableau de bord Power BI est un autre projet (projet 3) : il n'est pas présenté ici comme réalisé.**

## Chiffres clés

| Indicateur | Résultat vérifié |
|---|---:|
| Comptes | **4 500** |
| Clients | **5 369** |
| Transactions | **1 056 320** |
| Prêts | **682** |
| Montant initial total des prêts | **103 261 740,00** |
| Prêts classés B ou D | **76 (11,14 %)** |
| Montant initial des prêts B ou D | **15 580 152,00** |
| Période des transactions | **1993-01-01 — 1998-12-31** |

Les montants correspondent aux valeurs monétaires du jeu de données historique, généralement exprimées en couronnes tchèques (CZK). Ils ne sont **ni des pertes effectives**, ni des montants actualisés.

## 1. Données et provenance

Le **PKDD'99 Financial Dataset** est un jeu de données bancaires anonymisées d'une banque tchèque, publié à l'occasion du *Discovery Challenge* de PKDD 1999.

- Catalogue universitaire : [CTU Relational — Financial](https://relational.fel.cvut.cz/dataset/Financial)
- Archive des fichiers originaux : [miroir du jeu Berka](https://github.com/jlacko/berka-dataset)
- Version effectivement utilisée : **huit fichiers CSV locaux** (`;` comme séparateur), importés sous MySQL/WAMP, avec les effectifs ci-dessous. La version précise du miroir téléchargé reste à renseigner dans les métadonnées du dépôt si elle est connue.

| Table source | Table de travail | Lignes | Finalité |
|---|---|---:|---|
| `account` | `account` | 4 500 | Comptes et dates d'ouverture |
| `client` | `client` | 5 369 | Clients, date de naissance et sexe dérivés |
| `disp` | `disp` | 5 369 | Titulaires et mandataires de comptes |
| `card` | `card` | 892 | Cartes attribuées |
| `district` | `district` | 77 | Districts et indicateurs socio-économiques |
| `loan` | `loan` | 682 | Prêts, durée, montant et statut |
| `order` | `orders` | 6 471 | Ordres de paiement permanents |
| `trans` | `trans` | 1 056 320 | Transactions et soldes enregistrés |

La base propre `berka` ajoute une table de référence `ref_loan_status` (4 lignes) et une table technique `quality_log` ; ces objets ne sont pas des tables CSV sources.

## 2. Architecture et traitements

```text
CSV Berka (8 fichiers)       financial_raw (8 tables texte)
            └────────────────────┘
                      │ contrôles, typage et chargement transactionnel
                      ▼
       berka (8 tables métier + ref_loan_status)
                      │ contrôles métier + journal quality_log
                      ▼
           10 analyses SQL principales + 6 compléments validés
                      │
                      ▼
        3 vues SQL pour une exploitation BI ultérieure
```

La zone `financial_raw` conserve les valeurs brutes. La zone `berka` applique les types `DATE`, `INT`, `DECIMAL`, les clés primaires et étrangères, les contraintes `CHECK` et les index. Le chargement a été validé par `COMMIT` après comparaison des effectifs et montants. Les dates `AAMMJJ` ont été converties en dates du XXe siècle ; les marqueurs `?` de `district` ont été traités comme valeurs absentes.

**Diagramme EER :** créé et exporté localement dans MySQL Workbench. Fichiers attendus dans ce dépôt : `docs/diagrams/Berka_Banking_EER.png` et `models/Berka_Banking_EER.mwb` (ainsi que `docs/diagrams/Berka_Banking_EER.svg` si disponible). Ces fichiers doivent être conservés depuis l'ordinateur de travail : ils ne sont pas inclus dans ce lot de mise à jour documentaire.

## 3. Questions SQL traitées

| # | Question métier | Techniques |
|---|---|---|
| 01 | Montant des prêts B/D | `JOIN`, `SUM`, `AVG` |
| 02 | Durée du prêt et proportion de B/D | `CASE`, `GROUP BY` |
| 03 | Profil des titulaires ayant un prêt | `JOIN`, `TIMESTAMPDIFF` |
| 04 | Exposition par région | `GROUP BY`, agrégation conditionnelle |
| 05 | Dernier solde observé avant le prêt | CTE, `LEFT JOIN`, `ROW_NUMBER` |
| 06 | Flux entrants et sortants par mois | Agrégation temporelle |
| 07 | Cohortes annuelles d'ouvertures | CTE, `SUM() OVER` |
| 08 | Transactions atypiques : Z-score | `AVG`, `STDDEV_SAMP`, CTE |
| 09 | Transactions atypiques : IQR | `ROW_NUMBER`, quartiles, CTE |
| 10 | Concordance des détections Z-score/IQR | CTE, calcul conditionnel |

Les analyses 01–10 ont été exécutées et leurs résultats principaux sont documentés dans [docs/RESULTATS.md](docs/RESULTATS.md).

**Conformité au cahier initial :** six questions complémentaires ont aussi été exécutées dans `sql/06_complements_cahier_des_charges.sql` : soldes par district, risque B/D par district (`HAVING`), clients sans carte (`LEFT JOIN`), top 3 des comptes par district (`ROW_NUMBER`), variation mensuelle des transactions (`LAG`) et cohortes mensuelles. Leurs résultats sont documentés dans [docs/RESULTATS.md](docs/RESULTATS.md). Les 60 cohortes mensuelles sont exportées dans [`docs/resultats/cohortes_mensuelles_1993_1997.csv`](docs/resultats/cohortes_mensuelles_1993_1997.csv).

### Requêtes complémentaires (cahier des charges)

| Requête | Question métier | Résultat de vérification | Technique |
|---|---|---|---|
| Q1 | Comptes et dernier solde connu par district | 77 districts ; 0 compte sans solde connu | `ROW_NUMBER`, `LEFT JOIN` |
| Q2 | Prêts B/D par district | 65 districts retenus (`n ≥ 5`) | `HAVING`, `GROUP BY` |
| Q3 | Clients sans carte | 4 477 clients | `LEFT JOIN`, `COUNT(DISTINCT)` |
| Q4 | Top 3 des comptes par district | 231 lignes (77 × 3) | `ROW_NUMBER`, `PARTITION BY` |
| Q5 | Évolution mensuelle du nombre de transactions | 72 mois (1993–1998) | `LAG` |
| Q6 | Ouvertures mensuelles de comptes et cumul | 60 mois (1993–1997), cumul final 4 500 | `SUM() OVER` |

Ces indicateurs sont descriptifs. Les derniers soldes connus sont approchés à partir de l'ordre des écritures ; une valeur extrême ou un taux élevé sur un faible effectif ne prouve ni une fraude ni une causalité.

## 4. Principaux résultats observés

- **76 prêts sur 682** (11,14 %) sont classés B ou D ; la somme de leurs montants initiaux est **15 580 152**. Cette proportion n'est pas un taux de perte monétaire.
- Le taux descriptif de prêts B/D par région va de **1,64 % en North Bohemia** (1/61) à **15,79 % en West Bohemia** (9/57). **North Moravia** concentre **18 prêts B/D** sur 117.
- Le solde moyen observé *avant* l'octroi est **30 002,81** pour les prêts B/D, contre **43 750,89** pour les autres. Les montants moyens des crédits sont respectivement **205 002,00** et **144 689,09**.
- Les flux mensuels couvrent **72 mois**, de janvier 1993 à décembre 1998. De janvier 1994 à janvier 1998, les flux nets de janvier sont négatifs dans chaque année observée ; ce constat est descriptif, sans explication causale démontrée.
- Sur **1 056 311** transactions éligibles à la comparaison statistique, **9 293** ont été signalées par Z-score, **46 423** par IQR et **9 025** par les deux méthodes. **46 691** sont signalées par au moins une méthode ; ce ne sont pas des fraudes prouvées.

Les six analyses complémentaires confirment notamment **4 477 clients sans carte** (83,39 %), **65 districts** ayant au moins cinq prêts, un classement des **3 comptes principaux pour chacun des 77 districts** et les **60 cohortes mensuelles d'ouverture** (cumul final : 4 500). Les méthodes, limites, effectifs et résultats détaillés sont dans [docs/RESULTATS.md](docs/RESULTATS.md). Les séries de 72 mois de transactions et de 60 mois d'ouvertures figurent dans `docs/resultats/` au format CSV.

## 5. Qualité des données et contrôles de concordance

- **Chargement :** correspondance des effectifs entre `financial_raw` et `berka`, sans pertes de lignes constatées.
- **Références métier :** cinq des six contrôles visibles dans la capture de validation affichent `0` ; le sixième contrôle doit être confirmé à partir du journal ou d'une nouvelle exécution. Le contrôle historisé `prets_avant_ouverture` a bien `result = 0`, `expected = 0`.
- **Valeurs manquantes :** 183 114 opérations sans type d'opération détaillé, 535 314 sans `k_symbol`, 782 812 sans banque et 760 931 sans compte partenaire. Certaines absences peuvent être structurelles ; pas d'imputation systématique.
- **Soldes négatifs :** 2 999 transactions présentent un solde négatif, compatible avec une situation de découvert, à investiguer selon les règles métier.
- **Cohérence des soldes :** 531 084 écarts ont été signalés par un contrôle `LAG` fondé sur l'ordre `trans_date, trans_id`. **Cela ne prouve pas 531 084 erreurs** : l'ordre intrajournalier est incertain pour de nombreuses opérations (241 552 comparaisons concernées par des dates multiples).
- **Vues :** nombre de prêts, nombre de transactions, montant des prêts, entrées et sorties concordent exactement entre tables et vues.

## 6. Reproduire le projet

**Environnement :** MySQL 8.0.16+ (fonctions de fenêtrage et contraintes `CHECK`), MySQL Workbench, fichiers Berka au format CSV délimité par `;`. Exécution locale testée sous WAMP/MySQL sur Windows ; les chemins d'import sont propres au poste.

1. Télécharger les fichiers Berka et vérifier leur format, leur origine et leurs conditions de réutilisation.
2. Sur une base neuve, exécuter `sql/00_prepare_raw.sql`, puis adapter/exécuter `sql/00_import_raw_exemple.sql` pour alimenter `financial_raw`. **Ne pas réimporter des fichiers dans des tables déjà remplies.**
3. Exécuter `sql/01_create_schema.sql` (schéma propre, tables et clés).
4. Vérifier que les huit tables métier `berka` sont vides ; exécuter `sql/02_load_clean.sql` sur **une seule connexion**. Contrôler les effectifs et montants, puis faire **manuellement** `COMMIT;` (ou `ROLLBACK;` en cas d'écart).
5. Exécuter `sql/03_quality_checks.sql` section par section. La section 06 est plus coûteuse ; la section 07 crée la table technique `quality_log`.
6. Exécuter `sql/04_analysis.sql`, requête par requête ; puis `sql/05_views.sql`.
7. Exécuter les six requêtes de `sql/06_complements_cahier_des_charges.sql` ; les sorties attendues sont documentées dans `docs/RESULTATS.md`.

Pour les précautions sur le timeout, les importations Windows et les vérifications finales, voir [docs/REPRODUCTION.md](docs/REPRODUCTION.md).

## 7. Sécurité et limites

**Sécurité.** Pas d'identifiants ni de mots de passe dans le dépôt. En environnement réel : séparer administration, ingestion et lecture analytique, appliquer le moindre privilège, limiter l'écoute MySQL au poste/local privé et tester les sauvegardes. La configuration effective de ces mesures **n'a pas été auditée** dans ce projet.

**Limites.** Données anonymisées et anciennes (1993–1998), **682 prêts seulement**, historique de remboursements incomplet pour les prêts en cours, comparaison B/D définie comme indicateur exploratoire et non défaut bancaire légal/financier, incertitude de l'ordre intrajournalier, sensibilité des méthodes de détection aux distributions des montants. Aucune inférence de causalité ni identification de fraude ne découle des agrégats présentés.

## 8. Fichiers et statut des livrables

```text
berka-sql-analysis/
├── README.md
├── .gitignore
├── sql/
│   ├── 00_prepare_raw.sql               # staging supplémentaire, nouveau
│   ├── 00_import_raw_exemple.sql         # chemin WAMP à adapter, nouveau
│   ├── 01_create_schema.sql              # exécuté
│   ├── 02_load_clean.sql                # exécuté et COMMIT confirmé
│   ├── 03_quality_checks.sql            # exécuté
│   ├── 04_analysis.sql                  # 10 analyses exécutées
│   ├── 05_views.sql                     # 3 vues créées et vérifiées
│   └── 06_complements_cahier_des_charges.sql  # 6 requêtes exécutées et commentées
├── docs/
│   ├── RESULTATS.md
│   ├── DICTIONNAIRE_DONNEES.md
│   ├── REPRODUCTION.md
│   ├── resultats/                     # CSV des résultats contrôlés
│   │   └── cohortes_mensuelles_1993_1997.csv
│   ├── captures/                      # captures choisies, à ajouter
│   └── diagrams/Berka_Banking_EER.png   # export local à placer ici
└── models/Berka_Banking_EER.mwb        # modèle local à placer ici
```

**Statut :** les **16 requêtes d'analyse** (10 principales et 6 complémentaires) ont été exécutées et les résultats reçus ont été contrôlés. Avant publication : vérifier une dernière fois la requête métier concernant les dates d'émission des cartes, compléter les exports CSV/captures voulus, intégrer les fichiers EER locaux et tester la reproduction depuis une base vierge.

## Références

- PKDD'99 / Financial : [CTU Relational Dataset Repository](https://relational.fel.cvut.cz/dataset/Financial).
- Archive du jeu historique : [jlacko/berka-dataset](https://github.com/jlacko/berka-dataset).
- Cahier initial de ce portfolio : *Projets portfolio : Excel, SQL, BI et Python*, projet 2 (document de travail fourni).
