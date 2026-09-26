# 04 第一階段任務

第一階段拆成 35 個任務，每個預計半天內完成：31 個必要任務（T01～T31，其中 T15、T26、T30 視決定可能不做）與 4 個條件任務（T32～T35）。範圍依文件「開發順序」：骨架（帳號、題目模型、`Judge` 介面、作答紀錄、YAML 匯入）+ 選擇／填空題 + 手機版與等餐模式 → 部署。

## 怎麼用

1. 只挑「相依」都已完成、「阻擋」的待決問題都已有決定的任務（[06-open-questions.md](06-open-questions.md)）。目前不受任何待決問題阻擋的只有 T06。
2. 每個任務要滿足下方「共同完成條件」與自己的「驗收」。
3. 任務若預估超過半天，先回報並提出拆分方式，不要自行擴大或縮小範圍。
4. T06、T10、T12、T17 由你親手寫（Q-R1），AI 只出草稿、測試與 review。

## 共同完成條件

1. 後端建置與測試全部通過（指令依 Q-G1，例如 `./gradlew build` 或 `./mvnw verify`）。有前端變更時 `npm ci`、`npx ng build`、`npx ng test --watch=false` 全部通過。
2. 每條驗收都有自動化測試；無法自動化的，在 PR 描述寫明手動步驟與結果。
3. 沒有任何秘密進入版控（文件：Repo 公開）。設定一律用環境變數，只提交 `.env.example`。
4. 沒有偏離 01～03 的規格。發現規格缺漏或矛盾時停下來問，不自行假設（[05-agent-rules.draft.md](05-agent-rules.draft.md)）。
5. PR 描述列出任務編號、每條驗收的證據（指令與結果），以及用到的待決問題決定。

## 執行批次

依相依關係排出的最早可開始批次（還要加上待決問題的阻擋，見 06 的「決定順序」）：

| 批次 | 任務 |
| --- | --- |
| 1 | T01、T02 |
| 2 | T03、T04、T06 |
| 3 | T05、T07、T08 |
| 4 | T09、T12 |
| 5 | T10、T13、T14、T16、T20 |
| 6 | T11、T15、T17、T21、T22 |
| 7 | T18、T27、T32、T33、T35 |
| 8 | T19、T28、T34 |
| 9 | T23、T29、T30、T31 |
| 10 | T24 |
| 11 | T25、T26 |

## 需要人工的前置作業

| 項目 | 需要的任務 | 相關決定 |
| --- | --- | --- |
| Google OAuth 用戶端（本機授權來源與重新導向 URI） | T14 | Q-A9 |
| GCP 專案、帳單、VM、防火牆、SSH 方式 | T28 | Q-D1、Q-D4 |
| 網域與 DNS；OAuth 用戶端加入正式網域 | T28 | Q-D2 |
| GitHub Secrets 與映像倉庫權限 | T29 | Q-D3、Q-D5 |
| GCP 預算警示、Cloud Storage bucket | T30 | Q-D1 |
| 題庫 repo 與第一批題目 | T11、上線自用 | Q-I2、Q-I9 |

---

## A 基礎建設

### T01 後端專案骨架與本機 MySQL
- 相依：無
- 阻擋：Q-G1、Q-G2、Q-G4、Q-G6
- 範圍：
  - `backend/`：Spring Boot 4.0.3、Java 21（toolchain）。建置工具依 Q-G1，座標與根套件依 Q-G2，套件結構依 Q-G4。
  - 依賴名稱以 start.spring.io 產生的 4.0.3 專案為準：webmvc、validation、actuator、flyway 與 `org.flywaydb:flyway-mysql`、`com.mysql:mysql-connector-j`、test、Testcontainers（MySQL）。Security 在 T12 加入；資料存取依賴在 T05 依 Q-G3 加入。
  - repo 根目錄 `compose.yaml`：本機開發用 MySQL 8（映像標籤依 Q-G6），帳密從 `.env` 讀取；提交 `.env.example`。
  - `application.yaml` 與 profile `local`、`test`、`prod`；資料庫連線與所有秘密只從環境變數讀取。
  - Actuator 只開放 `health`。
  - 建立 `backend/src/main/resources/db/migration/`（先放 `.gitkeep`）。
  - `.gitignore` 補上 `.env`、IDE 設定、`node_modules/`、前端建置輸出（現有內容是 Gradle 範本）。
