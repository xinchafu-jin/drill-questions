# 02 REST API 規格

第一階段的端點全部在 `/api` 底下（文件：Nginx 提供 Angular 靜態檔，`/api` 轉給 Spring Boot）。登入狀態用 cookie 還是 token 取決於 Q-A1，受影響處兩種寫法並列；標「條件」的端點只有在對應問題決定後才實作。

## 1. 通用慣例

### 1.1 基本

- 路徑前綴 `/api`（文件）。Spring Boot 另有 `/actuator/health`，只在容器網路內給 Docker Compose 健康檢查使用，Nginx 不轉送。
- 請求與回應都是 JSON（UTF-8），欄位用 camelCase。
- 時間用 ISO-8601 UTC 並帶 `Z`，例如 `2026-09-25T04:12:33.123456Z`；統計日期用 `YYYY-MM-DD`（Asia/Taipei）。
- 題目、作答、場次以數字 `id` 識別；科目、單元以 `code` 識別。
- 不設定 CORS：正式環境前後端同網域（Nginx），開發時用 Angular dev server 的 proxy。
- 第一階段沒有列表端點。條件式端點若需要分頁，用 `page`（0 起算）與 `size`，回應 `{ "items": [], "page": 0, "size": 20, "totalElements": 0 }`。

以上除路徑前綴外都是規格慣例，可否決。

### 1.2 認證（依 Q-A1）

| | Q-A1 選 a 或 b：session cookie | Q-A1 選 c：JWT |
| --- | --- | --- |
| 登入成功 | `Set-Cookie` session（HttpOnly、Secure、SameSite=Lax） | 回應本文帶 `accessToken`；refresh token 放 HttpOnly cookie |
| 之後的請求 | 瀏覽器自動帶 cookie | `Authorization: Bearer <accessToken>` |
| CSRF | 需要：cookie `XSRF-TOKEN` + header `X-XSRF-TOKEN`，與 Angular HttpClient 的預設名稱相同；依 Spring Security 7 參考文件的 SPA 設定 | API 本身不需要；refresh 端點靠 cookie 的 SameSite 與路徑限制保護 |
| 未登入 | 401 problem+json，不導向登入頁 | 同左 |

### 1.3 授權

- 除 §4.1 標「公開」的端點外全部需要登入。這是安全預設；未登入可否瀏覽題目見 Q-A3。
- 使用者身分只取自認證資訊，忽略請求中任何 userId。
- 存取不屬於自己的資源（場次、作答）一律回 404，不透露資源是否存在。
- 學習紀錄僅本人可見（文件：紀錄僅本人可見）。
- 匯入端點的權限見 Q-A8、Q-I1。

## 2. 錯誤格式

錯誤回應用 RFC 9457 `application/problem+json`（Spring `ProblemDetail`），另加兩個欄位：

- `code`：機器可讀的錯誤碼，前端依此顯示訊息（介面語言見 Q-F2）。
- `errors`：欄位錯誤清單，只出現在驗證錯誤。`pointer` 是 RFC 6901 JSON Pointer，相對於請求本文。

```json
{
  "type": "about:blank",
  "title": "Bad Request",
  "status": 400,
  "detail": "answer 不符合題型格式",
  "instance": "/api/questions/101/attempts",
  "code": "INVALID_ANSWER",
  "errors": [
    { "pointer": "/answer/selected/0", "code": "ANSWER_UNKNOWN_OPTION", "message": "選項 z 不存在" }
  ]
}
```

500 錯誤不回傳堆疊或例外訊息。

