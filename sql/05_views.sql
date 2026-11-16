-- ============================================================================
-- PROJET BERKA | 05_views.sql
-- Vues analytiques pour MySQL 8 et Power BI
-- Prerequis : schemas financial_raw et berka charges ; analyses SQL effectuees.
-- Les vues ne modifient aucune donnee. CREATE OR REPLACE VIEW est rejouable.
-- ============================================================================

USE berka;

-- ============================================================================
-- 01. v_loan_360 : une ligne par pret, avec profil du titulaire et zone.
-- Les statuts B et D sont problematiques au sens du projet, pas des pertes.
-- La jointure OWNER evite d'attribuer le pret a un mandataire (DISPONENT).
-- ============================================================================
CREATE OR REPLACE VIEW v_loan_360 AS
SELECT
    l.loan_id,
    l.account_id,
    l.loan_date,
    l.amount AS loan_amount,
    l.duration AS duration_months,
    l.payments AS monthly_payment,
    l.status AS loan_status,
    s.label_fr AS loan_status_description,
    s.is_finished,
    s.is_problem,
    a.opened_date AS account_opened_date,
    di.district_id,
    di.district_name,
    di.region,
    c.client_id AS owner_client_id,
    c.gender AS owner_gender,
    c.birth_date AS owner_birth_date,
    TIMESTAMPDIFF(YEAR, c.birth_date, l.loan_date) AS owner_age_at_loan
FROM berka.loan AS l
JOIN berka.ref_loan_status AS s
    ON s.status = l.status
JOIN berka.account AS a
    ON a.account_id = l.account_id
JOIN berka.district AS di
    ON di.district_id = a.district_id
JOIN berka.disp AS dp
    ON dp.account_id = a.account_id
   AND dp.disp_type = 'OWNER'
JOIN berka.client AS c
    ON c.client_id = dp.client_id;

-- ============================================================
-- 02. VUE DES FLUX BANCAIRES MENSUELS
-- ============================================================

CREATE OR REPLACE VIEW v_monthly_flows AS
SELECT
    YEAR(t.trans_date) AS transaction_year,
    MONTH(t.trans_date) AS transaction_month,
    DATE_FORMAT(t.trans_date, '%Y-%m') AS `year_month`,

    COUNT(*) AS transaction_count,
    COUNT(DISTINCT t.account_id) AS active_accounts,

    SUM(
        CASE
            WHEN t.trans_type = 'PRIJEM'
            THEN t.amount ELSE 0
        END
    ) AS inflows,

    SUM(
        CASE
            WHEN t.trans_type IN ('VYDAJ', 'VYBER')
            THEN t.amount ELSE 0
        END
    ) AS outflows,

    SUM(
        CASE
            WHEN t.trans_type = 'PRIJEM'
            THEN t.amount
            WHEN t.trans_type IN ('VYDAJ', 'VYBER')
            THEN -t.amount
            ELSE 0
        END
    ) AS net_flow

FROM berka.trans AS t

GROUP BY
    YEAR(t.trans_date),
    MONTH(t.trans_date),
    DATE_FORMAT(t.trans_date, '%Y-%m');
    
-- ============================================================================
-- 03. v_account_summary : une ligne par compte.
-- Agregations calculees avec sous-requetes correlees indexees : cela evite
-- de multiplier artificiellement les montants en croisant trans/loan/orders.
-- Les colonnes de flux sont des montants cumules sur la periode observee.
-- ============================================================================
CREATE OR REPLACE VIEW v_account_summary AS
SELECT
    a.account_id,
    a.opened_date,
    a.frequency AS account_frequency,
    di.district_id,
    di.district_name,
    di.region,
    c.client_id AS owner_client_id,
    c.gender AS owner_gender,
    (SELECT COUNT(*) FROM berka.trans AS t
     WHERE t.account_id = a.account_id) AS transaction_count,
    COALESCE((SELECT SUM(t.amount) FROM berka.trans AS t
              WHERE t.account_id = a.account_id
                AND t.trans_type = 'PRIJEM'), 0) AS total_inflows,
    COALESCE((SELECT SUM(t.amount) FROM berka.trans AS t
              WHERE t.account_id = a.account_id
                AND t.trans_type IN ('VYDAJ', 'VYBER')), 0) AS total_outflows,
    (SELECT MIN(t.trans_date) FROM berka.trans AS t
     WHERE t.account_id = a.account_id) AS first_transaction_date,
    (SELECT MAX(t.trans_date) FROM berka.trans AS t
     WHERE t.account_id = a.account_id) AS last_transaction_date,
    (SELECT COUNT(*) FROM berka.loan AS l
     WHERE l.account_id = a.account_id) AS loan_count,
    (SELECT COUNT(*) FROM berka.loan AS l
     WHERE l.account_id = a.account_id
       AND l.status IN ('B', 'D')) AS problem_loan_count,
    COALESCE((SELECT SUM(l.amount) FROM berka.loan AS l
              WHERE l.account_id = a.account_id), 0) AS total_loan_amount,
    (SELECT COUNT(*) FROM berka.orders AS o
     WHERE o.account_id = a.account_id) AS standing_order_count
FROM berka.account AS a
JOIN berka.district AS di
    ON di.district_id = a.district_id
JOIN berka.disp AS dp
    ON dp.account_id = a.account_id
   AND dp.disp_type = 'OWNER'
JOIN berka.client AS c
    ON c.client_id = dp.client_id;

-- ============================================================================
-- CONTROLES A EXECUTER APRES LA CREATION (SELECT seulement).
-- Les effectifs attendus : 682 prets ; 72 mois ; 4 500 comptes.
-- ============================================================================
SELECT 'v_loan_360' AS view_name, COUNT(*) AS total FROM berka.v_loan_360
UNION ALL
SELECT 'v_monthly_flows', COUNT(*) FROM berka.v_monthly_flows
UNION ALL
SELECT 'v_account_summary', COUNT(*) FROM berka.v_account_summary;

-- Verifications de concordance des montants et volumes.
SELECT
    (SELECT COUNT(*) FROM berka.trans) AS raw_transaction_count,
    (SELECT SUM(transaction_count) FROM berka.v_monthly_flows) AS view_transaction_count,
    (SELECT COUNT(*) FROM berka.loan) AS raw_loan_count,
    (SELECT COUNT(*) FROM berka.v_loan_360) AS view_loan_count;
    
    USE berka;

SELECT
    (SELECT SUM(amount)
     FROM berka.loan) AS montant_prets_source,

    (SELECT SUM(loan_amount)
     FROM berka.v_loan_360) AS montant_prets_vue,

    (SELECT SUM(
        CASE WHEN trans_type = 'PRIJEM'
        THEN amount ELSE 0 END)
     FROM berka.trans) AS entrees_source,

    (SELECT SUM(inflows)
     FROM berka.v_monthly_flows) AS entrees_vue,

    (SELECT SUM(
        CASE WHEN trans_type IN ('VYDAJ', 'VYBER')
        THEN amount ELSE 0 END)
     FROM berka.trans) AS sorties_source,

    (SELECT SUM(outflows)
     FROM berka.v_monthly_flows) AS sorties_vue;

-- Exemples d'exploration pour Power BI / MySQL Workbench :
-- SELECT * FROM berka.v_loan_360 LIMIT 10;
-- SELECT * FROM berka.v_monthly_flows ORDER BY year_month LIMIT 12;
-- SELECT * FROM berka.v_account_summary LIMIT 10;
