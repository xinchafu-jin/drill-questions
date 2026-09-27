package io.github.xinchafujin.drill;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

@Import(TestcontainersConfiguration.class)
@SpringBootTest
class FlywayMigrationTests {

    private static final Set<String> EXPECTED_INDEXES = Set.of(
            "local_credential.uk_local_credential_login_id",
            "oauth_account.uk_oauth_account_provider_subject",
            "oauth_account.idx_oauth_account_user",
            "subject.uk_subject_code",
            "unit.uk_unit_subject_code",
            "question.uk_question_key",
            "question.idx_question_unit_status",
            "question_tag.idx_question_tag_tag",
            "attempt.uk_attempt_user_client_attempt",
            "attempt.idx_attempt_user_created",
            "attempt.idx_attempt_user_question",
            "attempt.idx_attempt_question");

    private static final Set<String> EXPECTED_FOREIGN_KEYS = Set.of(
            "local_credential.fk_local_credential_app_user",
            "oauth_account.fk_oauth_account_app_user",
            "unit.fk_unit_subject",
            "question.fk_question_unit",
            "question_tag.fk_question_tag_question",
            "attempt.fk_attempt_app_user",
            "attempt.fk_attempt_question");

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Test
    void appliesAllVersionedMigrationsSuccessfully() {
        List<String> versions = jdbcTemplate.queryForList(
                "SELECT version FROM flyway_schema_history WHERE success = 1 AND version IS NOT NULL ORDER BY installed_rank",
                String.class);

        assertThat(versions).containsExactly("1", "2", "3");
    }

    @Test
    void createsEveryIndexListedInSpec() {
        List<String> indexes = jdbcTemplate.queryForList("""
                SELECT DISTINCT CONCAT(TABLE_NAME, '.', INDEX_NAME)
                FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE()""", String.class);

        assertThat(indexes).containsAll(EXPECTED_INDEXES);
    }

    @Test
    void createsEveryForeignKeyListedInSpec() {
        List<String> foreignKeys = jdbcTemplate.queryForList("""
                SELECT CONCAT(TABLE_NAME, '.', CONSTRAINT_NAME)
                FROM information_schema.REFERENTIAL_CONSTRAINTS
                WHERE CONSTRAINT_SCHEMA = DATABASE()""", String.class);

        assertThat(foreignKeys).containsExactlyInAnyOrderElementsOf(EXPECTED_FOREIGN_KEYS);
    }
}