| code | HTTP | 意義 |
| --- | --- | --- |
| `VALIDATION_FAILED` | 400 | 請求格式或欄位驗證失敗 |
| `INVALID_ANSWER` | 400 | `answer` 不符合該題型格式（03-judge.md §2.4） |
| `AUTH_REQUIRED` | 401 | 未登入或登入已失效 |
| `AUTH_INVALID_CREDENTIALS` | 401 | 帳號或密碼錯誤；帳號不存在時回應完全相同 |
| `CSRF_INVALID` | 403 | 缺少或錯誤的 CSRF token（Q-A1 選 a／b） |
| `FORBIDDEN` | 403 | 已登入但權限不足 |
| `REGISTRATION_CLOSED` | 403 | 未開放註冊或不在白名單（Q-A2） |
| `NOT_FOUND` | 404 | 資源不存在或不屬於目前使用者 |
| `QUESTION_NOT_FOUND` | 404 | 題目不存在或目前不可作答（Q-M10） |
| `LOGIN_ID_TAKEN` | 409 | 登入識別已被註冊 |
| `QUESTION_REVISED` | 409 | 題目已改版，請重新載入 |
| `SESSION_NOT_ACTIVE` | 409 | 場次已結束或過期（Q-P3） |
| `SESSION_ITEM_MISMATCH` | 409 | 題目不屬於這個場次 |
| `PAYLOAD_TOO_LARGE` | 413 | 上傳內容超過上限（匯入，Q-I1） |
| `IMPORT_INVALID` | 422 | 匯入內容驗證失敗，附匯入報告 |
| `TOO_MANY_REQUESTS` | 429 | 超過頻率限制（Q-A6） |
| `INTERNAL_ERROR` | 500 | 未預期的錯誤 |

## 3. 資料結構

### 3.1 UserView

```json
{
  "id": 1,
  "loginMethods": ["LOCAL", "GOOGLE"]
}
```

| 欄位 | 型別 | 說明 |
| --- | --- | --- |
| `id` | number | `app_user.id` |
| `loginMethods` | string[] | 此帳號可用的登入方式：`LOCAL`、`GOOGLE` |

待決定後加入：`displayName`（Q-A4）、`email`（Q-A7）、`role`（Q-A8）。

### 3.2 SubjectView

```json
{
  "code": "mysql",
  "name": "MySQL",
  "units": [
    { "code": "index", "name": "索引" },
    { "code": "tuning", "name": "效能調校" }
  ]
}
```

科目與單元都依 `sort_order` 排序。

### 3.3 QuestionView

```json
{
  "id": 101,
  "revision": 1,
  "subject": { "code": "mysql", "name": "MySQL" },
  "unit": { "code": "index", "name": "索引" },
  "judgeType": "choice",
  "difficulty": 2,
  "device": "mobile",
  "version": "MySQL 8.0",
  "tags": ["index", "innodb"],
  "stem": "InnoDB 的聚簇索引（clustered index）使用哪一種資料結構？",
  "payload": {
    "options": [
      { "id": "a", "text": "Hash" },
      { "id": "b", "text": "B+Tree" },
      { "id": "c", "text": "R-Tree" },
      { "id": "d", "text": "跳躍串列（Skip List）" }
    ]
  },
  "source": "https://example.com/original",
  "license": "MIT"
}
```

| 欄位 | 說明 |
| --- | --- |
| `revision` | 作答時原樣送回，用來偵測題目在作答期間改版 |
| `version` | 沒有時為 `null` |
| `tags` | 依字母排序 |
| `payload` | 一律是 `Judge.toPublicPayload` 的結果，不含答案（03-judge.md §4.2、§5.2；例外見 Q-J6） |
| `source`、`license` | CC BY 等授權要求標示出處；前端是否顯示見 Q-I8 |

待決定後加入：`language`（Q-M7）。`question_key` 不對外公開。

### 3.4 AttemptResult

```json
{
  "attemptId": 5001,
  "questionId": 101,
  "questionRevision": 1,
  "verdict": "CORRECT",
  "feedback": {},
  "solution": { "answer": ["b"] },
  "createdAt": "2026-09-25T04:12:33.123456Z"
}
```

| 欄位 | 說明 |
| --- | --- |
| `verdict` | `CORRECT` 或 `WRONG` |
| `feedback` | 題型專屬回饋，不含正解（03-judge.md） |
| `solution` | 正解。何時回傳（每題、整場結束後、答錯才給、不給）見 Q-P4；不回傳時為 `null` |

待決定後加入：`explanation`（Q-M9）。

### 3.5 PracticeSessionView（Q-P3 選 a）