- 驗收：
  1. 乾淨 clone 後執行建置指令成功。
  2. `docker compose up -d` 後以 `local` profile 啟動，`curl -s localhost:8080/actuator/health` 回 `{"status":"UP"}`。
  3. 至少一個 `@SpringBootTest` 以 Testcontainers 啟動成功，映像標籤與 `compose.yaml` 相同（Q-G6）。
  4. `git ls-files` 沒有 `.env`；`.env.example` 只有範例值。
  5. `/actuator/env` 等其他 actuator 端點回 404。

### T02 前端專案骨架
- 相依：無
- 阻擋：Q-F1、Q-F6
- 範圍：
  - Node.js ≥ 22.22.3 或 ≥ 24.15.0（Angular 22.2 的 engines 要求），寫進 `frontend/.nvmrc` 與 `package.json` 的 `engines`。
  - 在 `frontend/` 以 Angular CLI 22.2 執行 `ng new`：standalone、routing、strict、測試框架用 CLI 預設（Vitest）、不啟用 SSR（文件：Nginx 提供 Angular 靜態檔）。樣式依 Q-F1，zoneless 依 Q-F6，檔名用 CLI 預設風格。
  - `proxy.conf.json`：`/api` 轉到 `http://localhost:8080`，並設定給 `ng serve` 使用。
- 驗收：
  1. `npm ci`、`npx ng build`、`npx ng test --watch=false` 全部成功。
  2. `ng build` 只產出靜態檔，沒有 SSR 伺服器程式。
  3. `angular.json` 的 serve 設定引用 proxy 檔（實際轉送在 T20 驗證）。

### T03 CI
- 相依：T01、T02
- 阻擋：Q-G1
- 範圍：`.github/workflows/ci.yml`，push 與 pull_request 觸發（所有 `task/*` 分支與 `main`，Q-R3）。後端 job：Temurin 21，建置與測試（含 Testcontainers）。前端 job：Node 24.15 以上，`npm ci`、build、test。快取依賴。
- 驗收：
  1. PR 上兩個 job 都通過。
  2. 任何測試失敗都會讓 job 失敗（不使用 `continue-on-error`）。
  3. workflow 內沒有明文秘密。

## B 資料庫

### T04 Flyway V1～V3 與 migration 測試
- 相依：T01
- 阻擋：Q-G6
- 說明：開工時若 Q-A2、Q-A4、Q-A7、Q-A8、Q-M7、Q-M9、Q-P7 已有決定，直接取消 01 §3 對應欄位的註解；未決定就先建立基礎版本，日後以新 migration 加欄位。
- 範圍：依 01 §3 建立 `V1__create_user_tables.sql`、`V2__create_question_bank_tables.sql`、`V3__create_attempt_table.sql`，內容與規格一致。
- 驗收：
  1. Testcontainers（Q-G6 決定的 MySQL 映像）整合測試：`flyway_schema_history` 有版本 1、2、3 且都成功。
  2. 同一測試查 `information_schema`，01 §4 列出的每個唯一鍵與索引、01 §3 的每個外鍵都存在。
  3. 再次啟動不會重跑 migration。
  4. PR 描述記錄 Spring Boot 啟動時是否出現 Flyway 的 MySQL 版本警告（01 §2：8.4 會出現，8.0 不會）。

