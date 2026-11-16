-- ============================================================================
-- PROJET BERKA — 02_load_clean.sql
-- Chargement contrôlé du schéma propre depuis financial_raw (voie CSV / Kaggle).
-- MySQL 8.0.16+ ; compatible avec le schéma 01_create_schema.sql fourni.
-- ============================================================================
-- PREREQUIS :
--   1. financial_raw contient les 8 tables CSV complètes et vérifiées.
--   2. Les 8 tables métier dans berka sont VIDES.
--   3. ref_loan_status contient déjà les 4 statuts A, B, C, D.
--   4. Rester sur LA MEME connexion MySQL jusqu'au COMMIT ou ROLLBACK.
--
-- IMPORTANT : le script ne lance pas COMMIT. Il affiche des contrôles.
-- Si tout est correct : exécuter COMMIT; dans la même connexion.
-- En cas d'erreur ou d'écart : exécuter ROLLBACK; dans la même connexion.
-- Ne pas relancer le chargement sur des tables déjà remplies.
-- ============================================================================

USE berka;

-- 0. Contrôle de préchargement : toutes ces valeurs doivent être 0.
SELECT 'district' AS table_name, COUNT(*) AS lignes_avant FROM berka.district
UNION ALL SELECT 'account', COUNT(*) FROM berka.account
UNION ALL SELECT 'client', COUNT(*) FROM berka.client
UNION ALL SELECT 'disp', COUNT(*) FROM berka.disp
UNION ALL SELECT 'card', COUNT(*) FROM berka.card
UNION ALL SELECT 'loan', COUNT(*) FROM berka.loan
UNION ALL SELECT 'orders', COUNT(*) FROM berka.orders
UNION ALL SELECT 'trans', COUNT(*) FROM berka.trans;

-- Si l'une des valeurs ci-dessus est > 0, ARRÊTER avant START TRANSACTION.
START TRANSACTION;

-- 1. District : 16 colonnes sources A1..A16, avec « ? » pour des valeurs absentes.
INSERT INTO berka.district (
  district_id, district_name, region, inhabitants,
  municipalities_lt500, municipalities_500_1999, municipalities_2000_9999,
  municipalities_ge10000, cities, urban_ratio, avg_salary,
  unemployment_95, unemployment_96, entrepreneurs_per_1000,
  crimes_95, crimes_96
)
SELECT
  CAST(A1 AS UNSIGNED), A2, A3, CAST(A4 AS UNSIGNED),
  CAST(A5 AS UNSIGNED), CAST(A6 AS UNSIGNED), CAST(A7 AS UNSIGNED),
  CAST(A8 AS UNSIGNED), CAST(A9 AS UNSIGNED),
  CAST(A10 AS DECIMAL(5,2)), CAST(A11 AS UNSIGNED),
  CAST(NULLIF(TRIM(A12), '?') AS DECIMAL(5,2)),
  CAST(A13 AS DECIMAL(5,2)), CAST(A14 AS UNSIGNED),
  CAST(NULLIF(TRIM(A15), '?') AS UNSIGNED), CAST(A16 AS UNSIGNED)
FROM financial_raw.district;

-- 2. Comptes : date AAMMJJ (années 1990) -> DATE.
INSERT INTO berka.account (account_id, district_id, frequency, opened_date)
SELECT
  CAST(account_id AS UNSIGNED), CAST(district_id AS UNSIGNED), TRIM(frequency),
  STR_TO_DATE(CONCAT('19', LPAD(TRIM(`date`), 6, '0')), '%Y%m%d')
FROM financial_raw.account;

