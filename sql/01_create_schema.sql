-- ==============================================================
-- PROJET BERKA — 01_create_schema.sql
-- MySQL 8.0.16+ | Schéma relationnel propre et contraint
-- Source : Berka / PKDD'99 Financial Dataset
-- Prérequis : les 8 tables brutes ont été chargées dans financial_raw.
-- IMPORTANT : aucune table de financial_raw n'est modifiée ici.
-- ==============================================================

CREATE DATABASE IF NOT EXISTS berka
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE berka;

-- 1. Districts : source financial_raw.district (A1 à A16)
CREATE TABLE IF NOT EXISTS district (
    district_id                  INT            NOT NULL,
    district_name                VARCHAR(50)    NOT NULL,
    region                       VARCHAR(50)    NOT NULL,
    inhabitants                  INT            NOT NULL CHECK (inhabitants > 0),
    municipalities_lt500         SMALLINT       NULL,
    municipalities_500_1999      SMALLINT       NULL,
    municipalities_2000_9999     SMALLINT       NULL,
    municipalities_ge10000       SMALLINT       NULL,
    cities                       SMALLINT       NULL,
    urban_ratio                  DECIMAL(5,2)   NULL CHECK (urban_ratio BETWEEN 0 AND 100),
    avg_salary                   INT            NULL CHECK (avg_salary > 0),
    unemployment_95              DECIMAL(5,2)   NULL,
    unemployment_96              DECIMAL(5,2)   NULL,
    entrepreneurs_per_1000       INT            NULL,
    crimes_95                    INT            NULL,
    crimes_96                    INT            NULL,
    PRIMARY KEY (district_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Comptes bancaires
CREATE TABLE IF NOT EXISTS account (
    account_id     INT          NOT NULL,
    district_id    INT          NOT NULL,
    frequency      VARCHAR(20)  NOT NULL
        CHECK (frequency IN ('POPLATEK MESICNE', 'POPLATEK TYDNE', 'POPLATEK PO OBRATU')),
    opened_date    DATE         NOT NULL,
    PRIMARY KEY (account_id),
    KEY idx_account_district (district_id),
    CONSTRAINT fk_account_district FOREIGN KEY (district_id)
        REFERENCES district (district_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Clients
CREATE TABLE IF NOT EXISTS client (
    client_id      INT         NOT NULL,
    birth_date     DATE        NOT NULL,
    gender         CHAR(1)     NOT NULL CHECK (gender IN ('F', 'M')),
    district_id    INT         NOT NULL,
    PRIMARY KEY (client_id),
    KEY idx_client_district (district_id),
    CONSTRAINT fk_client_district FOREIGN KEY (district_id)
        REFERENCES district (district_id) ON DELETE RESTRICT ON UPDATE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Relations entre clients et comptes
CREATE TABLE IF NOT EXISTS disp (
    disp_id      INT          NOT NULL,
    client_id    INT          NOT NULL,
    account_id   INT          NOT NULL,
    disp_type    VARCHAR(10)  NOT NULL CHECK (disp_type IN ('OWNER', 'DISPONENT')),
    PRIMARY KEY (disp_id),
    KEY idx_disp_client (client_id),
    KEY idx_disp_account (account_id),
    CONSTRAINT fk_disp_client FOREIGN KEY (client_id)
        REFERENCES client (client_id) ON DELETE RESTRICT,
    CONSTRAINT fk_disp_account FOREIGN KEY (account_id)
        REFERENCES account (account_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 5. Cartes bancaires
CREATE TABLE IF NOT EXISTS card (
    card_id       INT          NOT NULL,
    disp_id       INT          NOT NULL,
    card_type     VARCHAR(10)  NOT NULL CHECK (card_type IN ('junior', 'classic', 'gold')),
    issued_date   DATE         NOT NULL,
    PRIMARY KEY (card_id),
    KEY idx_card_disp (disp_id),
    CONSTRAINT fk_card_disp FOREIGN KEY (disp_id)
        REFERENCES disp (disp_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 6. Prêts bancaires
CREATE TABLE IF NOT EXISTS loan (
    loan_id      INT            NOT NULL,
    account_id   INT            NOT NULL,
    loan_date    DATE           NOT NULL,
    amount       DECIMAL(12,2)  NOT NULL CHECK (amount > 0),
    duration     SMALLINT       NOT NULL CHECK (duration IN (12,24,36,48,60)),
    payments     DECIMAL(10,2)  NOT NULL CHECK (payments > 0),
    status       CHAR(1)        NOT NULL CHECK (status IN ('A','B','C','D')),
    PRIMARY KEY (loan_id),
    KEY idx_loan_account (account_id),
    KEY idx_loan_status (status),
    CONSTRAINT fk_loan_account FOREIGN KEY (account_id)
        REFERENCES account (account_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 7. Ordres de paiement permanents (orders, pour éviter le mot réservé ORDER)
CREATE TABLE IF NOT EXISTS orders (
    order_id      INT            NOT NULL,
    account_id    INT            NOT NULL,
    bank_to       CHAR(2)        NULL,
    account_to    VARCHAR(20)    NULL,
    amount        DECIMAL(12,2)  NOT NULL CHECK (amount >= 0),
    k_symbol      VARCHAR(20)    NULL,
    PRIMARY KEY (order_id),
    KEY idx_orders_account (account_id),
    CONSTRAINT fk_orders_account FOREIGN KEY (account_id)
        REFERENCES account (account_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 8. Transactions : index utile pour les analyses compte / période
CREATE TABLE IF NOT EXISTS trans (
    trans_id        INT            NOT NULL,
    account_id      INT            NOT NULL,
    trans_date      DATE           NOT NULL,
    trans_type      VARCHAR(10)    NOT NULL CHECK (trans_type IN ('PRIJEM','VYDAJ','VYBER')),
    operation       VARCHAR(20)    NULL,
    amount          DECIMAL(12,2)  NOT NULL CHECK (amount >= 0),
    balance         DECIMAL(12,2)  NOT NULL,
    k_symbol        VARCHAR(20)    NULL,
    bank            CHAR(2)        NULL,
    partner_account VARCHAR(20)    NULL,
    PRIMARY KEY (trans_id),
    KEY idx_trans_account_date (account_id, trans_date),
    KEY idx_trans_date (trans_date),
    CONSTRAINT fk_trans_account FOREIGN KEY (account_id)
        REFERENCES account (account_id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 9. Table de correspondance des statuts de prêts
CREATE TABLE IF NOT EXISTS ref_loan_status (
    status       CHAR(1)      NOT NULL,
    label_fr     VARCHAR(60)  NOT NULL,
    is_finished  TINYINT(1)   NOT NULL,
    is_problem   TINYINT(1)   NOT NULL,
    PRIMARY KEY (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO ref_loan_status (status, label_fr, is_finished, is_problem) VALUES
    ('A', 'Terminé, remboursé', 1, 0),
    ('B', 'Terminé, non remboursé', 1, 1),
    ('C', 'En cours, sain', 0, 0),
    ('D', 'En cours, en difficulté', 0, 1);

-- ==============================================================
-- Vérifications — attendues : 9 tables et 4 statuts de prêts
-- ==============================================================
SHOW TABLES FROM berka;
SHOW CREATE TABLE berka.loan;
SELECT * FROM berka.ref_loan_status ORDER BY status;
