# AI 代理規範（草稿）

> 這是草稿。標〔提案〕的規則是規劃文件沒寫、由本草稿提出的，請確認或刪除；標〔待決 Q-xx〕的地方等 [06-open-questions.md](06-open-questions.md) 決定後補上。定稿後放到 repo 根目錄的 `AGENTS.md`，另建只含 `@AGENTS.md` 一行的 `CLAUDE.md` 與 `GEMINI.md`（Q-R2），並刪除這段說明。

## 專案

手機優先的刷題系統，主打「等餐時刷幾題」，同時是後端 + AI 的求職作品集。規格在 `docs/spec/`：資料表 01、API 02、判題 03、第一階段任務 04、待決問題 06。

## 工作方式

1. 一次只做一個指派的任務（04 的 `Txx`）。開工前確認相依任務已完成，且「阻擋」列出的待決問題在 06 都已填上「決定」。
2. 規格沒寫、互相矛盾、或待決問題還沒決定時，停下來問，並附上選項。不要自行假設，不要自己把待決問題改成已決定，也不要把「建議」當成「決定」。
3. 只做任務範圍內的事：不加額外功能、不預先抽象、不順手重構。
4. 任務預估超過半天時，先提出拆分方式再動手。
5. 完成時必須滿足 04 的「共同完成條件」與該任務的驗收條件，並在 PR 描述附上證據。
6. 套用已決定的待決問題而需要修改 `docs/spec/` 時，在同一個 PR 說明改了哪些段落。〔提案〕

## 保留給人類親手寫的範圍

以下任務由人類親手寫（Q-R1）：T06、T10、T12、T17。AI 在這些任務只可出草稿、寫測試、code review，不得直接提交實作。沙箱題的 setup／check 腳本也由人類撰寫，AI 只可出草稿（文件：題目來源與審核）。

## 技術版本（不得更改）

- Java 21。
- Spring Boot 4.0.3。版本一律由 Boot 的 BOM 管理，不自行覆寫。2026-09-25 查自 `spring-boot-dependencies-4.0.3.pom`：Spring Framework 7.0.5、Spring Security 7.0.3、Jackson 3.0.4、Hibernate 7.2.4.Final、Flyway 11.14.1、MySQL Connector/J 9.6.0、Testcontainers 2.0.3。
- Angular 22（目前 22.2.x）；Node.js ≥ 22.22.3 或 ≥ 24.15.0（Angular 22.2 的 engines）。
- MySQL 8.4 LTS，系統與練習用同版；映像標籤 `mysql:8.4`（Q-G6）。
- 新增 BOM 以外的依賴前是否要先詢問：〔待決 Q-R5〕

## 後端

### Spring Boot 4

- starter 名稱以 start.spring.io 選 4.0.3 產生的為準，例如 `spring-boot-starter-webmvc`、`spring-boot-starter-flyway`、`spring-boot-starter-security-oauth2-client`。Flyway 另需 `org.flywaydb:flyway-mysql`。
- 設定檔用 `application.yaml`〔提案〕；秘密只從環境變數讀取。
- 注入 `java.time.Clock`，不直接呼叫 `Instant.now()` 或 `LocalDate.now()`，讓測試能固定時間、測切日。〔提案〕
- 套件結構依層分：`controller`、`service`、`repository`、`domain`（Q-G4）。資料存取技術：〔待決 Q-G3〕。

### Jackson 3

- import `tools.jackson.core.*`、`tools.jackson.databind.*`；註解仍是 `com.fasterxml.jackson.annotation.*`。
- 注入 Spring Boot 自動設定的 `JsonMapper`，不要自己 `new ObjectMapper()`。
- 不加入 Jackson 2 的 `com.fasterxml.jackson.core:jackson-databind`，除非 Q-G3 選 a1。
- 與 2.x 的差異（已用 3.0.4 實測）：`JacksonException` 是 unchecked；`JsonNode` 的 `fieldNames()`、`fields()` 已移除，改用 `propertyNames()`、`properties()`；文字節點使用 `asString()`、`isString()`；java.time 支援已內建於 databind，不需要 jsr310 模組。
- YAML 用 `tools.jackson.dataformat:jackson-dataformat-yaml` 的 `YAMLMapper`。

### Spring Security 7

- 只用 `SecurityFilterChain` Bean 與 lambda DSL。
- `/api/**` 未登入回 401 problem+json，不導向登入頁（02 §1.2）。
- 密碼用 `PasswordEncoderFactories.createDelegatingPasswordEncoder()` 雜湊。
- 使用者身分只取自認證資訊；存取他人資源回 404（02 §1.3）。

### 資料庫與 Flyway

- schema 只能透過 Flyway migration 變更。已套用的 migration 不得修改；檔名 `V{n}__{snake_case}.sql`（01 §2）。
- Hibernate（若使用）不得產生或修改 schema。
- 時間存 UTC（`DATETIME(6)` ↔ `Instant`）；只有統計切日使用 `ZoneId.of("Asia/Taipei")`（文件）。
- 「今天」的查詢先換算成 UTC 區間再查，才用得到索引（01 §4）。

### API

- 依 02 實作；錯誤一律回 problem+json 並帶 `code`（02 §2）。
- 作答以 `clientAttemptId` 去重，重送回傳原結果（02 §4.4）。

