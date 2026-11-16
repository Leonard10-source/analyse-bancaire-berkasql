-- ============================================================================
-- PROJET BERKA | 04_analysis.sql
-- Analyse SQL du portefeuille bancaire (PKDD'99 / jeu de donnees Berka)
-- SGBD : MySQL 8.x | Base : berka
-- Date de preparation : 2026-11-16
-- ============================================================================
-- OBJET
-- Reunir, dans l'ordre, les analyses bancaires travaillees dans MySQL
-- Workbench. Les requetes sont en lecture seule : aucune ne modifie les donnees.
--
-- MODE D'EMPLOI
-- 1. Ouvrir ce fichier dans MySQL Workbench.
-- 2. Executer USE berka; une seule fois.
-- 3. Selectionner puis executer UNE section SELECT a la fois.
-- 4. Conserver le fichier distinct de 03_quality_checks.sql.
--
-- AVANCEMENT AU 16/11/2026
-- Analyses 01 a 04 : executees et verifiees avec succes.
-- Analyse 05       : prochaine analyse a executer.
--
-- DEFINITIONS METIER
-- Statut A : pret termine et rembourse.
-- Statut B : pret termine, non rembourse.
-- Statut C : pret en cours, sain.
-- Statut D : pret en cours, en difficulte.
-- "Pret problematique" = statut B ou D (definition pour ce projet).
-- Cette classification ne mesure PAS a elle seule une perte realisee,
-- un encours impaye ni la probabilite statistique de defaut.
-- Les montants sont exprimes dans l'unite monetaire du jeu de donnees.
-- ============================================================================

USE berka;

-- ============================================================================
-- 01. PRETS PROBLEMATIQUES : EFFECTIFS ET MONTANTS
-- Question : quelle est l'exposition en montant initial des prets B et D ?
-- SQL : INNER JOIN, WHERE IN, GROUP BY, COUNT, SUM, AVG.
--
-- Resultats deja obtenus :
-- D : 45 prets ; montant total 11 217 804 ; montant moyen 249 284,53.
-- B : 31 prets ; montant total  4 362 348 ; montant moyen 140 720,90.
-- Ensemble : 76 prets ; montant initial cumule 15 580 152.
-- Prudence : montant initial <> perte financiere effective.
-- ============================================================================
SELECT
    l.status AS statut,
    r.label_fr AS description,
    COUNT(*) AS nombre_prets,
    SUM(l.amount) AS montant_total,
    ROUND(AVG(l.amount), 2) AS montant_moyen
FROM berka.loan AS l
JOIN berka.ref_loan_status AS r
    ON l.status = r.status
WHERE l.status IN ('B', 'D')
GROUP BY l.status, r.label_fr
ORDER BY montant_total DESC;


-- ============================================================================
-- 02. MONTANT ET DUREE DES PRETS
-- Question : les proportions de prets B/D different-elles selon la duree ?
-- SQL : GROUP BY, CASE WHEN, agregations conditionnelles.
--
-- Resultats deja obtenus (duree ; nombre ; problemes ; taux) :
-- 12 mois : 131 ; 11 ;  8,40 %
-- 24 mois : 138 ; 17 ; 12,32 %
-- 36 mois : 130 ; 15 ; 11,54 %
-- 48 mois : 138 ; 16 ; 11,59 %
-- 60 mois : 145 ; 17 ; 11,72 %
-- Total   : 682 ; 76 ; 11,14 %
-- Prudence : association descriptive, pas relation causale.
-- ============================================================================
SELECT
    duration AS duree_mois,
    COUNT(*) AS nombre_prets,
    SUM(amount) AS montant_total,
    ROUND(AVG(amount), 2) AS montant_moyen,
    SUM(
        CASE WHEN status IN ('B', 'D') THEN 1 ELSE 0 END
    ) AS prets_problematiques,
    ROUND(
        100.0 * SUM(
            CASE WHEN status IN ('B', 'D') THEN 1 ELSE 0 END
        ) / COUNT(*),
        2
    ) AS taux_prets_problematiques
FROM berka.loan
GROUP BY duration
ORDER BY duration;


-- ============================================================================
-- 03. PROFIL DEMOGRAPHIQUE DES TITULAIRES EMPRUNTEURS
-- Question : quels sont les effectifs, ages et taux B/D selon le sexe ?
-- SQL : JOIN, restriction OWNER, TIMESTAMPDIFF, CASE WHEN.
--
-- La table disp relie un compte a son titulaire (disp_type = 'OWNER').
-- Resultats deja obtenus :
-- F : 348 prets ; age moyen 36,5 ans ; 41 problematiques ; 11,78 %.
-- M : 334 prets ; age moyen 38,8 ans ; 35 problematiques ; 10,48 %.
-- Prudence : aucun lien causal ni discrimination justifiee par ce constat.
-- ============================================================================
SELECT
    c.gender AS sexe,
    COUNT(*) AS nombre_prets,
    ROUND(
        AVG(TIMESTAMPDIFF(YEAR, c.birth_date, l.loan_date)),
        1
    ) AS age_moyen_emprunteurs,
    SUM(
        CASE WHEN l.status IN ('B', 'D') THEN 1 ELSE 0 END
    ) AS prets_problematiques,
    ROUND(
        100.0 * SUM(
            CASE WHEN l.status IN ('B', 'D') THEN 1 ELSE 0 END
        ) / COUNT(*),
        2
    ) AS taux_prets_problematiques
FROM berka.loan AS l
JOIN berka.disp AS d
    ON l.account_id = d.account_id
   AND d.disp_type = 'OWNER'
JOIN berka.client AS c
    ON d.client_id = c.client_id
GROUP BY c.gender
ORDER BY c.gender;


-- ============================================================================
-- 04. REPARTITION GEOGRAPHIQUE DES PRETS ET DES DIFFICULTES
-- Question : quelles regions concentrent les prets et les statuts B/D ?
-- SQL : jointures loan -> account -> district, GROUP BY, CASE WHEN.
--
-- Resultats deja obtenus (region : prets ; problematiques ; taux) :
-- west Bohemia    :  57 ;  9 ; 15,79 %
-- north Moravia   : 117 ; 18 ; 15,38 %
-- south Bohemia   :  60 ;  9 ; 15,00 %
-- central Bohemia :  90 ; 10 ; 11,11 %
-- east Bohemia    :  84 ;  9 ; 10,71 %
-- south Moravia   : 129 ; 13 ; 10,08 %
-- Prague          :  84 ;  7 ;  8,33 %
-- north Bohemia   :  61 ;  1 ;  1,64 %
-- Prudence : taux sensibles a la taille de l'echantillon par region.
-- ============================================================================
SELECT
    d.region AS region,
    COUNT(*) AS nombre_prets,
    SUM(l.amount) AS montant_total,
    ROUND(AVG(l.amount), 2) AS montant_moyen,
    SUM(
        CASE WHEN l.status IN ('B', 'D') THEN 1 ELSE 0 END
    ) AS prets_problematiques,
    ROUND(
        100.0 * SUM(
            CASE WHEN l.status IN ('B', 'D') THEN 1 ELSE 0 END
        ) / COUNT(*),
        2
    ) AS taux_prets_problematiques
FROM berka.loan AS l
JOIN berka.account AS a
    ON l.account_id = a.account_id
JOIN berka.district AS d
    ON a.district_id = d.district_id
GROUP BY d.region
ORDER BY taux_prets_problematiques DESC;


-- ============================================================================
-- 05. SOLDE CONNU AVANT L'OCTROI DU PRET                 [A EXECUTER ENSUITE]
-- Question : les emprunteurs avec pret B/D avaient-ils des soldes plus faibles
--            avant la date d'octroi que les autres emprunteurs ?
-- SQL : CTE (WITH), LEFT JOIN, ROW_NUMBER(), GROUP BY, AVG.
--
-- Methode :
--   * Inclure uniquement les transactions dont la date PRECEDE le pret.
--   * Selectionner la plus recente par pret (rang = 1).
--   * Conserver aussi les prets sans transaction anterieure (solde NULL).
--   * Comparer les deux categories : problematique / non problematique.
--
-- CONTROLE ATTENDU : nombre_prets des 2 categories = 682 ; categorie
-- "Problematique" = 76. Les soldes moyens restent a mesurer.
-- LIMITE : si plusieurs transactions existent le meme jour, trans_id n'est
-- pas garanti etre l'ordre d'execution reel. Le dernier solde retenu est
-- donc une APPROXIMATION du dernier solde connu avant le pret.
-- ============================================================================
WITH soldes_avant_pret AS (
    SELECT
        l.loan_id,
        l.status,
        l.amount AS montant_pret,
        t.balance AS solde_avant_pret,
        ROW_NUMBER() OVER (
            PARTITION BY l.loan_id
            ORDER BY t.trans_date DESC, t.trans_id DESC
        ) AS rang
    FROM berka.loan AS l
    LEFT JOIN berka.trans AS t
        ON l.account_id = t.account_id
       AND t.trans_date < l.loan_date
)
SELECT
    CASE
        WHEN status IN ('B', 'D') THEN 'Problematique'
        ELSE 'Non problematique'
    END AS categorie,
    COUNT(*) AS nombre_prets,
    SUM(solde_avant_pret IS NULL) AS prets_sans_solde_anterieur,
    ROUND(AVG(solde_avant_pret), 2) AS solde_moyen_avant_pret,
    ROUND(AVG(montant_pret), 2) AS montant_moyen_pret
FROM soldes_avant_pret
WHERE rang = 1
GROUP BY categorie
ORDER BY categorie;

-- ============================================================
-- 06. ANALYSE DES FLUX BANCAIRES MENSUELS
-- ============================================================

-- Objectif :
-- Étudier l'évolution mensuelle des entrées et sorties
-- d'argent sur les comptes bancaires.
--
-- PRIJEM : entrée d'argent
-- VYDAJ  : sortie d'argent
-- VYBER  : retrait d'argent
--
-- Méthodes SQL :
-- DATE_FORMAT(), COUNT(), SUM(), CASE WHEN, GROUP BY.
--
-- Période étudiée : 1993 à 1998.
-- ============================================================

SELECT
    DATE_FORMAT(trans_date, '%Y-%m') AS mois,

    COUNT(*) AS nombre_transactions,

    SUM(
        CASE
            WHEN trans_type = 'PRIJEM'
            THEN amount
            ELSE 0
        END
    ) AS total_entrees,

    SUM(
        CASE
            WHEN trans_type IN ('VYDAJ', 'VYBER')
            THEN amount
            ELSE 0
        END
    ) AS total_sorties,

    SUM(
        CASE
            WHEN trans_type = 'PRIJEM'
            THEN amount

            WHEN trans_type IN ('VYDAJ', 'VYBER')
            THEN -amount

            ELSE 0
        END
    ) AS flux_net

FROM berka.trans

GROUP BY DATE_FORMAT(trans_date, '%Y-%m')

ORDER BY mois;

-- ============================================================================
-- SUITE DU PROJET
-- Les futures analyses (flux mensuels, cohortes, transactions atypiques)
-- seront ajoutees dans ce meme fichier, apres validation de la section 05.
-- Ne pas modifier les tables sources pendant l'analyse.
-- ============================================================================


-- ============================================================
-- 07. ÉVOLUTION DES OUVERTURES DE COMPTES BANCAIRES
-- ============================================================

-- Objectif :
-- Analyser le nombre de nouveaux comptes ouverts chaque année.
-- Mesurer leur contribution au portefeuille total.
-- Calculer l'évolution cumulée du nombre de comptes.
--
-- Méthodes SQL :
-- CTE (WITH), YEAR(), COUNT(), SUM() OVER(), ROUND().
-- ============================================================

WITH cohortes AS (
    SELECT
        YEAR(opened_date) AS annee_ouverture,
        COUNT(*) AS nouveaux_comptes

    FROM berka.account

    GROUP BY YEAR(opened_date)
)

SELECT
    annee_ouverture,

    nouveaux_comptes,

    SUM(nouveaux_comptes) OVER (
        ORDER BY annee_ouverture
    ) AS total_cumule,

    ROUND(
        100.0 * nouveaux_comptes /
        SUM(nouveaux_comptes) OVER (),
        2
    ) AS pourcentage_total

FROM cohortes

ORDER BY annee_ouverture;



-- ============================================================
-- 08. DETECTION DES TRANSACTIONS BANCAIRES ATYPIQUES
-- ============================================================

-- Objectif :
-- Identifier les transactions dont le montant est
-- anormalement élevé par rapport aux habitudes du compte.
--
-- Méthode statistique :
-- Z-score = (montant - moyenne) / ecart_type
--
-- Seuil retenu : Z-score > 3
--
-- Méthodes SQL :
-- CTE (WITH), AVG(), STDDEV_SAMP(), COUNT(),
-- JOIN, HAVING, ORDER BY.
--
-- Précaution :
-- Une transaction atypique n'est pas nécessairement
-- une transaction frauduleuse.
-- ============================================================

USE berka;

WITH statistiques_comptes AS (

    SELECT
        account_id,

        COUNT(*) AS nombre_transactions,

        AVG(amount) AS montant_moyen,

        STDDEV_SAMP(amount) AS ecart_type

    FROM berka.trans

    GROUP BY account_id

    -- Conserver les comptes avec suffisamment
    -- d'observations et un écart-type non nul.
    HAVING COUNT(*) >= 10
       AND STDDEV_SAMP(amount) > 0
)

SELECT
    t.trans_id,

    t.account_id,

    t.trans_date,

    t.trans_type,

    t.amount AS montant_transaction,

    ROUND(s.montant_moyen, 2) AS montant_moyen_compte,

    ROUND(s.ecart_type, 2) AS ecart_type_compte,

    ROUND(
        (t.amount - s.montant_moyen) / s.ecart_type,
        2
    ) AS z_score

FROM berka.trans AS t

JOIN statistiques_comptes AS s
    ON t.account_id = s.account_id

WHERE
    (t.amount - s.montant_moyen) / s.ecart_type > 3

ORDER BY z_score DESC

LIMIT 20;


-- ============================================================
-- 09. DETECTION DES TRANSACTIONS ATYPIQUES PAR IQR
-- ============================================================

-- Objectif :
-- Identifier les montants inhabituellement élevés
-- en utilisant une méthode robuste aux valeurs extrêmes.
--
-- IQR = Q3 - Q1
-- Limite supérieure = Q3 + 1.5 * IQR
--
-- Les quartiles sont calculés pour chaque compte.
-- Méthode : nearest-rank.
--
-- Les comptes avec moins de 10 transactions
-- ou un IQR nul sont exclus.
-- ============================================================

USE berka;

WITH transactions_classees AS (

    SELECT
        account_id,
        amount,

        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY amount, trans_id
        ) AS rang,

        COUNT(*) OVER (
            PARTITION BY account_id
        ) AS total_transactions

    FROM berka.trans
),