### T05 資料存取層
- 相依：T04
- 阻擋：Q-G3
- 範圍：V1～V3 七張表的 entity／record 與 repository（或 mapper），技術依 Q-G3。JSON 欄位（`payload`、`answer`、`feedback`）在程式中是 `tools.jackson.databind.JsonNode`（選 JPA 時依 Q-G3 的 a1／a2／a3）。`DATETIME(6)` 對應 `Instant`，JDBC URL 設定 UTC（01 §2）。
- 驗收：
  1. 每張表至少一個新增與查詢的整合測試（Testcontainers）。
  2. 寫入 `Instant` `2026-01-01T00:00:00.123456Z` 再讀回完全相同；以原生 SQL 查到 `2026-01-01 00:00:00.123456`。
  3. JSON 欄位往返後內容不變（含巢狀陣列與中文）。
  4. 依賴樹中沒有 Jackson 2 的 `jackson-databind`，除非 Q-G3 選 a1。

## C 判題

### T06 Judge 核心與 registry
- 相依：T01
- 阻擋：無
- 範圍：03 §2.1、§2.2 的全部型別與 `JudgeRegistry`，放在 `judge` 套件。
- 驗收：
  1. 型別名稱、欄位與方法簽章和 03 §2.1 一致。
  2. 單元測試：註冊的 type 都查得到；兩個 Bean 宣告同一個 type 時 Spring context 啟動失敗，訊息含該 type；查未註冊的 type 丟 `UnknownJudgeTypeException`。
  3. 以一個只存在於測試程式的假判題器證明：新增題型不需要修改任何既有類別。
  4. `judge` 套件不 import web 或資料存取的類別。

### T07 choice 判題器
- 相依：T06
- 阻擋：Q-J2
- 範圍：依 03 §4 實作 choice，類別切分依 Q-J1。把 `docs/spec/schemas/` 複製到後端資源目錄並保持相對路徑（03 §3.2），依 Q-J2 調整 choice 的兩個 schema。
- 驗收：
  1. 表格式單元測試：答對、答錯、`selected` 參照不存在的選項（`InvalidAnswerException`，`ANSWER_UNKNOWN_OPTION`）、answer 不符合 schema；Q-J2 允許複選時加測集合比對。
  2. `validatePayload` 對 `OPTION_ID_DUPLICATE`、`ANSWER_UNKNOWN_OPTION`、schema 違規各有測試。
  3. `toPublicPayload` 的結果不含 `answer`，且不修改傳入的 payload。
  4. 範例 `mysql-innodb-clustered-index.yaml` 的標準答案判為 `CORRECT`。

### T08 fill 判題器
- 相依：T06
- 阻擋：Q-J3、Q-J4
- 範圍：依 03 §5 實作 fill；比對時的正規化依 Q-J3，多格判定與題幹標記依 Q-J4，並依決定調整 fill 的兩個 schema。
- 驗收：
  1. 表格式單元測試覆蓋 Q-J3 決定要做的每一條正規化規則，也驗證沒決定要做的規則確實沒做。
  2. `ANSWER_BLANKS_MISMATCH`、`BLANK_ID_DUPLICATE`、`ACCEPTED_DUPLICATE` 各有測試。
  3. `toPublicPayload` 的結果不含 `accepted`。
  4. 範例 `mysql-buffer-pool-size-variable.yaml` 的標準答案判為 `CORRECT`。

## D 匯入

### T09 題目檔解析與驗證
- 相依：T07、T08
- 阻擋：Q-M3、Q-M4、Q-M7、Q-M8、Q-M9、Q-I3、Q-I5、Q-I7、Q-I8
- 範圍：
  - 讀取一個目錄（或 zip）中的 `*.yaml`，以 Jackson 3 的 `YAMLMapper` 解析。
  - 依 03 §3.4 檢查不需資料庫的項目：YAML 語法、schema、未註冊的 judgeType、payload 語意、標準答案自我檢查、重複識別碼、重複 tag。科目與單元是否存在在 T10 檢查。
  - 產出錯誤清單：檔案路徑、JSON Pointer、code、訊息。本任務不寫資料庫。
  - 依決定更新 `question.schema.json`（Q-M3 範圍、Q-M4 值、Q-M7 language、Q-M9 explanation、Q-I3 key、Q-I7 審核欄位、Q-I8 格式）；JSON Schema 的驗證方式依 Q-I5。
