# 03 Judge 介面與各題型 payload

後端以 `Judge` 介面判題：每個實作宣告自己負責的 `judge_type`，`JudgeRegistry` 依題目的 `judge_type` 找到實作（文件：題目分類與資料結構）。第一階段完整定義 `choice` 與 `fill`（§4、§5）；其他題型是草案（§6），在對應階段開始前定稿。

## 1. 判題流程

| 時機 | 呼叫 | 目的 | 文件依據 |
| --- | --- | --- | --- |
| 匯入題目 | `validatePayload` | 檢查題型專屬資料 | 驗證：JSON Schema 檢查欄位 |
| 匯入題目 | `referenceAnswer` → `judge` | 標準答案必須判為 `CORRECT` | 驗證：標準答案實際跑一次判題器 |
| 出題 | `toPublicPayload` | 移除答案、隱藏資料後才送到瀏覽器 | check 腳本提交時才送進容器；正式成績以後端為準 |
| 作答 | `judge` | 產生 `Verdict`、回饋、解答 | 後端判題 |

判題器本身不寫資料庫。作答紀錄由呼叫端（作答服務）寫入 `attempt`（01 §3 V3）。

## 2. Java 介面

套件根名稱待定（Q-G2），以下以 `<root>` 表示。JSON 一律用 Jackson 3（`tools.jackson.databind.JsonNode`）。

### 2.1 型別

```java
package <root>.judge;

import java.util.List;
import java.util.Optional;
import java.util.Set;
import tools.jackson.databind.JsonNode;

/** 判題器。實作必須是無狀態、執行緒安全的 Spring Bean。 */
public interface Judge {

    /** 此實作負責的 judge_type，例如 "choice"。同一個值只能由一個 Bean 宣告。 */
    Set<String> supportedTypes();

    /** 匯入時檢查 payload。回傳空清單代表合法；不以例外表示驗證失敗。 */
    List<Violation> validatePayload(String judgeType, JsonNode payload);

    /** 標準答案，格式與使用者提交的 answer 相同；沒有標準答案的題型回傳 empty。 */
    Optional<JsonNode> referenceAnswer(String judgeType, JsonNode payload);

    /** 可送到瀏覽器的 payload：移除答案、隱藏測資、check 腳本等。 */
    JsonNode toPublicPayload(String judgeType, JsonNode payload);

    /** 判題。answer 不符合題型格式時丟 InvalidAnswerException。 */
    JudgeResult judge(JudgeRequest request);
}
```

```java
package <root>.judge;

import java.util.List;
import tools.jackson.databind.JsonNode;

/** userId 第一階段不使用，保留給沙箱等需要使用者情境的判題器。 */
public record JudgeRequest(QuestionSnapshot question, JsonNode answer, long userId) {}

public record QuestionSnapshot(
        long id, String key, int revision, String judgeType, String stem, JsonNode payload) {}

/** feedback 可直接給使用者看且不含正解；solution 是正解，是否回傳前端由 API 依 Q-P4 決定。 */
public record JudgeResult(Verdict verdict, JsonNode feedback, JsonNode solution) {}

/** 第一階段只有兩個值；後續階段需要的值（自評、只回饋、PENDING）在該階段規格新增。 */
public enum Verdict { CORRECT, WRONG }

/** pointer 是 RFC 6901 JSON Pointer，相對於被檢查的 payload 或 answer。 */
public record Violation(String pointer, String code, String message) {}

public class InvalidAnswerException extends RuntimeException {
    private final List<Violation> violations;

    public InvalidAnswerException(List<Violation> violations) {
        super("Invalid answer");
        this.violations = List.copyOf(violations);
    }

    public List<Violation> violations() {
        return violations;
    }
}

public class UnknownJudgeTypeException extends RuntimeException {
    public UnknownJudgeTypeException(String judgeType) {
        super("Unknown judge type: " + judgeType);
    }
}
```