quartiles AS (

    SELECT
        account_id,

        MAX(total_transactions) AS nombre_transactions,

        MAX(
            CASE
                WHEN rang = CEIL(total_transactions * 0.25)
                THEN amount
            END
        ) AS q1,

        MAX(
            CASE
                WHEN rang = CEIL(total_transactions * 0.75)
                THEN amount
            END
        ) AS q3

    FROM transactions_classees

    GROUP BY account_id

    HAVING MAX(total_transactions) >= 10
)

SELECT
    t.trans_id,
    t.account_id,
    t.trans_date,
    t.trans_type,
    t.amount AS montant_transaction,

    q.q1,
    q.q3,

    ROUND(q.q3 - q.q1, 2) AS iqr,

    ROUND(
        q.q3 + 1.5 * (q.q3 - q.q1),
        2
    ) AS limite_superieure

FROM berka.trans AS t

JOIN quartiles AS q
    ON t.account_id = q.account_id

WHERE
    q.q3 > q.q1

    AND t.amount >
        q.q3 + 1.5 * (q.q3 - q.q1)

ORDER BY
    t.amount - (
        q.q3 + 1.5 * (q.q3 - q.q1)
    ) DESC

LIMIT 20;


-- ============================================================
-- 10. COMPARAISON DES METHODES Z-SCORE ET IQR
-- ============================================================

