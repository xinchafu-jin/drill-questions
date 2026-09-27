# 刷題系統實作規格

這份規格把「刷題系統規劃」（Claude Docs，rev 19，[連結](https://claude.ai/artifact/79m4rQHMo1B62PU4uzdhzv)）轉成可交給 AI 代理實作的格式。規劃文件沒寫的地方一律列為待決問題（82 題），規格沒有替你做決定。

技術限制：Java 21、Spring Boot 4.0.3（Jackson 3、Spring Security 7）、Angular 22、MySQL 8。MySQL 原為 9.7 LTS，2026-09-25 更正為 8；規劃文件 rev 19 尚未同步修改，小版本見 Q-G6。

## 檔案

| 檔案 | 內容 |
| --- | --- |
| [01-database.md](01-database.md) | 資料表、欄位、型別、索引與 Flyway migration（第一階段 V1～V3 完整 DDL） |
| [02-api.md](02-api.md) | REST API：路徑、請求、回應、錯誤格式 |
| [03-judge.md](03-judge.md) | `Judge` 介面、題目 YAML 格式、各題型 payload／answer／回饋的 JSON 格式 |
| [04-phase1-tasks.md](04-phase1-tasks.md) | 第一階段 35 個半天任務與驗收條件 |
| [05-agent-rules.draft.md](05-agent-rules.draft.md) | 給 AI 代理的規範檔草稿 |
| [06-open-questions.md](06-open-questions.md) | 待決問題（含選項、阻擋的任務、決定欄） |
| [schemas/](schemas/) | 題目檔與 choice／fill 的 JSON Schema（draft 2020-12） |
| [examples/questions/](examples/questions/) | 範例題目 YAML |

## 使用順序

1. 你：依 06 的「決定順序」逐波填「決定」。第 0、1 波決定後，T01～T04、T06 就能開工。
2. 你：確認 05 的〔提案〕規則，依 Q-R2 放到 repo 根目錄。
3. 交給 AI：規範檔 + 「做 04 的 Txx」。AI 遇到未決定的問題要停下來問。

## 標記

| 標記 | 意義 |
| --- | --- |
| （文件：節名） | 內容來自規劃文件的該節 |
| 規格慣例 | 規劃文件沒寫、屬於實作細節，由本規格訂定，可否決；集中列在 01 §2 與 02 §1.1 |
| 〔提案〕 | 規範檔草稿中由本規格提出的規則 |
| 〔待決 Q-xx〕 | 尚未決定，見 06；DDL 與 JSON Schema 中以註解或 `$comment` 標示 |
| 條件 | 對應問題決定「要做」之後才實作 |

## 規劃文件章節對照

| 規劃文件 | 規格位置 |
| --- | --- |
| 系統定位、已決定事項 | 05 技術版本；06 Q-A1、Q-A2、Q-M7 |
| 待決定（間隔重複、親手寫的範圍、註冊邀請制） | 06 Q-L1、Q-R1、Q-A2 |
| 題目分類與資料結構 | 01 §3 V2；03 §1～§3 |
| 各類判題與技術 | 03 §4～§6；01 §6 |
| 手機體驗 | 02 §3.5；04 T20～T26；06 Q-F3、Q-F4 |
| 部署架構 | 04 T27～T30；06 Q-D1～Q-D5 |
| 題目來源與審核 | 03 §3；04 T09～T11；06 Q-I1～Q-I10 |
| 學習紀錄與每日量 | 01 §3 V3、§5.3、§5.4；06 Q-P6、Q-P7、Q-S1～Q-S3 |
| 小巧思 | 01 §6；02 §6；06 Q-L10、Q-L11 |
| 開發順序 | 04（第一階段）；01 §6、02 §6、03 §6（第二～七階段草案） |

## 已做的驗證（2026-09-25）

| 項目 | 方法 | 結果 |
| --- | --- | --- |
| DDL | Flyway 11.14.1 分別對 `mysql:8.0`（8.0.46）與 `mysql:8.4`（8.4.11）執行 01 的 9 個 migration；另把所有〔待決〕欄位取消註解再執行一次 | 兩個版本、兩種變體都成功；兩版本的索引與外鍵相同且與規格一致；8.4 有 Flyway 版本警告 |
| JSON Schema | python-jsonschema 4.26.0 | 5 個 schema 合法；2 個範例通過；12 個錯誤範例全被拒絕；8 個 answer 案例符合預期 |
| JSON 範例 | 解析 01～06 中所有 `json` 區塊 | 27 個全部合法 |
| Java 型別 | 03 §2.1 以 JDK 21 + Jackson 3.0.4 編譯，並以假判題器實際執行 | 編譯成功；標準答案判為 CORRECT、答錯判為 WRONG、重複註冊時啟動失敗 |
| 交叉引用 | 腳本比對 04 與 06 | 所有 Q／T 編號都有定義；任務與待決問題的阻擋關係雙向一致；執行批次符合相依關係 |
| 版本事實 | 讀取 Spring Boot 4.0.3 BOM、Angular 22.2.0 schematics、hibernate-core 7.2.4 jar | 記錄在 05「已查證的事實」 |