每個型別放在自己的檔案（Java 規定 public 型別一檔一個）。

### 2.2 JudgeRegistry

```java
package <root>.judge;

@Component
public class JudgeRegistry {

    /** 收集所有 Judge Bean，依 supportedTypes() 建立對照表。
     *  同一個 type 被兩個 Bean 宣告時丟 IllegalStateException，讓應用程式啟動失敗，
     *  訊息包含重複的 type 與兩個類別名稱。 */
    public JudgeRegistry(List<Judge> judges) { ... }

    /** 找不到時丟 UnknownJudgeTypeException。 */
    public Judge get(String judgeType) { ... }

    public Set<String> registeredTypes() { ... }
}
```

### 2.3 規則

1. 判題器無狀態、執行緒安全，不寫資料庫。第一階段的判題器也不呼叫任何外部服務。
2. `judge()` 可以假設 payload 已通過 `validatePayload`（匯入時檢查過）。若執行時發現 payload 不合法，丟 `IllegalStateException`（回應 500，代表資料有問題）。
3. `judge()` 一律先檢查 answer 的格式與語意，不合法時丟 `InvalidAnswerException`。
4. 新增題型 = 新增一個 `Judge` Bean + payload 與 answer 的 JSON Schema + 測試。不得修改既有判題器、`JudgeRegistry` 或作答 API（文件：新增題型不需改動既有程式）。前端另需要該題型的元件。
5. 實作內部以 `JsonMapper.treeToValue` 把 `JsonNode` 轉成自己的 record 再處理。
6. 第二階段起的判題器（正則、SQL、沙箱、AI）必須自行限制執行時間，逾時值見 Q-L3、Q-L4、Q-L8、Q-L9。
7. Q-J1 決定前，choice 與 fill 可以各自一個類別，也可以同一個類別；介面兩種都支援。

### 2.4 錯誤對應

| 情況 | 時機 | 對應 |
| --- | --- | --- |
| `InvalidAnswerException` | 作答 | 400，`code: INVALID_ANSWER`；`errors[].pointer` 加上 `/answer` 前綴（02 §2） |
| `validatePayload` 回傳違規 | 匯入 | 該檔的錯誤，`pointer` 加上 `/payload` 前綴 |
| 標準答案判為 `WRONG` | 匯入 | 該檔的錯誤 `REFERENCE_ANSWER_WRONG` |
| `UnknownJudgeTypeException` | 匯入 | 該檔的錯誤 `UNKNOWN_JUDGE_TYPE` |
| `UnknownJudgeTypeException` | 作答（資料庫有未註冊的題型） | 500 |

## 3. 題目檔（YAML）

文件：每題一個 YAML 檔，放在獨立的題庫 repo（題目即程式碼）。

### 3.1 欄位

YAML／JSON 欄位用 camelCase，資料庫欄位用 snake_case（規格慣例），例如 `judgeType` ↔ `judge_type`。

| 欄位 | 型別 | 必填 | 存到 | 來源 | 待決 |
| --- | --- | --- | --- | --- | --- |
| `key` | string | 待決 | `question.question_key` | 規格：冪等匯入需要穩定識別碼 | Q-I3 |
| `subject` | string | 是 | 對應 `subject.code` | 文件：科目 → 單元 → 題目 | Q-M1、Q-M2 |
| `unit` | string | 是 | 對應 `unit.code` | 文件 | Q-M2 |
| `judgeType` | string | 是 | `question.judge_type` | 文件 | — |
| `difficulty` | integer | 是 | `question.difficulty` | 文件 | Q-M3 |
| `device` | string | 是 | `question.device` | 文件 | Q-M4 |
| `version` | string | 否 | `question.version` | 文件 | Q-M5 |
| `tags` | string[] | 否 | `question_tag.tag` | 文件 | Q-M6 |
| `source` | string | 是 | `question.source` | 文件 | Q-I8 |
| `license` | string | 是 | `question.license` | 文件 | Q-I8 |
| `stem` | string | 是 | `question.stem` | 規格：題目必要內容 | Q-M8 |
| `payload` | object | 是 | `question.payload` | 文件 | §4～§6 |