```json
{
  "id": 42,
  "mode": "MEAL",
  "status": "IN_PROGRESS",
  "startedAt": "2026-09-25T04:10:00Z",
  "items": [
    {
      "seq": 1,
      "question": {
        "id": 101,
        "revision": 1,
        "subject": { "code": "mysql", "name": "MySQL" },
        "unit": { "code": "index", "name": "索引" },
        "judgeType": "choice",
        "difficulty": 2,
        "device": "mobile",
        "version": "MySQL 8.0",
        "tags": ["index", "innodb"],
        "stem": "InnoDB 的聚簇索引（clustered index）使用哪一種資料結構？",
        "payload": {
          "options": [
            { "id": "a", "text": "Hash" },
            { "id": "b", "text": "B+Tree" },
            { "id": "c", "text": "R-Tree" },
            { "id": "d", "text": "跳躍串列（Skip List）" }
          ]
        },
        "source": "https://example.com/original",
        "license": "MIT"
      },
      "result": { "attemptId": 5001, "verdict": "CORRECT" }
    },
    {
      "seq": 2,
      "question": {
        "id": 102,
        "revision": 1,
        "subject": { "code": "mysql", "name": "MySQL" },
        "unit": { "code": "tuning", "name": "效能調校" },
        "judgeType": "fill",
        "difficulty": 1,
        "device": "mobile",
        "version": null,
        "tags": ["configuration", "innodb"],
        "stem": "設定 InnoDB 緩衝池大小的系統變數名稱是什麼？",
        "payload": { "blanks": [ { "id": "1" } ] },
        "source": "https://example.com/original",
        "license": "MIT"
      },
      "result": null
    }
  ]
}
```

| 欄位 | 說明 |
| --- | --- |
| `mode` | `MEAL`（等餐模式） |
| `status` | `IN_PROGRESS`、`FINISHED`；是否有 `EXPIRED` 見 Q-P3 |
| `items[].question` | 完整的 QuestionView。一次回傳整場題目，換題不需要再連線（文件：打開到第一題 2～3 秒內、網路可能不穩） |
| `items[].result` | 尚未作答為 `null` |

待決定後加入：題數或時間限制（Q-P2）。

### 3.6 ImportReport（Q-I1 選 a）

```json
{
  "dryRun": true,
  "applied": false,
  "summary": { "created": 2, "updated": 1, "unchanged": 40, "retired": 0 },
  "errors": [
    {
      "file": "mysql/index/innodb-clustered-index.yaml",
      "pointer": "/payload/answer/0",
      "code": "ANSWER_UNKNOWN_OPTION",
      "message": "answer 參照不存在的選項 z"
    }
  ],
  "warnings": []
}
```

- `applied`：資料庫是否已變更。
- `retired` 的意義依 Q-I4；有錯誤時是否仍匯入正確的檔案依 Q-I10。
- 錯誤碼見 03-judge.md §3.4、§4.4、§5.4。

## 4. 第一階段端點

### 4.1 總表

| # | 方法 | 路徑 | 用途 | 認證 | 條件 |
| --- | --- | --- | --- | --- | --- |
| 1 | GET | `/api/auth/csrf` | 取得 CSRF cookie | 公開 | Q-A1 選 a／b |
| 2 | POST | `/api/auth/register` | 自建帳號註冊 | 公開 | 規則依 Q-A2、Q-A4～Q-A6 |
| 3 | POST | `/api/auth/login` | 帳密登入 | 公開 | |
| 4 | POST | `/api/auth/logout` | 登出 | 登入 | |
| 5 | POST | `/api/auth/refresh` | 換發 access token | refresh cookie | Q-A1 選 c |
| 6 | GET | `/api/auth/oauth2/authorization/google` | 導向 Google 登入 | 公開 | Q-A9 選 a |
| 7 | GET | `/api/auth/oauth2/callback/google` | Google 回呼 | 公開 | Q-A9 選 a |
| 8 | POST | `/api/auth/google` | 以 Google ID token 登入 | 公開 | Q-A9 選 b |
| 9 | GET | `/api/me` | 目前使用者 | 登入 | |
| 10 | GET | `/api/subjects` | 科目與單元 | 登入 | |
| 11 | GET | `/api/questions/{id}` | 單一題目 | 登入 | |
| 12 | POST | `/api/questions/{id}/attempts` | 提交作答 | 登入 | |
| 13 | POST | `/api/practice-sessions` | 開始等餐模式 | 登入 | Q-P3 選 a |
| 14 | GET | `/api/practice-sessions/active` | 取得進行中的場次（續做） | 登入 | Q-P3 選 a |
| 15 | POST | `/api/practice-sessions/{id}/finish` | 結束場次 | 登入 | Q-P3 選 a |
| 16 | GET | `/api/practice/questions` | 取得一組等餐模式題目 | 登入 | Q-P3 選 b |
| 17 | POST | `/api/admin/imports` | 匯入題目 | CI token 或管理員 | Q-I1 選 a |