-- Objectif :
-- Comparer les transactions atypiques détectées
-- par les deux méthodes statistiques.
--
-- Conditions :
-- Minimum 10 transactions par compte.
-- Z-score > 3.
-- IQR : montant > Q3 + 1.5 * IQR.
--
-- Résultat :
-- Nombre de transactions détectées par chaque méthode,
-- par les deux méthodes et exclusivement par l'une.
-- ============================================================

WITH statistiques AS (
    SELECT
        account_id,
        COUNT(*) AS n,
        AVG(amount) AS moyenne,
        STDDEV_SAMP(amount) AS ecart_type
    FROM berka.trans
    GROUP BY account_id
    HAVING COUNT(*) >= 10
),

classement AS (
    SELECT
        account_id,
        amount,

        ROW_NUMBER() OVER (
            PARTITION BY account_id
            ORDER BY amount, trans_id
        ) AS rang,

        COUNT(*) OVER (
            PARTITION BY account_id
        ) AS total
    FROM berka.trans
),

quartiles AS (
    SELECT
        account_id,

        MAX(
            CASE
                WHEN rang = CEIL(total * 0.25)
                THEN amount
            END
        ) AS q1,

        MAX(
            CASE
                WHEN rang = CEIL(total * 0.75)
                THEN amount
            END
        ) AS q3

    FROM classement
    GROUP BY account_id
),