尚未納入、待決定後加入的欄位：`language`（Q-M7）、`explanation`（Q-M9）、審核狀態（Q-I7）。

### 3.2 範例與 JSON Schema

- 題目檔：[schemas/question.schema.json](schemas/question.schema.json)（依 `judgeType` 套用 payload schema）
- 範例：[examples/questions/](examples/questions/)

```yaml
# yaml-language-server: $schema=../../schemas/question.schema.json
key: mysql-innodb-clustered-index   # 〔待決 Q-I3〕
subject: mysql                      # 〔待決 Q-M1〕
unit: index
judgeType: choice
difficulty: 2                       # 〔待決 Q-M3〕
device: mobile                      # 〔待決 Q-M4〕
version: MySQL 8.0
tags: [innodb, index]
source: https://example.com/original  # 〔待決 Q-I8〕
license: MIT                          # 〔待決 Q-I8〕
stem: InnoDB 的聚簇索引（clustered index）使用哪一種資料結構？
payload:
  options:
    - id: a
      text: Hash
    - id: b
      text: B+Tree
    - id: c
      text: R-Tree
    - id: d
      text: 跳躍串列（Skip List）
  answer: [b]
```

驗證紀錄（2026-09-25）：以 python-jsonschema 4.26.0（draft 2020-12）檢查，5 個 schema 本身合法；2 個範例通過；12 個錯誤範例（缺少必填欄位、多出欄位、只有一個選項、答案為空、選項 id 大寫、device 不在清單、difficulty 不是整數、judgeType 與 payload 不符、YAML 數字 id 沒加引號、可接受答案為空字串、沒有空格、題幹過長）全部被拒絕。

實作時把 `schemas/` 複製到後端資源目錄並保持相對路徑，之後以程式內的版本為準（放置位置另見 Q-I5）。

### 3.3 content_hash 算法

1. 以 Jackson 3 的 `YAMLMapper` 把檔案解析成 JSON 樹。
2. 移除 `key`（識別碼不算內容）。
3. 物件的 key 依 Unicode code point 遞迴排序；陣列保持原順序。
4. 輸出成不含空白的 JSON，編碼 UTF-8。
5. 取 SHA-256，存 64 字元小寫 hex 到 `question.content_hash`。

YAML 的註解與排版不影響雜湊；任何欄位的值改變都會讓 `revision` 加 1。

### 3.4 匯入時的語意檢查

以下規則 JSON Schema 表達不了，由匯入程式負責：

| code | 規則 |
| --- | --- |
| `YAML_SYNTAX` | 檔案不是合法 YAML |
| `SCHEMA_VIOLATION` | 不符合 question.schema.json（`message` 帶 schema 錯誤） |
| `UNKNOWN_JUDGE_TYPE` | `judgeType` 沒有已註冊的 Judge |
| `UNKNOWN_SUBJECT`、`UNKNOWN_UNIT` | 科目或單元不存在；是否改為自動建立見 Q-M2 |
| `DUPLICATE_KEY` | 同一批檔案中識別碼重複（Q-I3） |
| `DUPLICATE_TAG` | `tags` 不分大小寫重複（資料庫定序不分大小寫） |
| payload 語意規則 | 各題型 §4.4、§5.4 |
| `REFERENCE_ANSWER_WRONG` | 標準答案判為 `WRONG` |
| 重複題目 | 規則與處置見 Q-I6 |

## 4. choice（第一階段）

文件：知識型，判題方式為選擇。

### 4.1 payload

| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| `options` | array，至少 2 項 | 選項；上限見 Q-J2 |
| `options[].id` | string，`^[a-z0-9]{1,8}$` | 改版時必須保持不變：作答紀錄以 id 記錄選了哪個選項，日後用來找「多數人選同一個錯誤選項」（文件：上線後修正） |
| `options[].text` | string | 格式見 Q-M8 |
| `answer` | string[]，至少 1 項 | 正確選項的 id；單選或複選見 Q-J2 |

```json
{
  "options": [
    { "id": "a", "text": "Hash" },
    { "id": "b", "text": "B+Tree" },
    { "id": "c", "text": "R-Tree" },
    { "id": "d", "text": "跳躍串列（Skip List）" }
  ],
  "answer": ["b"]
}
```

Schema：[schemas/payload/choice.schema.json](schemas/payload/choice.schema.json)

### 4.2 public payload

移除 `answer`：

```json
{
  "options": [
    { "id": "a", "text": "Hash" },
    { "id": "b", "text": "B+Tree" },
    { "id": "c", "text": "R-Tree" },
    { "id": "d", "text": "跳躍串列（Skip List）" }
  ]
}
```

- 〔待決 Q-J2〕若允許複選，加上 `"multiple": true|false`（由 `answer` 的數量推得），讓前端決定單選或複選介面；若要打亂選項，決定在這裡或在前端處理。
- 〔待決 Q-J6〕若決定離線判題，決定範圍內的題目需保留 `answer`。

### 4.3 answer

```json
{ "selected": ["b"] }
```

Schema：[schemas/answer/choice.schema.json](schemas/answer/choice.schema.json)

### 4.4 語意檢查

| 對象 | code | 條件 |
| --- | --- | --- |
| payload | `SCHEMA_VIOLATION` | 不符合 payload schema |
| payload | `OPTION_ID_DUPLICATE` | `options` 內 id 重複 |
| payload | `ANSWER_UNKNOWN_OPTION` | `answer` 參照不存在的選項 |
| answer | `SCHEMA_VIOLATION` | 不符合 answer schema |
| answer | `ANSWER_UNKNOWN_OPTION` | `selected` 參照不存在的選項 |

### 4.5 判定、回饋、解答

- `selected` 與 `answer` 的集合相同 → `CORRECT`，否則 `WRONG`。
- `feedback`：`{}`（選擇題沒有額外回饋）。
- `solution`：`{ "answer": ["b"] }`。
- 標準答案：`{ "selected": <payload.answer> }`。

## 5. fill（第一階段）

文件：知識型，判題方式為填空。

### 5.1 payload

| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| `blanks` | array，至少 1 項 | 空格；是否允許多格見 Q-J4 |
| `blanks[].id` | string，`^[a-z0-9]{1,8}$` | YAML 中數字形式要加引號，例如 `id: "1"` |
| `blanks[].accepted` | string[]，至少 1 項 | 可接受的答案；比對規則見 Q-J3 |

```json
{
  "blanks": [
    { "id": "1", "accepted": ["innodb_buffer_pool_size"] }
  ]
}
```

Schema：[schemas/payload/fill.schema.json](schemas/payload/fill.schema.json)

題幹中如何標出空格位置見 Q-J4。

### 5.2 public payload

移除 `accepted`：

```json
{
  "blanks": [
    { "id": "1" }
  ]
}
```

### 5.3 answer

```json
{ "blanks": { "1": "innodb_buffer_pool_size" } }
```

Schema：[schemas/answer/fill.schema.json](schemas/answer/fill.schema.json)。允許空字串（使用者沒填，判為該格錯）。

### 5.4 語意檢查

| 對象 | code | 條件 |
| --- | --- | --- |
| payload | `SCHEMA_VIOLATION` | 不符合 payload schema |
| payload | `BLANK_ID_DUPLICATE` | `blanks` 內 id 重複 |
| payload | `ACCEPTED_DUPLICATE` | 同一格的可接受答案經 Q-J3 正規化後重複 |
| answer | `SCHEMA_VIOLATION` | 不符合 answer schema |
| answer | `ANSWER_BLANKS_MISMATCH` | `blanks` 的 key 與題目的空格 id 不完全相同 |