### 4.2 帳號

#### GET /api/auth/csrf（Q-A1 選 a／b）

回應 204，並設定 `XSRF-TOKEN` cookie（不可設 HttpOnly，Angular 要讀取）。前端在第一個寫入請求（登入、註冊）之前呼叫一次。

#### POST /api/auth/register

```json
{ "loginId": "user@example.com", "password": "correct horse battery staple" }
```

| 欄位 | 規則 |
| --- | --- |
| `loginId` | 必填，最長 254 字元；是 email 還是使用者名稱見 Q-A4 |
| `password` | 必填；長度與其他規則見 Q-A6 |

是否加 `displayName` 見 Q-A4。

| 狀態 | 本文 | 情況 |
| --- | --- | --- |
| 201 | UserView | 註冊成功；是否同時登入見 Q-A4 |
| 400 | problem，`VALIDATION_FAILED` | 欄位不合法 |
| 403 | problem，`REGISTRATION_CLOSED` | Q-A2 選白名單或邀請碼且不符合 |
| 409 | problem，`LOGIN_ID_TAKEN` | 登入識別已存在（依定序不分大小寫） |

密碼以 `PasswordEncoderFactories.createDelegatingPasswordEncoder()` 雜湊後存入 `local_credential.password_hash`。

#### POST /api/auth/login

```json
{ "loginId": "user@example.com", "password": "correct horse battery staple" }
```

| 狀態 | 本文 | 情況 |
| --- | --- | --- |
| 200 | Q-A1 選 a／b：UserView，並設定 session cookie | 成功 |
| 200 | Q-A1 選 c：`{ "accessToken": "…", "expiresIn": 900, "user": { UserView } }`，並設定 refresh cookie；`expiresIn` 的值依 Q-A1 | 成功 |
| 401 | problem，`AUTH_INVALID_CREDENTIALS` | 帳號不存在或密碼錯誤，兩者回應相同 |
| 429 | problem，`TOO_MANY_REQUESTS` | 依 Q-A6 |

登入成功後必須更換 session id（Spring Security 預設行為，防 session fixation）。

#### POST /api/auth/logout

回應 204。Q-A1 選 a／b 時使 session 失效；選 c 時撤銷 refresh token 並清除 cookie。

#### POST /api/auth/refresh（Q-A1 選 c）

以 refresh cookie 換發新的 access token，同時輪替 refresh token。成功回 200 `{ "accessToken": "…", "expiresIn": 900 }`；cookie 無效、過期或已撤銷回 401 `AUTH_REQUIRED`。

#### Google 登入（Q-A9）

- 選 a：前端把瀏覽器導向 `GET /api/auth/oauth2/authorization/google`（302 到 Google）。Google 回呼 `GET /api/auth/oauth2/callback/google`，成功 302 到 `/`，失敗 302 到 `/login?error=google`。Spring Security 預設的端點不在 `/api` 底下，需設定 `authorizationEndpoint.baseUri` 與 `redirectionEndpoint.baseUri`，並把註冊的 redirect URI 設為 `{baseUrl}/api/auth/oauth2/callback/{registrationId}`，Nginx 就不必另外轉送路徑。
- 選 b：`POST /api/auth/google`，本文 `{ "idToken": "…" }`。後端驗證簽章、`aud`（本系統的 client id）、`iss`、到期時間，成功回應同 `/api/auth/login`，失敗回 401 `AUTH_INVALID_CREDENTIALS`。

