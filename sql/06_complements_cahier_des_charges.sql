-- ============================================================================
-- PROJET BERKA | 06_complements_cahier_des_charges.sql
-- Six questions du cahier des charges initial complementaires aux 10
-- analyses du fichier 04_analysis.sql.
-- VALIDATION : six requetes executees dans MySQL Workbench le 16/11/2026.
-- Q1: 77 districts ; Q2: 65 districts avec >= 5 prets ;
-- Q3: 4 477 clients sans carte ; Q4: 231 lignes ;
-- Q5: 72 mois ; Q6: 60 mois, cumul final 4 500 comptes.
-- Details et limites : docs/RESULTATS.md.
-- Chaque requete est autonome ; execution une par une sous MySQL 8.0+.
-- ============================================================================
USE berka;

-- Q1. Nombre de comptes et solde moyen connu par district
-- Definition : une observation PAR COMPTE, avec le dernier solde enregistre.
-- Attention : tri intrajournalier approxime par trans_id ; ce solde n'est
-- pas necessairement le solde exact en fin de journee.
WITH soldes_classes AS (
    SELECT
        t.account_id, t.balance,
        ROW_NUMBER() OVER (
            PARTITION BY t.account_id
            ORDER BY t.trans_date DESC, t.trans_id DESC
        ) AS rn
    FROM berka.trans AS t
)
SELECT
    di.district_id,
    di.district_name,
    di.region,
    COUNT(*) AS nombre_comptes,
    ROUND(AVG(sc.balance), 2) AS solde_moyen_connu,
    SUM(sc.balance IS NULL) AS comptes_sans_solde
FROM berka.account AS a
JOIN berka.district AS di ON di.district_id = a.district_id
LEFT JOIN soldes_classes AS sc ON sc.account_id = a.account_id AND sc.rn = 1
GROUP BY di.district_id, di.district_name, di.region
ORDER BY nombre_comptes DESC, di.district_id;

-- Q2. Part des prets B/D par DISTRICT, avec HAVING
-- Par choix methodologique, on affiche seulement les districts avec >= 5 prets.
-- Les districts ecartes ne doivent pas etre interpretes comme sans risque.
SELECT
    di.district_id,
    di.district_name,
    COUNT(*) AS nombre_prets,
    SUM(l.status IN ('B', 'D')) AS prets_problematiques,
    ROUND(100.0 * SUM(l.status IN ('B', 'D')) / COUNT(*), 2)
        AS taux_prets_problematiques_pct
FROM berka.loan AS l
JOIN berka.account AS a ON a.account_id = l.account_id
JOIN berka.district AS di ON di.district_id = a.district_id
GROUP BY di.district_id, di.district_name
HAVING COUNT(*) >= 5
ORDER BY taux_prets_problematiques_pct DESC, nombre_prets DESC;

-- Q3. Clients sans carte, avec LEFT JOIN
-- Une absence de carte est evaluee sur toutes les dispositions du client.
WITH cartes_par_client AS (
    SELECT
        c.client_id,
        c.gender,
        COUNT(DISTINCT ca.card_id) AS nb_cartes
    FROM berka.client AS c
    LEFT JOIN berka.disp AS dp ON dp.client_id = c.client_id
    LEFT JOIN berka.card AS ca ON ca.disp_id = dp.disp_id
    GROUP BY c.client_id, c.gender
)
SELECT
    gender,
    COUNT(*) AS clients_sans_carte
FROM cartes_par_client
WHERE nb_cartes = 0
GROUP BY gender
ORDER BY gender;

-- Q4. Top 3 des comptes par district, classes par flux monetaire BRUT cumule
-- Montant = entrees + sorties (t.amount >= 0) ; ce n'est pas le flux NET.
WITH volume_par_compte AS (
    SELECT
        a.account_id,
        a.district_id,
        COUNT(t.trans_id) AS nombre_transactions,
        COALESCE(SUM(t.amount), 0) AS flux_brut_cumule
    FROM berka.account AS a
    LEFT JOIN berka.trans AS t ON t.account_id = a.account_id
    GROUP BY a.account_id, a.district_id
), classement AS (
    SELECT
        v.*,
        ROW_NUMBER() OVER (
            PARTITION BY district_id
            ORDER BY flux_brut_cumule DESC, account_id
        ) AS rang_district
    FROM volume_par_compte AS v
)
SELECT
    d.district_id,
    d.district_name,
    cl.rang_district,
    cl.account_id,
    cl.nombre_transactions,
    cl.flux_brut_cumule
FROM classement AS cl
JOIN berka.district AS d ON d.district_id = cl.district_id
WHERE cl.rang_district <= 3
ORDER BY d.district_id, cl.rang_district;

-- Q5. Nombre de transactions par mois et variation par rapport au mois precedent
-- Le nombre de transactions est le volume d'activite, pas le montant.
WITH mensuel AS (
    SELECT
        DATE_FORMAT(trans_date, '%Y-%m') AS mois,
        COUNT(*) AS nombre_transactions,
        SUM(amount) AS montant_brut
    FROM berka.trans
    GROUP BY DATE_FORMAT(trans_date, '%Y-%m')
), compare AS (
    SELECT
        mois,
        nombre_transactions,
        montant_brut,
        LAG(nombre_transactions) OVER (ORDER BY mois) AS transactions_mois_precedent
    FROM mensuel
)
SELECT
    mois,
    nombre_transactions,
    transactions_mois_precedent,
    (nombre_transactions - transactions_mois_precedent) AS variation_absolue,
    ROUND(100.0 * (nombre_transactions - transactions_mois_precedent)
        / NULLIF(transactions_mois_precedent, 0), 2) AS variation_pct,
    montant_brut
FROM compare
ORDER BY mois;

-- Q6. Cohortes de comptes par MOIS d'ouverture, cumul mensuel.
WITH ouvertures_mensuelles AS (
    SELECT DATE_FORMAT(opened_date, '%Y-%m') AS mois_ouverture,
           COUNT(*) AS nouveaux_comptes
    FROM berka.account
    GROUP BY DATE_FORMAT(opened_date, '%Y-%m')
)
SELECT
    mois_ouverture,
    nouveaux_comptes,
    SUM(nouveaux_comptes) OVER (
        ORDER BY mois_ouverture
    ) AS total_cumule
FROM ouvertures_mensuelles
ORDER BY mois_ouverture;