### 5.5 判定、回饋、解答

- 每一格：使用者輸入與任一個 `accepted` 經 Q-J3 的正規化後相等，該格正確。Q-J3 決定前不得自行加入任何正規化（連去除空白都不做），T08 因此被 Q-J3 阻擋。
- 只有一格：該格正確 → `CORRECT`，否則 `WRONG`。多格的判定見 Q-J4。
- `feedback`：`{ "blanks": { "1": true } }`（每格是否正確）。
- `solution`：`{ "blanks": { "1": ["innodb_buffer_pool_size"] } }`。
- 標準答案：每格取 `accepted[0]`，例如 `{ "blanks": { "1": "innodb_buffer_pool_size" } }`。

## 6. 後續題型草案

以下格式只是起點，JSON 範例合法但尚無 JSON Schema。各階段開始前依待決問題定稿，並補上 schema、語意檢查與範例。

### 6.1 testcase：正則（第二階段）

文件：Java 用 `java.util.regex`、JS 用 GraalJS，兩者都設逾時防 ReDoS；前端即時預覽用瀏覽器 `RegExp`（Web Worker），正式成績以後端為準；每題標明完整匹配、部分匹配、取出所有或取代；另有「差異題」；payload 存支援的正則引擎；錯誤回饋顯示未通過的測資。

```json
{
  "kind": "regex",
  "engines": ["java", "js"],
  "operation": "fullMatch",
  "cases": [
    { "input": "2026-09-25", "expected": true },
    { "input": "2026/09/25", "expected": false }
  ],
  "solution": { "pattern": "\\d{4}-\\d{2}-\\d{2}" }
}
```

- `operation`：`fullMatch`（完整匹配）、`find`（部分匹配）、`findAll`（取出所有）、`replace`（取代）。`expected` 的型別依序為 boolean、boolean、string[]、string。
- answer 草案：`{ "engine": "java", "pattern": "\\d{4}-\\d{2}-\\d{2}" }`
- feedback 草案：`{ "failedCases": [ { "index": 1, "input": "2026/09/25", "expected": false, "actual": true } ] }`
- public payload：移除 `solution`（以及隱藏測資，若有）。
- 技術提醒：`java.util.regex` 沒有內建逾時，常見做法是包一層會檢查期限的 `CharSequence`；GraalJS 需在獨立 `Context` 中執行並可從外部取消。
- 待決：Q-L2（是否拆 judge_type）、Q-L3（引擎、flags、取代字串、隱藏測資、逾時、差異題、GraalJS 記憶體）。

### 6.2 testcase：SQL（第三階段）

文件：以 JDBC 連練習用 MySQL（與系統 MySQL 分開），交易內執行後 rollback，比對結果集；資料集用 Sakila、Chinook；錯誤回饋並排比對結果並標出差異列。

```json
{
  "kind": "sql",
  "dataset": "sakila",
  "solution": "SELECT actor_id, first_name FROM actor WHERE actor_id <= 3 ORDER BY actor_id"
}
```

- answer 草案：`{ "sql": "SELECT actor_id, first_name FROM actor WHERE actor_id <= 3" }`
- feedback 草案：

```json
{
  "expected": { "columns": ["actor_id", "first_name"], "rows": [[1, "PENELOPE"], [2, "NICK"], [3, "ED"]] },
  "actual": { "columns": ["actor_id", "first_name"], "rows": [[1, "PENELOPE"], [2, "NICK"]] },
  "diffRows": [2]
}
```

- 風險：MySQL 的 DDL 會隱式提交，rollback 擋不住，必須以練習資料庫帳號的權限限制。
- 待決：Q-L4（允許的語句、比對規則、期望結果來源、資料集建立與重置）。

### 6.3 vocab（第四階段）

文件：托福單字，間隔重複排程；發音用 Web Speech API；單字資料找開源授權資料；可離線判題。

