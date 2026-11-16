-- ============================================================================
-- Projet Berka | 03_quality_checks.sql
-- MySQL 8.0+ | Contrôles de qualité après chargement valide et COMMIT
-- Source métier : guide « Projet 2 - Analyse SQL d'une base bancaire (Berka) »
-- Exécution : MySQL Workbench, connecté à la base berka.
-- Ne modifie aucune donnée des huit tables métier.
-- Note : les contrôles signalent des anomalies à investiguer, sans les corriger.
-- ============================================================================

USE berka;

-- 01. Périodes couvertes (ordre : account, loan, trans)
SELECT 'account' AS table_name, MIN(opened_date) AS date_min, MAX(opened_date) AS date_max FROM account
UNION ALL
SELECT 'loan', MIN(loan_date), MAX(loan_date) FROM loan
UNION ALL
SELECT 'trans', MIN(trans_date), MAX(trans_date) FROM trans;

-- 02. Effectifs chargés
SELECT 'district' AS table_name, COUNT(*) AS nb FROM district
UNION ALL SELECT 'account', COUNT(*) FROM account
UNION ALL SELECT 'client', COUNT(*) FROM client
UNION ALL SELECT 'disp', COUNT(*) FROM disp
UNION ALL SELECT 'card', COUNT(*) FROM card
UNION ALL SELECT 'loan', COUNT(*) FROM loan
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'trans', COUNT(*) FROM trans;

-- 03. Répartition des statuts de prêt et pourcentage
SELECT l.status, s.label_fr, COUNT(*) AS nb_prets,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pourcentage
FROM loan AS l
JOIN ref_loan_status AS s ON s.status = l.status
GROUP BY l.status, s.label_fr
ORDER BY l.status;

-- 04. Règles d'intégrité métier : une ligne par contrôle
SELECT 'comptes_sans_titulaire' AS controle, COUNT(*) AS anomalies
FROM account AS a
WHERE NOT EXISTS (
    SELECT 1 FROM disp AS d
    WHERE d.account_id = a.account_id AND d.disp_type = 'OWNER'
)
UNION ALL
SELECT 'comptes_multi_titulaires', COUNT(*)
FROM (
    SELECT account_id FROM disp
    WHERE disp_type = 'OWNER'
    GROUP BY account_id HAVING COUNT(*) > 1
) AS doublons
UNION ALL
SELECT 'comptes_multi_prets', COUNT(*)
FROM (
    SELECT account_id FROM loan
    GROUP BY account_id HAVING COUNT(*) > 1
) AS multi
UNION ALL
SELECT 'prets_avant_ouverture', COUNT(*)
FROM loan AS l JOIN account AS a ON a.account_id = l.account_id
WHERE l.loan_date < a.opened_date
UNION ALL
SELECT 'transactions_avant_ouverture', COUNT(*)
FROM trans AS t JOIN account AS a ON a.account_id = t.account_id
WHERE t.trans_date < a.opened_date
UNION ALL
SELECT 'cartes_avant_ouverture', COUNT(*)
FROM card AS c
JOIN disp AS d ON d.disp_id = c.disp_id
JOIN account AS a ON a.account_id = d.account_id
WHERE c.issued_date < a.opened_date;

-- Remarque : comptes_multi_prets n'est pas nécessairement une erreur : analyser le contexte.

-- 05. Champs manquants et soldes négatifs ; certains NULL sont légitimes
SELECT COUNT(*) AS nb_transactions,
       SUM(operation IS NULL) AS operations_vides,
       SUM(k_symbol IS NULL) AS codes_symboles_vides,
       SUM(bank IS NULL) AS banques_vides,
       SUM(partner_account IS NULL) AS comptes_partenaires_vides,
       SUM(balance < 0) AS soldes_negatifs
FROM trans;

-- 06. Cohérence des soldes : requête volumineuse, à exécuter séparément.
-- L'ordre à l'intérieur d'une même journée n'est pas toujours reconstructible ;
-- un écart n'est donc pas automatiquement une erreur de source.
WITH ordered_trans AS (
    SELECT account_id, trans_id, trans_date, trans_type, amount, balance,
           LAG(balance) OVER (
               PARTITION BY account_id ORDER BY trans_date, trans_id
           ) AS prev_balance
    FROM trans
)
SELECT COUNT(*) AS ecarts_de_solde
FROM ordered_trans
WHERE prev_balance IS NOT NULL
  AND ROUND(
      prev_balance + CASE WHEN trans_type = 'PRIJEM' THEN amount ELSE -amount END - balance,
      2
  ) <> 0;

-- 07. Journal de contrôle (historique) : créer la table dédiée sans toucher aux données métier
CREATE TABLE IF NOT EXISTS quality_log (
    log_id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    check_name VARCHAR(80) NOT NULL,
    result BIGINT NOT NULL,
    expected VARCHAR(40) DEFAULT NULL,
    checked_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Historiser un contrôle métier important ; chaque exécution produit une nouvelle entrée.
INSERT INTO quality_log (check_name, result, expected)
SELECT 'prets_avant_ouverture', COUNT(*), '0'
FROM loan AS l
JOIN account AS a ON a.account_id = l.account_id
WHERE l.loan_date < a.opened_date;

SELECT * FROM quality_log ORDER BY checked_at DESC, log_id DESC LIMIT 20;