-- 3. Clients : birth_number = AAMMJJ ; mois +50 = sexe féminin.
-- Dans le jeu de données Berka, les dates de naissance appartiennent au XXe siècle.
INSERT INTO berka.client (client_id, birth_date, gender, district_id)
SELECT
  CAST(client_id AS UNSIGNED),
  STR_TO_DATE(
    CONCAT(
      '19', LEFT(LPAD(TRIM(birth_number), 6, '0'), 2),
      LPAD(
        CAST(SUBSTRING(LPAD(TRIM(birth_number), 6, '0'), 3, 2) AS UNSIGNED)
        - IF(CAST(SUBSTRING(LPAD(TRIM(birth_number), 6, '0'), 3, 2) AS UNSIGNED) > 12, 50, 0),
        2, '0'
      ),
      RIGHT(LPAD(TRIM(birth_number), 6, '0'), 2)
    ), '%Y%m%d'
  ),
  IF(CAST(SUBSTRING(LPAD(TRIM(birth_number), 6, '0'), 3, 2) AS UNSIGNED) > 12, 'F', 'M'),
  CAST(district_id AS UNSIGNED)
FROM financial_raw.client;

-- 4. Relations clients–comptes.
INSERT INTO berka.disp (disp_id, client_id, account_id, disp_type)
SELECT CAST(disp_id AS UNSIGNED), CAST(client_id AS UNSIGNED),
       CAST(account_id AS UNSIGNED), TRIM(`type`)
FROM financial_raw.disp;

-- 5. Cartes : issued (AAMMJJ HH:MM:SS) -> DATE.
INSERT INTO berka.card (card_id, disp_id, card_type, issued_date)
SELECT CAST(card_id AS UNSIGNED), CAST(disp_id AS UNSIGNED), TRIM(`type`),
       STR_TO_DATE(CONCAT('19', LEFT(TRIM(issued), 6)), '%Y%m%d')
FROM financial_raw.card;

-- 6. Prêts : dates et montants normalisés.
INSERT INTO berka.loan (loan_id, account_id, loan_date, amount, duration, payments, status)
SELECT CAST(loan_id AS UNSIGNED), CAST(account_id AS UNSIGNED),
       STR_TO_DATE(CONCAT('19', LPAD(TRIM(`date`), 6, '0')), '%Y%m%d'),
       CAST(amount AS DECIMAL(12,2)), CAST(duration AS UNSIGNED),
       CAST(payments AS DECIMAL(10,2)), TRIM(status)
FROM financial_raw.loan;

-- 7. Ordres permanents : table source « order » = mot réservé.
INSERT INTO berka.orders (order_id, account_id, bank_to, account_to, amount, k_symbol)
SELECT CAST(order_id AS UNSIGNED), CAST(account_id AS UNSIGNED),
       NULLIF(TRIM(bank_to), ''), NULLIF(TRIM(account_to), ''),
       CAST(amount AS DECIMAL(12,2)), NULLIF(TRIM(k_symbol), '')
FROM financial_raw.`order`;

-- 8. Transactions : étape la plus volumineuse (> 1 million de lignes).
INSERT INTO berka.trans (
  trans_id, account_id, trans_date, trans_type, operation,
  amount, balance, k_symbol, bank, partner_account
)
SELECT CAST(trans_id AS UNSIGNED), CAST(account_id AS UNSIGNED),
       STR_TO_DATE(CONCAT('19', LPAD(TRIM(`date`), 6, '0')), '%Y%m%d'),
       TRIM(`type`), NULLIF(TRIM(operation), ''),
       CAST(amount AS DECIMAL(12,2)), CAST(balance AS DECIMAL(12,2)),
       NULLIF(TRIM(k_symbol), ''), NULLIF(TRIM(bank), ''),
       NULLIF(TRIM(`account`), '')
FROM financial_raw.trans;

-- ============================================================================
-- VALIDATION AVANT COMMIT — comparer la colonne source à la colonne propre.
-- ============================================================================
SELECT 'district' AS table_name,
       (SELECT COUNT(*) FROM financial_raw.district) AS source_count,
       (SELECT COUNT(*) FROM berka.district) AS propre_count
UNION ALL SELECT 'account', (SELECT COUNT(*) FROM financial_raw.account),
                            (SELECT COUNT(*) FROM berka.account)
