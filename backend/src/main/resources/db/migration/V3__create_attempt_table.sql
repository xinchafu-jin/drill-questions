CREATE TABLE attempt (
    id                 BIGINT      NOT NULL AUTO_INCREMENT,
    user_id            BIGINT      NOT NULL,
    question_id        BIGINT      NOT NULL,
    question_revision  INT         NOT NULL,  -- 作答當下的 question.revision
    client_attempt_id  CHAR(36)    CHARACTER SET ascii COLLATE ascii_bin NOT NULL,  -- 前端產生的 UUID，重送時去重
    answer             JSON        NOT NULL,  -- 使用者提交內容（03-judge.md）
    verdict            VARCHAR(16) NOT NULL,  -- 第一階段：CORRECT、WRONG
    feedback           JSON        NULL,      -- Judge 回傳的回饋細節
    -- 〔待決 Q-P7〕client_duration_ms INT NULL,
    created_at         DATETIME(6) NOT NULL,  -- 伺服器判題完成的時間（UTC）
    PRIMARY KEY (id),
    UNIQUE KEY uk_attempt_user_client_attempt (user_id, client_attempt_id),
    KEY idx_attempt_user_created (user_id, created_at),
    KEY idx_attempt_user_question (user_id, question_id),
    KEY idx_attempt_question (question_id),
    CONSTRAINT fk_attempt_app_user FOREIGN KEY (user_id) REFERENCES app_user (id),
    CONSTRAINT fk_attempt_question FOREIGN KEY (question_id) REFERENCES question (id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