```json
{
  "word": "ubiquitous",
  "meanings": [ { "pos": "adj.", "definition": "無所不在的" } ],
  "examples": ["Smartphones have become ubiquitous."]
}
```

- answer、判定與欄位清單都待決：Q-L1（演算法與評分尺度）、Q-L5（互動方式、資料來源）、Q-J6（離線）。

### 6.4 flashcard（第四階段）

文件：八股文記憶卡自評；間隔重複套用到記憶卡與所有錯題。

```json
{
  "back": "Spring 的 @Transactional 透過 AOP 代理生效；同一個類別內部的方法呼叫不經過代理，交易不會啟動。",
  "keyPoints": ["透過 AOP 代理生效", "內部呼叫不經過代理"]
}
```

- answer 草案：使用者的自評等級，尺度依 Q-L1（SM-2 為 0～5）。
- 需要新的 `Verdict` 值或另一種紀錄方式；待決：Q-L1、Q-L6。

### 6.5 typing（第五階段）

文件：Angular 監聽 keydown，RxJS 計算即時速度與正確率；後端只存成績與防作弊；倉頡內建五代碼表，輸入字根碼並提示拆碼；英打排行榜依裝置分開。

```json
{ "mode": "english", "text": "The quick brown fox jumps over the lazy dog." }
```

```json
{ "mode": "cangjie", "text": "日月金木水火土" }
```

- answer 草案：`{ "durationMs": 31000, "typed": "The quick brown fox jumps over the lazy dog.", "device": "mobile" }`，防作弊所需的按鍵資料待決。
- 速度與正確率由前端計算（文件），後端只驗證合理性；判定語意待決：Q-L7。

### 6.6 sandbox（第六階段）

文件：每題 = 基礎映像 + setup 腳本 + 題目說明 + check 腳本；每次作答開新容器，答完整個銷毀；check 腳本提交時才從外部送進容器，檢查狀態而非指令；Linux、Git、MySQL 維運用 gVisor，Docker 題用 Sysbox；程式透過 `SandboxClient` 介面呼叫沙箱。

```json
{
  "image": "drill/linux-basic:1",
  "runtime": "gvisor",
  "setup": "#!/bin/sh\nset -e\nmkdir -p /home/player/project\n",
  "check": "#!/bin/sh\ntest -d /home/player/project/logs\n",
  "solution": "#!/bin/sh\nmkdir -p /home/player/project/logs\n"
}
```

- 題目說明就是 `stem`。`runtime` 為 `gvisor` 或 `sysbox`。
- `solution` 供匯入時自我檢查（文件：沙箱題完全由判題器驗證）。
- answer 草案：`{ "sandboxSessionId": 123 }`。
- public payload：至少移除 `check` 與 `solution`；`setup` 能否公開見 Q-L8。
- 容器限制（`--network none`、記憶體與 CPU 上限、`--pids-limit`、`--cap-drop ALL`、非 root）由沙箱統一套用（文件）；是否允許逐題調整見 Q-L8。
- 待決：Q-J7（同步或非同步）、Q-L8。

### 6.7 ai_rubric（第七階段）

文件：AI 批改用 Spring AI，依事先寫好的要點清單評分，只作回饋不列成績。

```json
{
  "keyPoints": [
    { "id": "p1", "text": "@Transactional 透過 AOP 代理生效" },
    { "id": "p2", "text": "同一類別內部呼叫不經過代理，交易不會啟動" }
  ]
}
```

- answer 草案：`{ "text": "使用者的回答" }`
- feedback 草案：`{ "points": [ { "id": "p1", "covered": true, "comment": "有提到代理" } ] }`
- 「不列成績」需要新的 `Verdict` 值（例如只回饋）；待決：Q-J7、Q-L6、Q-L9。

### 6.8 尚未定義

- 預測輸出、排序題：文件列為手機版題型，但沒有對應的 judge_type，見 Q-J5。