- 驗收：
  1. `docs/spec/examples/questions/` 驗證結果為零錯誤。
  2. 上述每一種錯誤都有測試檔，且回報正確的檔案、pointer 與 code。
  3. 中文內容以 UTF-8 正確讀取。
  4. 一個檔案出錯不影響其他檔案的檢查，所有錯誤一次列出。

### T10 匯入寫入
- 相依：T05、T09
- 阻擋：Q-M1、Q-M2、Q-M10、Q-I3、Q-I4、Q-I6、Q-I10
- 範圍：把驗證通過的題目寫入資料庫。科目與單元依 Q-M2；題目以識別碼 upsert，依 03 §3.3 計算 `content_hash`，內容變動時 `revision` 加 1；tags 整批替換；從題庫消失的題目依 Q-I4；重複題依 Q-I6；部分錯誤依 Q-I10；回傳匯入報告（欄位同 02 §3.6）。
- 驗收：
  1. 空資料庫匯入範例 → `created` 等於檔案數。
  2. 原封不動再匯入 → 全部 `unchanged`，`revision` 與 `updated_at` 都不變。
  3. 修改一題的題幹 → `updated` = 1、該題 `revision` = 2；既有作答紀錄的 `question_revision` 仍為 1。
  4. 刪除一個檔案再匯入 → 行為符合 Q-I4，作答紀錄保留。
  5. 夾帶一個錯誤檔案 → 行為符合 Q-I10。
  6. 報告的數字與資料庫實際狀態一致。

### T11 匯入觸發
- 相依：T10、T12
- 阻擋：Q-A8、Q-I1、Q-I2、Q-I5、Q-I7
- 範圍：依 Q-I1。選 a 時實作 02 §4.6（`dryRun`、CI token、上傳大小上限），並在 `docs/` 提供題庫 repo 可用的 GitHub Actions 範例。另提供本機匯入範例題目的方式。
- 驗收（Q-I1 選 a）：
  1. `dryRun=true` 不寫入資料庫，回傳完整報告。
  2. 有錯誤時回 422 `IMPORT_INVALID`，`report` 列出錯誤。
  3. 缺少或錯誤的 token 回 401；token 以常數時間比對。
  4. 超過上傳上限回 413 `PAYLOAD_TOO_LARGE`。
  5. PR 附上以 `curl` 手動呼叫的步驟與結果。

## E 帳號與安全

### T12 Spring Security 基礎與 /api/me
- 相依：T05
- 阻擋：Q-A1、Q-A8
- 範圍：`SecurityFilterChain`（lambda DSL）；登入狀態依 Q-A1（含 01 §5.1 的條件式 migration）；CSRF 依 02 §1.2；401／403 以 problem+json 回應（02 §2），不導向登入頁；只開放 02 §4.1 標為公開的端點與 `/actuator/health`；`GET /api/me`；角色依 Q-A8。
- 驗收：
  1. 未登入 `GET /api/me` → 401，`Content-Type: application/problem+json`，`code: AUTH_REQUIRED`。
  2. 以測試使用者登入後 `GET /api/me` → 200 UserView。
  3. Q-A1 選 a／b 時：沒帶 CSRF token 的 POST → 403 `CSRF_INVALID`，帶了就通過。
  4. `/actuator/health` 不需登入；其他 actuator 端點 404。
  5. 以上以 spring-security-test 撰寫測試。