### 判題

- 依 03 實作；判題器無狀態、不寫資料庫。
- 新題型 = 新的 `Judge` Bean + JSON Schema + 測試；不得修改既有判題器、`JudgeRegistry` 或作答 API（文件：新增題型不需改動既有程式）。
- 題目 `payload` 含答案，任何對外回應都要先經過 `toPublicPayload`。

## Clean code

使用者要求維持 clean code 風格（2026-09-26）；以下細則是本草稿提出的〔提案〕。

- 命名說明意圖：類別用名詞、方法用動詞，不用縮寫與無意義名稱（`data`、`tmp`、`util`）。
- 一個方法只做一件事；超過約 20 行或巢狀超過 2 層就拆分。
- 一個類別只有一個變動理由；controller 不寫商業邏輯，只做轉換與呼叫 service。
- 優先用不可變物件：DTO 與值物件用 `record`，欄位 `final`，建構子注入，不用欄位注入。
- 不回傳 `null` 表示「沒有」，改用 `Optional` 或空集合；不用例外控制正常流程。
- 不寫魔法數字與字串，改為具名常數或設定值。
- 註解只寫「為什麼」，不寫「做什麼」；不留被註解掉的程式碼與 TODO（改開 issue）。
- 不重複：同樣邏輯出現第三次才抽出共用，避免過早抽象。
- 測試也是程式碼：一個測試驗一件事，名稱描述行為，採 given／when／then 結構。
- 前端元件保持小而專一；畫面邏輯放元件，資料存取放 service。

## 前端

- 用 Angular CLI 產生程式碼；standalone 元件、signals、內建控制流程（`@if`、`@for`）。
- 所有路由 lazy load；首頁只載入等餐模式需要的程式碼（文件）。
- 手機優先（文件）：以手機尺寸（例如 360×640）檢查版面；操作手感的範圍見 Q-F3。
- 只用相對路徑 `/api/...` 呼叫後端；開發時靠 dev server proxy，正式環境靠 Nginx。
- 作答送出時帶 `clientAttemptId`（`crypto.randomUUID()`），重送沿用同一個值。
- 題目內容不得用 `innerHTML` 直接輸出；若 Q-M8 決定用 Markdown，必須先 sanitize。
- 樣式用 Tailwind CSS，不引入 Angular Material（Q-F1）。介面只有繁體中文（Q-F2）。zoneless，狀態用 signals（Q-F6）。

## 測試

- 後端：JUnit 5；整合測試用 Testcontainers 實際啟動 MySQL（文件），映像標籤依 Q-G6，且與本機 `compose.yaml` 相同。Docker Hub 限流時可改用 `mirror.gcr.io/library/mysql:<標籤>`。
- 前端：CLI 預設的 Vitest；端對端測試用 Playwright。〔提案〕
- 每條驗收條件都要有對應的自動化測試；做不到的，在 PR 寫明手動驗證步驟與結果。
- 不得為了讓 CI 通過而停用、跳過或刪除測試。

## 安全（repo 公開）

- 不得 commit 任何秘密：密碼、token、OAuth client secret、`.env`。只提交 `.env.example`。
- log 中不得出現密碼、token、session id。
- 題目答案不得出現在任何對外 API 回應（例外見 Q-J6）。
- Docker daemon 與資料庫不對外開放（文件）。

## Git 與 PR

- `main` 受保護，只能經 PR 合併；人類審核並以 squash 合併（Q-R3）。
- 每個任務一個分支 `task/T<編號>-<簡述>`、一個 PR，PR 標題以 `[Txx]` 開頭（Q-R3）。
- commit 訊息用 Conventional Commits（例：`feat(judge): add choice judge`）（Q-R3）。
- commit 訊息中英雙語：第一行英文（Conventional Commits），內文中文說明（Q-R4）。程式碼註解與 PR 描述的語言：〔待決 Q-R4〕。
- PR 描述包含：任務編號、每條驗收條件的證據、用到的待決問題決定、偏離規格之處（應該沒有）。
- 不 force-push 共用分支；不用 `--no-verify` 跳過檢查。
- 格式化與靜態檢查工具：〔待決 Q-R6〕。

## 已查證的事實（2026-09-25）

- hibernate-core 7.2.4 內建的 JSON 映射只支援 Jackson 2；Spring ORM 7.0.5 與 spring-boot-hibernate 4.0.3 沒有 Jackson 3 版本（影響 Q-G3）。
- `com.networknt:json-schema-validator` 3.0.7 原生依賴 Jackson 3（影響 Q-I5）。
- Angular 22.2 的 `ng new` 預設：standalone、Vitest、strict、2025 檔名風格（沒有 `.component` 後綴）；zoneless 會詢問。
- `mysql:8.0`（8.0.46）與 `mysql:8.4`（8.4.11）的預設字元集都是 utf8mb4、定序 utf8mb4_0900_ai_ci。
- Flyway 11.14.1 對 MySQL 8.0 沒有警告；對 8.4 會警告未經驗證，但 migration 能正常執行（01 §2）。
- MySQL 8.0 已於 2026 年 4 月結束支援，之後沒有安全性修補（影響 Q-G6）。