UNION ALL SELECT 'client', (SELECT COUNT(*) FROM financial_raw.client),
                           (SELECT COUNT(*) FROM berka.client)
UNION ALL SELECT 'disp', (SELECT COUNT(*) FROM financial_raw.disp),
                         (SELECT COUNT(*) FROM berka.disp)
UNION ALL SELECT 'card', (SELECT COUNT(*) FROM financial_raw.card),
                         (SELECT COUNT(*) FROM berka.card)
UNION ALL SELECT 'loan', (SELECT COUNT(*) FROM financial_raw.loan),
                         (SELECT COUNT(*) FROM berka.loan)
UNION ALL SELECT 'orders', (SELECT COUNT(*) FROM financial_raw.`order`),
                           (SELECT COUNT(*) FROM berka.orders)
UNION ALL SELECT 'trans', (SELECT COUNT(*) FROM financial_raw.trans),
                          (SELECT COUNT(*) FROM berka.trans);

-- Vérification des montants : source vs schéma propre.
SELECT
  (SELECT SUM(CAST(amount AS DECIMAL(14,2))) FROM financial_raw.trans) AS raw_trans_amount,
  (SELECT SUM(amount) FROM berka.trans) AS clean_trans_amount,
  (SELECT SUM(CAST(amount AS DECIMAL(14,2))) FROM financial_raw.loan) AS raw_loan_amount,
  (SELECT SUM(amount) FROM berka.loan) AS clean_loan_amount;

-- Vérification des bornes temporelles et des répartitions de valeurs.
SELECT MIN(loan_date) AS premier_pret, MAX(loan_date) AS dernier_pret FROM berka.loan;
SELECT gender, COUNT(*) AS nombre_clients FROM berka.client GROUP BY gender ORDER BY gender;
SELECT status, COUNT(*) AS nombre_prets FROM berka.loan GROUP BY status ORDER BY status;

-- ============================================================================
-- ARRÊT ICI : ne PAS valider sans examiner les résultats de ces contrôles.
-- Si tout est correct et aucune erreur SQL : exécuter MANUELLEMENT COMMIT;
-- Si problème (erreur SQL, décompte, montant, dates) : exécuter ROLLBACK;
-- ============================================================================

SELECT 'district' AS table_name, COUNT(*) AS total
FROM berka.district

UNION ALL
SELECT 'account', COUNT(*)
FROM berka.account

UNION ALL
SELECT 'client', COUNT(*)
FROM berka.client

UNION ALL
SELECT 'disp', COUNT(*)
FROM berka.disp

UNION ALL
SELECT 'card', COUNT(*)
FROM berka.card

UNION ALL
SELECT 'loan', COUNT(*)
FROM berka.loan

UNION ALL
SELECT 'orders', COUNT(*)
FROM berka.orders

UNION ALL
SELECT 'trans', COUNT(*)
FROM berka.trans;

SELECT
    (SELECT SUM(CAST(amount AS DECIMAL(12,2)))
     FROM financial_raw.trans) AS transactions_source,

    (SELECT SUM(amount)
     FROM berka.trans) AS transactions_cible,

    (SELECT SUM(CAST(amount AS DECIMAL(12,2)))
     FROM financial_raw.loan) AS prets_source,

    (SELECT SUM(amount)
     FROM berka.loan) AS prets_cible;
     
     SELECT
    MIN(loan_date) AS premier_pret,
    MAX(loan_date) AS dernier_pret
FROM berka.loan;

SELECT
    gender AS sexe,
    COUNT(*) AS nombre_clients
FROM berka.client
GROUP BY gender
ORDER BY gender;

COMMIT;

SET autocommit = 1;

SELECT
    (SELECT COUNT(*) FROM berka.account) AS comptes,
    (SELECT COUNT(*) FROM berka.client) AS clients,
    (SELECT COUNT(*) FROM berka.loan) AS prets,
    (SELECT COUNT(*) FROM berka.trans) AS transactions;