### T13 自建帳密註冊、登入、登出
- 相依：T12
- 阻擋：Q-A2、Q-A4、Q-A5、Q-A6
- 範圍：02 §4.2 的 register、login、logout（Q-A1 選 c 時含 refresh）。密碼以 `PasswordEncoderFactories.createDelegatingPasswordEncoder()` 雜湊；註冊限制依 Q-A2；密碼規則與限流依 Q-A6。Q-A5 選 b 或 c 時，忘記密碼與 email 驗證另拆任務。
- 驗收：
  1. 註冊成功回 201；相同 `loginId`（大小寫不同也算）→ 409 `LOGIN_ID_TAKEN`。
  2. 登入成功回 200；帳號不存在與密碼錯誤時，狀態碼與本文完全相同。
  3. `password_hash` 以 DelegatingPasswordEncoder 的 `{id}` 前綴開頭，不含明文。
  4. 登出後 `GET /api/me` → 401。
  5. Q-A2、Q-A6 決定的每條規則都有測試。

### T14 Google 登入
- 相依：T12
- 阻擋：Q-A7、Q-A9
- 需人工：在 Google Cloud Console 建立 OAuth 用戶端（網頁應用程式），加入本機的授權來源與重新導向 URI；client id 與 secret 放環境變數。正式網域在 T28 加入。
- 範圍：依 Q-A9 實作 02 §4.2 的 Google 登入；以 `sub` 找到或建立 `oauth_account`；相同 email 依 Q-A7。
- 驗收：
  1. 自動化測試（模擬 Google 回應或使用測試 JWK）：第一次登入建立 `app_user` 與 `oauth_account`（`provider = google`、`provider_subject = sub`）；同一個 `sub` 再登入得到同一個使用者。
  2. 相同 email 的情況符合 Q-A7。
  3. Q-A9 選 b 時：`aud` 錯誤、`iss` 錯誤、已過期的 ID token 都回 401。
  4. 手動：本機以真實 Google 帳號登入成功（PR 附步驟）。

### T15 訪客 demo 帳號（條件：Q-A3 決定要做）
- 相依：T13
- 阻擋：Q-A3
- 範圍與驗收：依 Q-A3 的決定補齊（登入方式、權限限制、資料重置）。

## F 作答後端

### T16 題目查詢 API
- 相依：T05、T07、T08、T12
- 阻擋：Q-M10、Q-J6
- 範圍：02 §4.3 的 `GET /api/subjects` 與 `GET /api/questions/{id}`；`payload` 一律經 `toPublicPayload`。
- 驗收：
  1. 回應欄位名稱與型別符合 02 §3.2、§3.3（JSON 斷言測試）。
  2. choice 與 fill 題的回應不含 `answer`、`accepted`（Q-J6 決定的例外除外）。
  3. 狀態不是 `ACTIVE` 的題目 → 404 `QUESTION_NOT_FOUND`。
  4. 未登入 → 401。

### T17 作答提交 API
- 相依：T16
- 阻擋：Q-M9、Q-P4、Q-P7
- 範圍：02 §4.4 處理順序的第 1、2、3、5、6 步（場次檢查的第 4 步在 T19）；`solution` 依 Q-P4；作答時間依 Q-P7；寫入 `attempt`。
- 驗收：
  1. 答對、答錯各回 201 與正確的 `verdict`；資料庫有對應列（`user_id`、`question_revision`、`answer`、`verdict`、`feedback`）。
  2. 相同 `clientAttemptId` 重送 → 200、本文與第一次相同、資料庫只有一列；兩個請求同時送達也一樣。
  3. `questionRevision` 過期 → 409 `QUESTION_REVISED`，不寫入。
  4. `answer` 不合法 → 400 `INVALID_ANSWER`，`errors[].pointer` 以 `/answer` 開頭，不寫入。
  5. 請求本文夾帶 `userId` 不影響寫入的使用者。
  6. `created_at` 以 UTC 儲存。

### T18 等餐模式選題與每日新題上限
- 相依：T17
- 阻擋：Q-M4、Q-P1、Q-P6
- 範圍：選題服務（輸入使用者與模式，輸出題目清單），規則依 Q-P1，裝置過濾依 Q-M4。Q-P6 決定第一階段就做每日新題上限時，含 01 §5.4 的 migration。「今天」以 Asia/Taipei 切日（文件）。
- 驗收：
  1. 以固定的 `Clock` 與亂數種子，測試 Q-P1 的每一條排序與過濾規則。
  2. 切日：`2026-09-25T15:59:59Z` 的作答算 9/25，`2026-09-25T16:00:00Z` 算 9/26。
  3. 可出的題目不足時，行為符合 Q-P1。
  4. 若做每日新題上限：當天新題數達上限後不再出新題。

