CREATE TABLE app_user (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    -- 〔待決 Q-A4〕display_name VARCHAR(50) NULL,
    -- 〔待決 Q-A7〕email VARCHAR(254) NULL,  -- 決定合併帳號時加，並加 UNIQUE KEY uk_app_user_email (email)
    -- 〔待決 Q-A8〕role VARCHAR(16) NOT NULL,
    created_at  DATETIME(6) NOT NULL,
    updated_at  DATETIME(6) NOT NULL,
    PRIMARY KEY (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE local_credential (
    user_id        BIGINT       NOT NULL,
    login_id       VARCHAR(254) NOT NULL,  -- 〔Q-A4〕email 或使用者名稱；依定序不分大小寫比對
    password_hash  VARCHAR(255) NOT NULL,  -- DelegatingPasswordEncoder 格式，例如 {bcrypt}$2a$10$...
    created_at     DATETIME(6)  NOT NULL,
    updated_at     DATETIME(6)  NOT NULL,
    PRIMARY KEY (user_id),
    UNIQUE KEY uk_local_credential_login_id (login_id),
    CONSTRAINT fk_local_credential_app_user FOREIGN KEY (user_id) REFERENCES app_user (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE oauth_account (
    id                BIGINT       NOT NULL AUTO_INCREMENT,
    user_id           BIGINT       NOT NULL,
    provider          VARCHAR(32)  NOT NULL,  -- 第一階段只有 google
    provider_subject  VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,  -- Google ID token 的 sub
    -- 〔待決 Q-A2／Q-A7〕email VARCHAR(254) NULL,  -- Google 提供的 email，白名單或合併帳號需要時才存
    created_at        DATETIME(6)  NOT NULL,
    updated_at        DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_oauth_account_provider_subject (provider, provider_subject),
    KEY idx_oauth_account_user (user_id),
    CONSTRAINT fk_oauth_account_app_user FOREIGN KEY (user_id) REFERENCES app_user (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