兩者共同規則：以 ID token 的 `sub` 找 `oauth_account`；第一次登入時建立 `app_user` 與 `oauth_account`。已有相同 email 的自建帳號時怎麼處理見 Q-A7；白名單檢查見 Q-A2。

#### GET /api/me

回 200 UserView；未登入回 401 `AUTH_REQUIRED`。

### 4.3 題目

#### GET /api/subjects

回 200，本文為 SubjectView 陣列。

#### GET /api/questions/{id}

回 200 QuestionView。題目不存在或狀態不是 `ACTIVE`（Q-M10）時回 404 `QUESTION_NOT_FOUND`。

### 4.4 作答

#### POST /api/questions/{id}/attempts

```json
{
  "clientAttemptId": "0f8c6a0e-6c1e-4d3b-9a57-1c1f0d1f2a33",
  "questionRevision": 1,
  "answer": { "selected": ["b"] },
  "practiceSessionId": 42
}
```

| 欄位 | 必填 | 說明 |
| --- | --- | --- |
| `clientAttemptId` | 是 | 前端以 `crypto.randomUUID()` 產生；同一次作答重送時沿用同一個值 |
| `questionRevision` | 是 | 取得題目時的 `QuestionView.revision` |
| `answer` | 是 | 03-judge.md 各題型的 answer 格式 |
| `practiceSessionId` | 否 | Q-P3 選 a 時，場次中的作答要帶 |

待決定後加入：作答時間 `durationMs`（Q-P7）。

處理順序：

1. 同一使用者已有相同 `clientAttemptId` 的作答 → 直接回 200 與原本的結果，不重新判題，也不檢查其他欄位。
2. 題目不存在或不可作答 → 404 `QUESTION_NOT_FOUND`。
3. `questionRevision` 不是目前版本 → 409 `QUESTION_REVISED`，不寫入。離線同步的情況見 Q-J6。
4. 帶了 `practiceSessionId`：場次不屬於自己 → 404 `NOT_FOUND`；場次已結束 → 409 `SESSION_NOT_ACTIVE`；題目不在場次內 → 409 `SESSION_ITEM_MISMATCH`。同一題可否重答見 Q-P4。
5. 判題；`answer` 不合法 → 400 `INVALID_ANSWER`，不寫入。
6. 寫入 `attempt`（有場次時一併填入 `practice_session_item.attempt_id`），回 201 AttemptResult。

| 狀態 | 本文 |
| --- | --- |
| 201 | AttemptResult（新的作答） |
| 200 | AttemptResult（重送，內容與第一次相同） |
| 400 | problem，`INVALID_ANSWER` 或 `VALIDATION_FAILED` |
| 404 | problem，`QUESTION_NOT_FOUND` 或 `NOT_FOUND` |
| 409 | problem，`QUESTION_REVISED`、`SESSION_NOT_ACTIVE` 或 `SESSION_ITEM_MISMATCH` |

### 4.5 等餐模式

文件：一鍵開始，5 題或 3 分鐘，隨時離開可續做。選題規則見 Q-P1，題數與時間見 Q-P2，續做範圍見 Q-P3。

#### Q-P3 選 a：伺服器端場次

`POST /api/practice-sessions`

```json
{ "mode": "MEAL" }
```

可能加入的參數（科目範圍、題數或時間模式）見 Q-P1、Q-P2。

| 狀態 | 本文 | 情況 |
| --- | --- | --- |
| 201 | PracticeSessionView | 建立新場次，題目清單在建立時固定 |
| 200 | PracticeSessionView | 已有進行中的場次，且 Q-P3 決定續做舊場次 |

可出的題目不足預定題數時怎麼處理見 Q-P1。

`GET /api/practice-sessions/active`：回 200 PracticeSessionView；沒有進行中的場次時回 204。

`POST /api/practice-sessions/{id}/finish`：

```json
{
  "id": 42,
  "status": "FINISHED",
  "startedAt": "2026-09-25T04:10:00Z",
  "finishedAt": "2026-09-25T04:13:05Z",
  "answeredCount": 5,
  "correctCount": 4
}
```