### T19 等餐模式場次 API
- 相依：T18
- 阻擋：Q-P2、Q-P3
- 範圍：Q-P3 選 a 時：01 §5.2 的 migration、02 §4.5 的三個端點、作答 API 的場次檢查（02 §4.4 第 4 步）；題數與時間依 Q-P2。Q-P3 選 b 時：只做 `GET /api/practice/questions`。
- 驗收（Q-P3 選 a）：
  1. 開始場次回 201，題數符合 Q-P2，每題都是完整的 QuestionView。
  2. 帶 `practiceSessionId` 作答後，`GET /api/practice-sessions/active` 顯示該題的 `result`。
  3. 作答不在場次內的題目 → 409 `SESSION_ITEM_MISMATCH`；別人的場次 → 404。
  4. `finish` 後狀態為 `FINISHED`、摘要數字正確；再呼叫一次回相同摘要；`active` 回 204。
  5. 場次保留期限（Q-P3）以固定 `Clock` 測試。

## G 前端

### T20 前端外殼、路由、認證狀態
- 相依：T02、T12
- 阻擋：Q-A1、Q-F1、Q-F2
- 範圍：手機優先的版面；所有路由 lazy load，首頁 `/` 是等餐模式（文件：首頁只載入等餐模式所需程式碼）；認證狀態服務（signals）；HTTP 攔截器（依 Q-A1 帶 XSRF 或 Bearer）；未登入導向 `/login` 的 guard；依 problem 的 `code` 顯示錯誤訊息（語言依 Q-F2）。
- 驗收：
  1. 未登入進入 `/` 被導向 `/login`；登入後回到原頁（測試）。
  2. 攔截器單元測試：Q-A1 選 a／b 時寫入請求帶 `X-XSRF-TOKEN`；選 c 時帶 `Authorization`，收到 401 時嘗試 refresh 一次。
  3. `ng serve` 時 `/api/me` 經 proxy 轉到後端（PR 附手動步驟）。
  4. 錯誤 `code` 對應訊息的單元測試。
  5. 手機尺寸（例如 360×640）下沒有水平捲軸。

### T21 登入與註冊頁
- 相依：T13、T20（Google 按鈕另需 T14）
- 阻擋：Q-A4、Q-A9、Q-F1、Q-F2
- 範圍：`/login`、`/register` 兩個 lazy 頁面；欄位依 Q-A4；Google 登入入口依 Q-A9；錯誤訊息依 `code`。
- 驗收：
  1. 元件測試：送出的請求本文正確；`AUTH_INVALID_CREDENTIALS`、`LOGIN_ID_TAKEN`、`VALIDATION_FAILED` 顯示對應訊息。
  2. 建置結果中 `/login`、`/register` 是獨立 chunk，不在首頁 chunk 內。
  3. 手動：本機完成註冊 → 登入 → 登出；T14 已完成時再測 Google 登入。

### T22 choice／fill 題目元件
- 相依：T16、T20
- 阻擋：Q-M8、Q-M9、Q-J2、Q-J4、Q-P4、Q-F1、Q-F3
- 範圍：依 QuestionView 顯示 choice 與 fill；送出時以 `crypto.randomUUID()` 產生 `clientAttemptId`，answer 格式依 03 §4.3、§5.3；顯示 `verdict`、`feedback`、`solution`（依 Q-P4）與解析（Q-M9）；題幹格式依 Q-M8（Markdown 必須 sanitize）；操作手感依 Q-F3（主要按鈕在畫面下半部、答對答錯震動，iOS 限制見 Q-F5）。
- 驗收：
  1. 元件測試：依 public payload 正確呈現選項與空格；送出的 answer 形狀符合 03 §4.3、§5.3。
  2. 網路錯誤後重送沿用同一個 `clientAttemptId`。
  3. Q-M8 選 Markdown 時：題幹中的 `<script>` 與 `onerror` 屬性不會執行也不會輸出。
  4. Q-F3 納入操作手感時：手機尺寸下主要按鈕位於畫面下半部。