detection AS (
    SELECT
        t.trans_id,

        CASE
            WHEN s.ecart_type > 0
             AND (t.amount - s.moyenne) / s.ecart_type > 3
            THEN 1 ELSE 0
        END AS anomalie_zscore,

        CASE
            WHEN q.q3 > q.q1
             AND t.amount > q.q3 + 1.5 * (q.q3 - q.q1)
            THEN 1 ELSE 0
        END AS anomalie_iqr

    FROM berka.trans AS t

    JOIN statistiques AS s
        ON t.account_id = s.account_id

    JOIN quartiles AS q
        ON t.account_id = q.account_id
)

SELECT
    COUNT(*) AS transactions_evaluees,

    SUM(anomalie_zscore) AS total_zscore,

    SUM(anomalie_iqr) AS total_iqr,

    SUM(
        CASE
            WHEN anomalie_zscore = 1
             AND anomalie_iqr = 1
            THEN 1 ELSE 0
        END
    ) AS anomalies_communes,

    SUM(
        CASE
            WHEN anomalie_zscore = 1
             AND anomalie_iqr = 0
            THEN 1 ELSE 0
        END
    ) AS uniquement_zscore,

    SUM(
        CASE
            WHEN anomalie_zscore = 0
             AND anomalie_iqr = 1
            THEN 1 ELSE 0
        END
    ) AS uniquement_iqr

FROM detection;