回 200 與上面的摘要。場次已結束時再次呼叫，回 200 與同一份摘要（重送安全）。場次不屬於自己回 404 `NOT_FOUND`。

#### Q-P3 選 b：瀏覽器端進度

`GET /api/practice/questions?mode=MEAL` 回 200 `{ "questions": [ QuestionView, … ] }`。進度存在瀏覽器；作答時不帶 `practiceSessionId`。

### 4.6 匯入（Q-I1 選 a）

`POST /api/admin/imports?dryRun=true`

- 認證：`Authorization: Bearer <CI token>`（token 來自環境變數，以常數時間比對），或管理員登入（Q-A8）。
- `Content-Type: multipart/form-data`，欄位 `bundle` 是 zip 檔，內含 YAML 題目檔並保留目錄結構（Q-I2）。
- 上傳大小上限見 Q-I1。
- `dryRun=true` 只驗證不寫入，供題庫 repo 的 PR 檢查使用（Q-I5）。

| 狀態 | 本文 | 情況 |
| --- | --- | --- |
| 200 | ImportReport | 沒有錯誤；`dryRun=false` 時已寫入 |
| 401 | problem，`AUTH_REQUIRED` | 缺少或錯誤的 token |
| 422 | problem，`IMPORT_INVALID`，擴充欄位 `report` 為 ImportReport | 有驗證錯誤；是否仍匯入正確的檔案依 Q-I10 |

## 5. 條件式端點

決定納入第一階段才實作，細節在決定後補齊。

| 條件 | 方法 | 路徑 | 用途 |
| --- | --- | --- | --- |
| Q-S2 | GET | `/api/me/stats/daily?from=YYYY-MM-DD&to=YYYY-MM-DD` | 每日分科統計（Asia/Taipei 日期） |
| Q-S2 | GET | `/api/me/stats/summary` | 今日作答量、連續天數 |
| Q-S2 | GET | `/api/me/attempts?page=0&size=20` | 作答歷史 |
| Q-P6 | GET | `/api/me/subject-settings` | 各科每日新題上限 |
| Q-P6 | PUT | `/api/me/subject-settings/{subjectCode}` | 修改上限，本文 `{ "dailyNewLimit": 10 }` |
| Q-P8 | POST | `/api/questions/{id}/reports` | 回報題目錯誤，欄位見 Q-P8 |
| Q-P5 | GET | `/api/subjects/{subjectCode}/units/{unitCode}/questions?page=0&size=20` | 依單元瀏覽題目 |

## 6. 第二～七階段端點草案

| 階段 | 端點 | 說明 | 待決 |
| --- | --- | --- | --- |
| 2 正則 | 沿用 `POST /api/questions/{id}/attempts` | 即時預覽在前端 Web Worker，不呼叫後端（文件） | Q-L3 |
| 3 SQL | 沿用作答端點；可能新增 `GET /api/sql-datasets/{name}/schema` | 顯示練習資料表結構 | Q-L4 |
| 4 間隔重複 | `GET /api/me/reviews/due`；自評沿用作答端點 | 今天到期的複習題 | Q-L1、Q-L5、Q-L6 |
| 5 打字 | 成績沿用作答端點；`GET /api/leaderboards/typing?device=mobile` | 排行榜依裝置分開（文件） | Q-L7、Q-L11 |
| 6 沙箱 | `POST /api/sandbox/sessions`（回傳短效 JWT 與 `wss://sandbox.<網域>` 位址）、`POST /api/sandbox/sessions/{id}/reset`、`DELETE /api/sandbox/sessions/{id}`、`GET /api/status`（公開） | 終端機直連沙箱 WebSocket（文件）；一鍵重置、系統狀態頁（小巧思） | Q-J7、Q-L8、Q-L10 |
| 7 AI 批改 | 沿用作答端點；非同步時另需查詢結果的端點或 SSE | 只作回饋不列成績（文件） | Q-J7、Q-L9 |
| 未排入 | `POST /api/me/push-subscriptions` | 用餐時間推播（小巧思） | Q-L11 |