### T23 等餐模式主流程畫面
- 相依：T19、T22
- 阻擋：Q-M4、Q-P1、Q-P2、Q-P4、Q-F3
- 範圍：首頁一鍵開始（文件）；依場次逐題作答；題數或倒數依 Q-P2；送出目前裝置類型供選題（Q-M4）；左右滑換題（Q-F3）；結束摘要。
- 驗收：
  1. Playwright 端對端測試（對本機後端或模擬 API）：點「開始」→ 第一題出現 → 作答完畢 → 摘要顯示答對數。
  2. 題數或時間到達時的行為符合 Q-P2。
  3. Q-F3 納入時：左右滑可換題。

### T24 續做與斷線重送
- 相依：T23
- 阻擋：Q-P3
- 範圍：依 Q-P3 續做（選 a：開啟時呼叫 `GET /api/practice-sessions/active`；選 b：從瀏覽器儲存恢復）；送出失敗時保留待送狀態並自動重試，沿用同一個 `clientAttemptId`（文件：網路可能不穩）。
- 驗收：
  1. 作答到一半重新整理 → 回到第一個未作答的題目（端對端測試）。
  2. 模擬送出失敗再恢復連線 → 自動重送成功，資料庫只有一筆作答。
  3. 場次過期後的行為符合 Q-P3。

### T25 首屏效能與量測
- 相依：T24、T27
- 阻擋：Q-F3、Q-F4
- 範圍：依 Q-F4 的條件建立可重複執行的量測腳本（例如 Playwright 或 Lighthouse CI，含網路節流）；設定 `angular.json` budgets；檢查首頁 chunk 只含等餐模式所需程式碼；檢查 Nginx 的壓縮與快取標頭（T27）。
- 驗收：
  1. 量測腳本與說明已提交；在 T27 的 Compose 環境量得的結果低於 Q-F4 的門檻。
  2. 超出 budget 時 `ng build` 失敗。
  3. 首頁 chunk 不含 `/login`、`/register` 等其他路由的程式碼（以 build stats 驗證）。

### T26 PWA 與離線（條件：Q-F3 納入）
- 相依：T24
- 阻擋：Q-J6、Q-F3
- 說明：範圍明顯超過半天，決定納入後再拆成 2～3 個任務：service worker 與快取、離線作答佇列、同步與衝突處理。

## H 部署

### T27 容器化與正式環境 Compose
- 相依：T17、T21
- 阻擋：Q-A9、Q-D1、Q-D5
- 範圍：
  - 後端 Dockerfile（Java 21 執行環境）；JVM 參數依 Q-D1，e2-micro 時為 `-Xmx256m`（文件）。
  - 前端在 CI 建置（文件：Angular 在 GitHub Actions 建置，不在 VM 上 build），靜態檔放進 Nginx 映像。
  - `deploy/compose.prod.yaml`：nginx、backend、mysql。MySQL 設定依 Q-D1 調小 buffer pool（文件）；資料用 named volume；各服務有健康檢查。
  - `deploy/nginx/`：SPA fallback、`/api/` 轉送後端（Q-A9 選 a 時回呼路徑也在 `/api` 底下，02 §4.2）、gzip、帶雜湊的靜態檔長期快取、`index.html` 不快取。
  - 秘密的提供方式依 Q-D5。
- 驗收：
  1. 本機 `docker compose -f deploy/compose.prod.yaml up` 後：`curl localhost/` 回 index.html；`curl localhost/api/me` 回 401 problem+json；任意深層路徑回 index.html；`curl localhost/actuator/health` 回 404。
  2. 重啟 Compose 後資料仍在。
  3. `docker inspect` 可見 JVM 參數與記憶體限制符合 Q-D1。
  4. 映像的 `docker history` 與內建環境變數中沒有秘密。

