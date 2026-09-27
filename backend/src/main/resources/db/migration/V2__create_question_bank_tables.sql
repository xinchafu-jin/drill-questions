CREATE TABLE subject (
    id          BIGINT      NOT NULL AUTO_INCREMENT,
    code        VARCHAR(32) NOT NULL,  -- 〔Q-M1〕例如 mysql；題目檔以此參照
    name        VARCHAR(64) NOT NULL,  -- 顯示名稱〔Q-F2〕若介面雙語需擴充
    sort_order  INT         NOT NULL,
    created_at  DATETIME(6) NOT NULL,
    updated_at  DATETIME(6) NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_subject_code (code)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE unit (
    id          BIGINT       NOT NULL AUTO_INCREMENT,
    subject_id  BIGINT       NOT NULL,
    code        VARCHAR(64)  NOT NULL,  -- 科目內唯一
    name        VARCHAR(128) NOT NULL,
    sort_order  INT          NOT NULL,
    created_at  DATETIME(6)  NOT NULL,
    updated_at  DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_unit_subject_code (subject_id, code),
    CONSTRAINT fk_unit_subject FOREIGN KEY (subject_id) REFERENCES subject (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE question (
    id            BIGINT       NOT NULL AUTO_INCREMENT,
    question_key  VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,  -- 〔Q-I3〕題庫中的穩定識別碼
    unit_id       BIGINT       NOT NULL,
    judge_type    VARCHAR(32)  NOT NULL,  -- 已註冊的 Judge 類型，第一階段為 choice、fill
    stem          TEXT         NOT NULL,  -- 題幹〔Q-M8〕格式
    difficulty    SMALLINT     NOT NULL,  -- 〔Q-M3〕尺度與是否必填
    device        VARCHAR(16)  NOT NULL,  -- 〔Q-M4〕mobile、desktop
    version       VARCHAR(64)  NULL,      -- 適用版本，例如 MySQL 8.0〔Q-M5〕
    source        VARCHAR(512) NOT NULL,  -- 出處〔Q-I8〕
    license       VARCHAR(64)  NOT NULL,  -- 授權〔Q-I8〕
    payload       JSON         NOT NULL,  -- 題型專屬資料（03-judge.md），含答案，不得直接回傳前端
    status        VARCHAR(16)  NOT NULL,  -- ACTIVE；其他值見 Q-M10
    revision      INT          NOT NULL,  -- 新題為 1，內容每變動一次 +1
    content_hash  CHAR(64)     CHARACTER SET ascii COLLATE ascii_bin NOT NULL,  -- 題目檔正規化後的 SHA-256（hex）
    -- 〔待決 Q-M7〕language VARCHAR(16) NOT NULL,  -- zh-TW、en
    -- 〔待決 Q-M9〕explanation TEXT NULL,
    created_at    DATETIME(6)  NOT NULL,
    updated_at    DATETIME(6)  NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_question_key (question_key),
    KEY idx_question_unit_status (unit_id, status),
    CONSTRAINT fk_question_unit FOREIGN KEY (unit_id) REFERENCES unit (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE question_tag (
    question_id  BIGINT      NOT NULL,
    tag          VARCHAR(64) NOT NULL,
    PRIMARY KEY (question_id, tag),
    KEY idx_question_tag_tag (tag),
    CONSTRAINT fk_question_tag_question FOREIGN KEY (question_id) REFERENCES question (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