### T28 VM 佈建與 HTTPS（需人工）
- 相依：T27
- 阻擋：Q-D1、Q-D2、Q-D4、Q-D5
- 需人工：GCP 專案與帳單；VM（機型依 Q-D1）；防火牆只開 80、443（文件）；SSH 依 Q-D4；DNS 記錄（Q-D2）；Google OAuth 用戶端加入正式網域。
- 範圍：`deploy/README.md` 逐步操作手冊；`deploy/scripts/` 的 VM 初始化腳本（安裝 Docker；e2-micro 時加 2 GB swap，文件）；Certbot 申請與自動續期（文件）。
- 驗收：
  1. 依手冊在全新 VM 上操作後，`https://<網域>` 可開啟且憑證有效。
  2. `certbot renew --dry-run` 成功。
  3. 從外部掃描只有 80、443 開放，Docker daemon 不對外（文件）。
  4. e2-micro 時 `swapon --show` 顯示 2 GB swap。

### T29 自動部署
- 相依：T03、T28
- 阻擋：Q-D3、Q-D4、Q-D5、Q-R3
- 範圍：`.github/workflows/deploy.yml`：`main` 有新 commit 時（Q-R3），建置後端與前端映像、推到映像倉庫（Q-D3）、部署到 VM（Q-D3、Q-D4）、執行冒煙測試；秘密放 GitHub Secrets（文件：GitHub Actions 自動部署）。Flyway 在應用程式啟動時執行 migration。
- 驗收：
  1. `main` 有新 commit 後 workflow 成功，VM 上執行的映像標籤等於該 commit SHA。
  2. 冒煙測試（`/` 回 200、`/api/me` 回 401）失敗時 workflow 失敗。
  3. workflow log 中沒有秘密。

### T30 備份與預算警示（條件：Q-D1 決定第一階段要做）
- 相依：T28
- 阻擋：Q-D1
- 範圍：系統 MySQL 每日備份到 Cloud Storage（文件），保留期限在決定時一併定；還原手冊；GCP 預算警示（文件，需人工在主控台設定）。
- 驗收：
  1. 連續兩天在 bucket 看到備份檔。
  2. 依還原手冊把備份還原到暫時的資料庫並能查詢。

### T31 README
- 相依：T28
- 阻擋：Q-A3、Q-D2、Q-G5
- 範圍：README 放架構圖、demo 網址與訪客帳號（文件）；本機開發快速開始；連到 `docs/spec/`；LICENSE 依 Q-G5。
- 驗收：
  1. 依 README 在乾淨環境從 clone 到本機跑起來（PR 附操作紀錄）。
  2. README 中的網址可開啟；Q-A3 決定提供時，訪客帳號可登入。

## I 條件任務

只有對應問題決定「第一階段要做」時才執行；範圍在決定後補齊驗收條件，超過半天就拆分。

### T32 每日統計與紀錄頁（條件：Q-S2）
- 相依：T17
- 阻擋：Q-P7、Q-S1、Q-S2、Q-S3
- 範圍：01 §5.3 的 migration、更新方式（Q-S1）、02 §5 的統計端點、圖表頁（Q-S3）。

### T33 題目錯誤回報（條件：Q-P8）
- 相依：T16、T22
- 阻擋：Q-P8
- 範圍：01 §5.5 的 migration、02 §5 的回報端點、題目元件上的回報按鈕。

### T34 每日新題上限設定（條件：Q-P6）
- 相依：T18、T20
- 阻擋：Q-P6
- 範圍：02 §5 的兩個設定端點與設定頁。

### T35 依科目瀏覽作答（條件：Q-P5）
- 相依：T16、T22
- 阻擋：Q-P5
- 範圍：02 §5 的瀏覽端點與頁面。
