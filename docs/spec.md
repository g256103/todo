# PayPay ToDoコミットアプリ

## 確定仕様・要件定義・技術選定・ユースケース 統合ドキュメント（v3）

> これまでの会話で確定した事項を、実装前の基準資料として統合整理したもの。確定事項を中心に記載し、未確定事項は勝手に補完しない。

### 改訂履歴

| 版 | 内容 | 変更点 |
|---|---|---|
| v1 | 初版 | 要件定義・仕様・データ設計・技術選定の基礎資料として作成。 |
| v2 | 前版 | 4秒長押しタスク完了機能（バッテリー充電アニメーション）の検討結果を反映。長押しアニメーションの仕様変更、実装障壁の検討（①〜㉑）、技術選定の補足検討（T1〜T7）を本文および付録に統合。 |
| v3 | 本書 | ユースケース一覧（UC1〜UC26）を新規章として追加し、要件定義・仕様・技術選定と統合。 |

---

## 目次

1. プロダクト概要・目的
2. 金額・期限・チャレンジ
3. 開始仕様
4. タスク完了仕様
5. タスク・ルーティーン
6. 支払い・PayPayモック
7. 成功・失敗・ポイント
8. QR仕様
9. UI・画面
10. データモデル
11. リレーション
12. 状態遷移
13. Transaction・競合制御
14. 技術選定
15. アーキテクチャ責務
16. Flutter構成
17. Edge Functions
18. 実装順序チェックリスト
19. テストチェックリスト
20. 完成条件チェックリスト
21. 実装上の重要原則
22. 実装前の最終確認
23. ユースケース一覧（新規）
- 付録A：長押しタスク完了機能の検討詳細（①〜㉑）
- 付録B：技術選定の補足検討事項（T1〜T7）

---

## 1. プロダクト概要・目的

- [ ] ToDo開始前にユーザーが金額をコミットし、チャレンジを完遂した場合に返金される仕組みにする。
- [ ] チャレンジ達成をゲーム的に体験できるパズル／QR開放演出を実装する。
- [ ] 失敗して返金されなかった金額は、制限付きの教育用途ポイントとして扱う。
- [ ] Phase 2では外部サービスとの交換を想定する。

## 2. 金額・期限・チャレンジ

- [ ] チャレンジ金額は100円から5000円まで、100円単位。
- [ ] 期限は絶対日時。途中で期限をずらさない。
- [ ] タスク期限の変更は不可。
- [ ] 全タスク完了で自動的にSUCCESS。
- [ ] 成功後はそのチャレンジを変更不可。
- [ ] 取り消しは「取り消し完了」とする。
- [ ] ユーザーのタスク削除等で返金条件を崩す操作は許可しない設計を維持する。

## 3. 開始仕様

- [ ] 支払い成功を確認した後、ユーザーが「始める」を押したら開始。
- [ ] ユーザーが押さなくても5分後に自動開始。
- [ ] ユーザーが押した場合の開始時刻は押した瞬間。
- [ ] 自動開始はサーバー時刻を基準にする。
- [ ] 手動開始と自動開始が競合しても二重開始しない。

## 4. タスク完了仕様（v2で更新）

- [ ] チャレンジ中の完了状態はchallenge_tasksに持たせる。
- [ ] 元のtasksにはチャレンジ中の完了状態を持たせない。
- [ ] 完了操作は4秒長押し。
- [ ] 【仕様変更】長押しアニメーションは、バッテリーが充電されるように満ちていく表現とする（旧仕様：ゲージが減っていく表現から変更）。
- [ ] 長押し中断（指を離す／キャンセル／アプリのバックグラウンド化）時は、進捗を即座に0へリセットする。
- [ ] 長押しは同時に1タスクのみ許可し、他タスクの長押しは排他制御で禁止する。
- [ ] 締切までの残り時間が5秒未満の場合、クライアント側UIで長押し開始自体を禁止する（UX目的のガードであり、最終判定はサーバー時刻を正とする）。
- [ ] 長押し完了（4秒経過）とサーバーでの完了確定は同一ではない。長押し完了後、サーバーが完了可否を判定して確定する。
- [ ] サーバー確定待ちの間は、満タン表示にローディング表示を重ねる。
- [ ] サーバーが完了を拒否した場合は、進捗0への逆再生アニメーションとエラーメッセージを表示する。
- [ ] 通信失敗・タイムアウト時も進捗0へ戻し、長押しからやり直させる。
- [ ] 同一リクエストの再送でも二重完了・二重報酬にしない（idempotency keyは長押し開始時にクライアントで発行し、メモリ上にのみ保持する。永続化はしない）。
- [ ] 最後のタスク完了、全タスク判定、SUCCESS化は同一トランザクションで扱う。
- [ ] deadline時刻ちょうどまでは完了可能、超過後は不可という整理。
- [ ] OSの支援機能（スクリーンリーダー等）が有効な場合は、長押しの代わりに確認ダイアログ（「このタスクを完了しますか？」→OK）による代替完了操作を提供する。呼び出し先は同じcomplete-taskエンドポイントとする。

## 5. タスク・ルーティーン

- [ ] ユーザーは自分のタスクを管理する。
- [ ] ルーティーンは現段階では他ユーザーと共有しない。
- [ ] ルーティーンは複数タスクをまとめて扱う。
- [ ] routineとtaskは多対多。
- [ ] チャレンジ作成時に対象タスクをchallenge_tasksへコピーする。
- [ ] 過去履歴はタスク名等のスナップショットを保持し、元タスク変更で履歴を変えない。

## 6. 支払い・PayPayモック

- [ ] PayPayはモック実装にとどめ、本番決済APIは実装しない。
- [ ] PayPayを使ったように見えるUI・状態遷移を作る。
- [ ] 実際のQR決済等のPayPay本番決済は行わない。
- [ ] モック上のPayment SUCCESS確認後にChallenge作成へ進む。
- [ ] PaymentとChallengeは別エンティティで管理する。
- [ ] 将来、本物の決済サービスへ差し替えやすい構造にする。

### 6.1 Mock Payment API（確定仕様）

Mock Paymentは認証済みユーザー専用のサーバー処理とし、Flutterから`payments`へ直接INSERT/UPDATEしない。FlutterはEdge Functionを呼び出し、Edge FunctionはPostgreSQL RPCを経由してPaymentを操作する。本番決済API、実際のQR決済、`service_role`を処理主体として使用しない。

Paymentの状態遷移は次の2つだけを許可する。

```text
PENDING → SUCCESS
PENDING → FAILED
```

`SUCCESS`と`FAILED`は終端状態とする。PENDING Paymentは自動FAILEDにしない。PENDINGまたはFAILEDのPaymentが存在していても、新しいidempotency keyによる新規Payment作成を許可する。FAILED Paymentは再利用・再開せず、再試行時は新しいPaymentを作成する。

#### `mock-payment-create`

Request:

```json
{
  "amount": 1000,
  "idempotency_key": "client-generated-key"
}
```

入力はJSON objectとする。`amount`はfiniteなnumberで、`Number.isInteger()`を満たし、100以上5000以下かつ100円単位でなければならない。`"1000"`のような文字列は拒否する。JSON parse後に整数値となる`1000.0`および`1e3`は許可する。

`idempotency_key`は1〜200文字とし、trim後に空文字となる値および前後に空白を含む値は拒否する。unknown fieldは禁止する。`user_id`、`status`、`paid_at`、`created_at`、`updated_at`などのサーバー管理項目はクライアントから指定できない。

サーバーはJWTから`auth.uid()`を取得し、PaymentをPENDINGで作成する。`id`はDBが生成し、`user_id`は`auth.uid()`、`paid_at`はNULL、timestampsはDBが生成する。Payment作成とidempotency record保存は同一transactionで処理する。

初回のResponseはHTTP 201とする。

```json
{
  "payment": {
    "id": "uuid",
    "amount": 1000,
    "status": "PENDING",
    "created_at": "timestamp"
  }
}
```

同一operation・同一key・同一Requestの再送時は、保存済みResponseをHTTP 200で返し、別Paymentを作成しない。

#### `mock-payment-success`

Request:

```json
{
  "payment_id": "uuid",
  "idempotency_key": "client-generated-key"
}
```

`payment_id`はUUIDとし、canonical lowercase UUIDへ正規化する。`idempotency_key`は1〜200文字とし、trim後に空文字となる値および前後に空白を含む値は拒否する。unknown fieldは禁止する。`amount`、`status`、`paid_at`、`user_id`などはクライアントから指定できない。

サーバーはJWTから`auth.uid()`を取得し、`id`と`user_id = auth.uid()`でPaymentを取得する。Payment行をFOR UPDATEでロックし、Paymentが存在しなければ`payment_not_found`、PENDING以外なら`payment_not_pending`とする。PENDINGの場合のみSUCCESSへ遷移させ、`paid_at`を`clock_timestamp()`で設定する。`id`、`user_id`、`amount`は変更しない。Payment更新とidempotency record保存は同一transactionで処理する。

ResponseはHTTP 200とする。

```json
{
  "payment": {
    "id": "uuid",
    "amount": 1000,
    "status": "SUCCESS",
    "paid_at": "timestamp"
  }
}
```

#### `mock-payment-failure`

Request:

```json
{
  "payment_id": "uuid",
  "idempotency_key": "client-generated-key"
}
```

認証、入力検証、所有者確認、ロック、冪等性の扱いは`mock-payment-success`と同じとする。PENDINGの場合のみFAILEDへ遷移させ、`paid_at`はNULLとする。

ResponseはHTTP 200とする。

```json
{
  "payment": {
    "id": "uuid",
    "amount": 1000,
    "status": "FAILED",
    "paid_at": null
  }
}
```

#### idempotency

次の3 operationを分離する。

```text
mock-payment-create
mock-payment-success
mock-payment-failure
```

`idempotency_keys`の`(user_id, key)`を使用し、次の値を保存する。

- `user_id`: JWTの`auth.uid()`
- `key`: Requestのidempotency key
- `operation`: 上記operation名
- `resource_id`: PaymentのID
- `request_hash`: idempotency keyを除いた正規化Requestのhash
- `response`: API Response JSON全体
- `created_at`: DB生成
- `expires_at`: DB default

`mock-payment-create`の正規化Requestは次のとおりとする。

```json
{
  "amount": 1000
}
```

`mock-payment-success`および`mock-payment-failure`の正規化Requestは次のとおりとする。

```json
{
  "payment_id": "canonical-lowercase-uuid"
}
```

同じoperation・同じkey・同じRequestの場合は保存済みResponseを返す。同じkeyでRequestが異なる場合、またはoperationが異なる場合はHTTP 409 `idempotency_key_reused`とする。

`expires_at`は24時間後に設定する。ただし、expires_atを過ぎてもidempotency keyは再利用不可とする。期限切れrecordのcleanupは今回実装しない。

#### RPC

DB処理は次のRPCで行う。

```text
public.mock_payment_create(integer, text) returns jsonb
public.mock_payment_success(uuid, text) returns jsonb
public.mock_payment_failure(uuid, text) returns jsonb
```

引数はそれぞれ`p_amount integer, p_idempotency_key text`、`p_payment_id uuid, p_idempotency_key text`とする。RPC内部の戻り値は次の形式とする。

```json
{
  "response": {
    "payment": {}
  },
  "replayed": false
}
```

`response`は外部API Response body、`replayed`は初回かidempotency再送かを示す内部情報とする。Edge Functionは`response`のみを外部へ返し、createでは`replayed = false`をHTTP 201、`replayed = true`をHTTP 200に変換する。success/failureは常にHTTP 200とする。

各RPCは`SECURITY DEFINER`、`SET search_path = ''`、`auth.uid()`、READ COMMITTED、`SET LOCAL lock_timeout = '3s'`、ユーザー単位advisory lock、必要なPaymentのSELECT FOR UPDATEを使用する。idempotency確認、Payment操作、Response保存は同一transactionで処理し、失敗時はPayment変更とidempotency recordをrollbackする。EXECUTEはauthenticatedだけに許可し、public、anon、service_roleからは明示的にREVOKEする。

ロック順序は次のとおりとする。

```text
user advisory lock
→ idempotency_keys
→ payments
```

#### エラーと同時実行

業務エラーはSQLSTATE `P0001`とし、messageには次の安定したerror codeを入れる。

```text
unauthorized
payment_not_found
payment_not_pending
idempotency_key_reused
payment_creation_conflict
invalid_amount
invalid_idempotency_key
```

lock timeoutはSQLSTATE `55P03`とし、Edge FunctionでHTTP 503 `temporary_unavailable`へ変換する。

HTTP APIの基本エラーは次のとおりとする。

| 条件 | HTTP | error code |
|---|---:|---|
| Authorization不正 | 401 | `unauthorized` |
| JSON不正 | 400 | `malformed_json` |
| POST以外 | 405 | `method_not_allowed` |
| amount不正 | 422 | `invalid_amount` |
| UUID不正 | 422 | `invalid_uuid` |
| idempotency key不正 | 422 | `invalid_idempotency_key` |
| unknown field | 422 | `unknown_field` |
| Payment不存在・他ユーザー | 404 | `payment_not_found` |
| 終端状態への遷移 | 409 | `payment_not_pending` |
| idempotency key再利用 | 409 | `idempotency_key_reused` |
| Payment作成競合 | 409 | `payment_creation_conflict` |
| lock timeout | 503 | `temporary_unavailable` |
| その他 | 500 | `internal_error` |

同一keyのcreateを同時に受けた場合、ユーザー単位advisory lockによりPaymentは1件だけ作成し、後続Requestは保存済みResponseを返す。同一Paymentへのsuccess同時実行、successとfailureの同時実行では、一方だけが状態遷移に成功し、後続Requestは`payment_not_pending`とする。

#### Security

Payment操作では、Paymentの所有者を必ず`id`と`user_id = auth.uid()`で確認する。存在しないPaymentと他ユーザーPaymentは同じ`payment_not_found`として扱う。RLSは変更せず、FlutterにpaymentsのINSERT/UPDATE/DELETE権限やidempotency_keysの権限を追加しない。Flutter、Edge Functionともにservice_roleを使用せず、Authorization headerとユーザーJWTを利用する。

#### Flutter接続

画面の基本フローは次のとおりとする。

```text
金額選択
↓
mock-payment-create
↓
PENDING
↓
Mock Payment画面
↓
支払い成功 / 支払い失敗
```

成功時は`mock-payment-success`を呼び、SUCCESSになったPaymentの`payment_id`をChallenge作成へ渡す。失敗時は`mock-payment-failure`を呼び、FAILED Paymentは再開せず、新しいPaymentを作成して再試行する。Mock Payment画面では「支払い成功」と「支払い失敗」を選択できる。

Challenge作成時は、Payment操作とは別の新しいidempotency keyを使用し、既存仕様どおり次だけを送信する。

```json
{
  "payment_id": "uuid",
  "task_ids": [],
  "routine_ids": [],
  "idempotency_key": "new-key"
}
```

Flutterから`user_id`、`status`、`paid_at`、`created_at`、`updated_at`、Payment amountの再指定、`service_role`、`deadline`、`auto_start_at`、`task_name_snapshot`、展開済みRoutine Taskを送信しない。

## 7. 成功・失敗・ポイント

- [ ] SUCCESS時にQRを利用可能にする。
- [ ] SUCCESS時はチャレンジ金額（`challenges.amount`、全額）をモック返金する。`payments.status`はコミット時の`SUCCESS`を維持し、返金は`challenges.refunded_at`で記録する（ポイント台帳には載せない）。
- [ ] モック返金は`complete_task` RPC内で、初回のチャレンジ`SUCCESS`遷移と`qr_codes`作成と同一トランザクションで行う。別のMock Payment Edge Functionは追加しない。
- [ ] 期限到達時に未完了ならFAILED。
- [ ] FAILED時、返金されなかった金額を教育用途ポイントとして付与する。
- [ ] ポイント用途は書籍・学習・資格教材等。
- [ ] ポイント有効期限は3か月。
- [ ] ポイントは譲渡不可。
- [ ] 現金化条件は7回の成功かつ1週間以上の継続条件。
- [ ] 現金化手数料は10%。
- [ ] ポイント画面では保有ポイントと進捗を表示する。
- [ ] 進捗表示として「n pt」「4/7」「あと3日」等を使用する。

## 8. QR仕様（v2で更新）

- [ ] 成功後にQRを利用可能にする。
- [ ] 実際のカメラでQRを読み取れるようにする。
- [ ] QRにはランダムなtoken等を持たせ、サーバーで検証する。トークン生成にはcrypto.randomUUID()等、暗号学的に安全な乱数を使用する。
- [ ] QRはAVAILABLEから一度利用するとUSED。
- [ ] 同じQRの二重利用を防止する。
- [ ] SUCCESS前は利用不可。
- [ ] QR利用時はサーバーでChallenge状態とQR状態を確認する。

## 9. UI・画面（v2で更新）

- [ ] Bottom Navigationは「メイン / ポイント / 設定 / 履歴 / 編集」。
- [ ] メイン：金額選択→モックPayment→ToDo設定→Challenge作成。
- [ ] 編集：タスク／ルーティーンを管理。左で編集・削除、右で登録する方針。
- [ ] ルーティーン長押しで含まれるタスクを確認。
- [ ] チャレンジ中：完了タスクを緑、未完了タスクを白。
- [ ] チャレンジ中のタスク完了操作は4秒長押し。長押し中はバッテリーが充電されるように満ちていくアニメーションを表示する（単色＋満タン時のみ軽い光の演出。CustomPainterで描画）。
- [ ] 支援機能（スクリーンリーダー等）利用時は、長押しUIと並行して確認ダイアログによる代替完了操作を提供する。
- [ ] 履歴：日付・チャレンジ額・結果。長押しで詳細。
- [ ] 履歴詳細：完了タスクを緑、未完了タスクを赤。
- [ ] 設定：ユーザー名・利用規約等。
- [ ] 成功時：ランダム位置からパズルピースが飛び、QRが完成する。
- [ ] 成功時：コンフェッティ・「おめでとう」等の演出と振動。
- [ ] 「充電」（進行中プロセスの表現）と「パズル」（達成結果の表現）は役割を分離し、世界観の完全な統一は必須要件としない。色・角丸・影の質感などトーンのみアプリ全体で統一する。

## 10. データモデル（v2で更新）

**users**
id PK / user_name / created_at / updated_at / deleted_at / auth.usersと1:1

**tasks**
id PK / user_id FK / name / created_at / updated_at / チャレンジ完了状態は持たない

**routines**
id PK / user_id FK / name / created_at / updated_at / ユーザー間共有なし

**routine_tasks**
routine_id FK / task_id FK / PK=(routine_id, task_id) / 多対多

**payments**
id PK / user_id FK / amount（integer、円単位・小数点なし） / status / created_at / paid_at / PENDING/SUCCESS/FAILED

**challenges**
id PK / user_id FK / payment_id FK / amount（integer） / status / created_at / auto_start_at / started_at / deadline / finished_at / refunded_at（timestamptz、モック返金確定時刻） / WAITING/IN_PROGRESS/SUCCESS/FAILED。`status = 'SUCCESS'`のときのみ`refunded_at`はNOT NULL（`FAILED`等ではNULL）。

**challenge_tasks**
id PK / challenge_id FK / task_id FK / task_name_snapshot / status / completed_at / created_at / INCOMPLETE/COMPLETED

**points**
user_id PK/FK / available_points / created_at / updated_at / ユーザー1人1口座

**point_transactions**
id PK / user_id FK / challenge_id FK / type / amount / expires_at / created_at / 二重付与防止制約

**qr_codes**
id PK / challenge_id FK / token（暗号学的に安全な乱数で生成） / status / created_at / used_at / AVAILABLE/USED

**purchases**
id PK / user_id FK / points_used / item_name / status / created_at / completed_at

**cashouts**
id PK / user_id FK / points_used / fee_points / cash_amount / status / created_at / completed_at

**idempotency_keys**
key / user_id / operation / resource_id / created_at / 重要操作の二重実行防止

## 11. リレーション

- [ ] auth.users : users = 1:1。
- [ ] users : tasks = 1:N。
- [ ] users : routines = 1:N。
- [ ] routines : tasks = N:M（routine_tasks）。
- [ ] users : payments = 1:N。
- [ ] payment : challenge = 1:0..1（payment_idを一意にする）。
- [ ] challenge : challenge_tasks = 1:N。
- [ ] users : points = 1:1。
- [ ] users : point_transactions = 1:N。
- [ ] challenge : qr_code = 1:1。
- [ ] users : purchases = 1:N。
- [ ] users : cashouts = 1:N。

## 12. 状態遷移

- [ ] Challenge：WAITING → IN_PROGRESS（手動開始または5分後自動開始）。
- [ ] Challenge：IN_PROGRESS → SUCCESS（全challenge_tasksがCOMPLETED）。
- [ ] Challenge：IN_PROGRESS → FAILED（deadline到達時に未完了）。
- [ ] SUCCESS後は変更不可。
- [ ] FAILED後は変更不可。
- [ ] challenge_task：INCOMPLETE → COMPLETED。
- [ ] COMPLETEDへの再送は何もしない。

## 13. Transaction・競合制御（v2で更新）

- [ ] Challenge作成＋challenge_tasks作成を1トランザクション。
- [ ] Task完了＋全タスク確認＋SUCCESS化を1トランザクション。
- [ ] SUCCESS＋モック返金（`refunded_at`設定）＋QR AVAILABLE化を一体で確定。
- [ ] FAILED＋ポイント付与を1トランザクション。
- [ ] ポイント交換を1トランザクション。
- [ ] 現金化を1トランザクション。
- [ ] QR使用を1トランザクション。
- [ ] 開始処理ではChallengeをロックして二重開始を防ぐ。
- [ ] QR使用ではQRをロックして二重使用を防ぐ。
- [ ] 重要処理は冪等性を持たせる。
- [ ] 外部サービスを将来導入する場合、DBトランザクションと外部API処理は分離する。
- [ ] Challenge行のロックはSELECT ... FOR UPDATEで取得し、ロック取得順序は「challenges→challenge_tasks→qr_codes」に統一してデッドロックを回避する。
- [ ] トランザクション分離レベルはデフォルトのREAD COMMITTEDを維持し、SERIALIZABLEは採用しない。
- [ ] lock_timeoutを数秒に明示設定し、タイムアウト時はクライアント側の通常エラーハンドリングに合流させる。
- [ ] Task完了処理のトランザクション本体は、PL/pgSQLストアドファンクションとしてDB側に実装し、Edge FunctionはRPCを1回呼ぶだけにする方式を推奨する。

## 14. 技術選定（v2で新規記載）

### 採用技術

- [ ] フロントエンド：Flutter（UI・アニメーション・カメラ・長押し・画面遷移）
- [ ] BaaS：Supabase（Auth／PostgreSQL／Edge Functions／Cron／RLS）
- [ ] 状態管理：Riverpod

### 補足検討事項（未決定・未選定を含む）

| # | 論点 | 状態 | 内容 |
|---|---|---|---|
| T1 | Edge Function内のトランザクション実装方式 | 未決定（推奨案あり） | PL/pgSQLストアドファンクションにロジックを実装し、Edge FunctionはRPCを1回呼ぶ方式を推奨。 |
| T2 | pg_cronの実行粒度 | 留意事項 | 最短1分単位。自動FAILED化に最大1分のタイムラグが生じ得るが、個々の完了判定には影響しない。 |
| T3 | 監視・エラートラッキング | 未選定 | Sentry等（Flutter/Deno双方対応）の導入を検討。 |
| T4 | 環境分離（dev/staging/production） | 未記載 | プロジェクト分離かスキーマ分離かを決定する必要がある。 |
| T5 | QRトークンの生成方式 | 未明記 | crypto.randomUUID()等、暗号学的に安全な乱数を使用する。 |
| T6 | 重要APIへのレート制限 | 未検討 | complete-task・use-qr等へのレート制限・不正リクエスト対策を検討。 |
| T7 | amount（金額）のデータ型 | 未明記 | 円単位・小数点なしのinteger型で統一する。 |

## 15. アーキテクチャ責務

- [ ] Flutter：UI、アニメーション、カメラ、長押し、画面遷移、ユーザー入力。
- [ ] Edge Functions：Challenge開始、Task完了判定、SUCCESS/FAILED、ポイント、QR検証、現金化、Mock Payment等。
- [ ] PostgreSQL：保存、FK、UNIQUE、CHECK、Transaction、Lock、RLS。
- [ ] Cron：5分自動開始、deadline処理。
- [ ] 重要状態をFlutterから直接UPDATEさせない。
- [ ] RLSは「誰のデータにアクセスできるか」、Edge Functionsは「何をしてよいか」を主に担う。

## 16. Flutter構成

```
lib/
├─ main.dart
├─ core/（constants／errors／router／theme／utils／widgets）
├─ features/（auth／challenge／tasks／routines／points／history／qr／payment／settings）
│　※challenge配下に長押し完了アニメーション（バッテリー充電表現）・進捗共有Provider・アクセシビリティ代替操作を実装する。
└─ services/（supabase_service.dart／vibration_service.dart／mock_payment_service.dart）
```

## 17. Edge Functions（v2で更新）

- [ ] create-challenge
- [ ] start-challenge
- [ ] complete-task（レスポンスにresult種別：completed／challenge_success／already_completed／deadline_exceeded／invalid_stateを含める）
  - complete-task: 業務上の結果は HTTP 200 の result で返す(completed / challenge_success / already_completed / deadline_exceeded / invalid_state)。invalid_state は challenge が IN_PROGRESS でない場合(未開始・SUCCESS 済み・FAILED 済み)。認証・入力不正・対象なし・冪等キー不整合・競合・一時障害は error_code + 4xx/5xx。
  - `result = challenge_success`のとき、RPCレスポンス（Edgeはそのまま返す）に`refunded: true`と`refund_amount`（integer、円、`challenges.amount`と同値）を含める。それ以外の result では含めない。
- [ ] process-auto-start
- [ ] process-deadlines
- [ ] use-qr
- [ ] purchase-points
- [ ] cashout-points
- [ ] mock-payment-create
- [ ] mock-payment-success
- [ ] mock-payment-failure

## 18. 実装順序チェックリスト

- [ ] Flutterプロジェクト作成
- [ ] Supabaseプロジェクト作成・接続
- [ ] Git/GitHub設定
- [ ] DB Migration
- [ ] 外部キー・UNIQUE・CHECK等の制約
- [ ] RLS
- [ ] Google Auth
- [ ] Task CRUD
- [ ] Routine CRUD
- [ ] Routine-Task連携
- [ ] Mock Payment
- [ ] Challenge作成
- [ ] Challenge開始
- [ ] 状態管理の骨格（長押し進捗・排他制御用StateNotifier）
- [ ] Task完了（4秒長押し・バッテリー充電アニメーション）
- [ ] complete-taskのレスポンス契約実装（result種別）
- [ ] deadline境界のクライアントガードとサーバー側ロック戦略
- [ ] 冪等性（idempotency key）の組み込み
- [ ] アクセシビリティ代替操作（確認ダイアログ）
- [ ] SUCCESS/FAILED
- [ ] 5分自動開始
- [ ] deadline処理
- [ ] Points
- [ ] Point expiry
- [ ] Purchase
- [ ] Cashout
- [ ] QR生成
- [ ] QR読み取り
- [ ] QR一回利用
- [ ] History
- [ ] History Snapshot
- [ ] Settings
- [ ] パズル演出
- [ ] 成功演出
- [ ] 振動
- [ ] GitHub Actions
- [ ] テスト
- [ ] エラー処理
- [ ] 二重リクエスト対策
- [ ] リリース前確認

## 19. テストチェックリスト（v2で更新）

- [ ] Payment SUCCESS / FAILED / 二重処理
- [ ] Challenge作成 / 二重作成防止
- [ ] 手動開始 / 5分自動開始 / 手動と自動の競合
- [ ] 4秒長押し / タスク二重完了
- [ ] 長押し中断（指を離す／アプリバックグラウンド化）時の進捗リセット
- [ ] サーバー拒否時の逆再生アニメーションとエラーメッセージ表示
- [ ] 支援機能有効時の代替完了操作（確認ダイアログ）
- [ ] バッテリー描画のゴールデンテスト（画面サイズ差異）
- [ ] 最後のタスク完了→SUCCESS
- [ ] deadline直前 / deadlineちょうど / deadline後
- [ ] deadline処理と完了処理の競合
- [ ] SUCCESS後・FAILED後の変更拒否
- [ ] FAILED→ポイント付与 / ポイント二重付与防止 / 3か月期限 / 譲渡不可
- [ ] ポイント交換 / 残高不足
- [ ] 7回未満・1週間未満の現金化拒否
- [ ] 現金化10%手数料 / 二重申請
- [ ] QR成功前拒否 / 成功後利用 / 二重利用拒否 / 不正QR
- [ ] 履歴Snapshot維持
- [ ] RLSによる他ユーザー情報遮断
- [ ] 通信再送時の冪等性
- [ ] アプリ終了中のCron処理
- [ ] Googleログイン後のデータ継続

## 20. 完成条件チェックリスト

- [ ] Googleログインが動作する
- [ ] タスク・ルーティーン管理が動作する
- [ ] 100～5000円・100円単位の金額選択が動作する
- [ ] Mock Paymentが動作する
- [ ] Challengeが作成できる
- [ ] Challengeを手動開始できる
- [ ] 5分後の自動開始が動作する
- [ ] 4秒長押しでタスク完了できる（バッテリー充電アニメーション）
- [ ] 長押し中断時に進捗が正しくリセットされる
- [ ] サーバー拒否時に適切なフィードバックが表示される
- [ ] 支援機能利用時に代替完了操作が機能する
- [ ] 全タスク完了でSUCCESSになる
- [ ] deadlineでFAILEDになる
- [ ] SUCCESS時にモック返金される
- [ ] FAILED時にポイントが付与される
- [ ] QRを実際に読み取れる
- [ ] QR二重利用が防止される
- [ ] ポイント交換が動作する
- [ ] 現金化と10%手数料が動作する
- [ ] 履歴と詳細が表示される
- [ ] 過去履歴が後から変化しない
- [ ] RLSが機能する
- [ ] 重要処理がサーバー側で検証される
- [ ] Transactionで整合性が守られる
- [ ] 二重リクエストに耐えられる
- [ ] Cronがアプリ終了中でも処理する
- [ ] 自動テスト・静的解析を通過する

## 21. 実装上の重要原則（v2で追記）

- [ ] 画面上の成功表示とサーバーが成功を確定した状態を混同しない。
- [ ] 重要状態はサーバー・DBを正とする。
- [ ] FlutterからChallenge SUCCESS、ポイント残高、QR使用済み等を直接書き換えさせない。
- [ ] 重要状態遷移はEdge Functionsで検証する。
- [ ] TransactionとLockで競合を処理する。
- [ ] 同じリクエストが複数回届いても安全な冪等設計にする。
- [ ] 履歴はChallenge時点のSnapshotを参照する。
- [ ] PayPayはモックであり、本番決済機能として扱わない。
- [ ] 仕様変更時は変更前・変更後・影響範囲を記録する。
- [ ] 長押しアニメーションの完了とサーバーでの完了確定を混同しない。
- [ ] 長押し専用の完了操作に加えて、アクセシビリティ配慮の代替手段を必ず用意する。

## 22. 実装前の最終確認（v2で追記）

- [ ] 要件定義を本書と照合した
- [ ] Challengeの状態遷移を確認した
- [ ] challenge_tasksが完了状態の正しい保持先になっていることを確認した
- [ ] deadlineが絶対日時であることを確認した
- [ ] 5分自動開始を確認した
- [ ] PayPayはモックであることを確認した
- [ ] QRは実カメラで読み取ることを確認した
- [ ] ポイント・現金化・10%手数料を確認した
- [ ] 履歴仕様を変更していないことを確認した
- [ ] DB Transaction / Lock / 冪等性方針を確認した
- [ ] Flutter + Supabase + PostgreSQL + Edge Functions + Cron + Riverpodの技術選定を確認した
- [ ] 未確定事項を勝手に仕様化していないことを確認した
- [ ] 長押しアニメーションの仕様変更（充電表現への変更）を確認した
- [ ] Postgresロック戦略（ロック順序・分離レベル・lock_timeout）を確認した
- [ ] アクセシビリティ代替操作を確認した
- [ ] 技術選定の補足事項（監視・環境分離・QRトークン生成・レート制限・amount型）を確認した

---

## 23. ユースケース一覧（新規）

### アクター

| アクター | 説明 |
|---|---|
| ユーザー | エンドユーザー。自分のデータのみアクセス可能（RLS前提） |
| システム（自動処理） | pg_cronによる自動開始・deadline処理・ポイント失効など、ユーザー操作を介さない処理 |

管理者ロールは仕様書に記載がないため、アクターに含めていない。

### 1. 認証
- UC1：Googleアカウントでログイン／サインアップする（ユーザー）

### 2. タスク・ルーティーン管理
- UC2：タスクを登録・編集・削除する（ユーザー）
- UC3：ルーティーンを登録・編集・削除する（ユーザー）
- UC4：ルーティーンに複数タスクを紐付ける（ユーザー）
- UC5：ルーティーンを長押しして内容を確認する（ユーザー）

### 3. チャレンジ作成（支払い）
- UC6：チャレンジ金額を選択する（100〜5000円・100円単位）（ユーザー）
- UC7：Mock Paymentで支払いを完了する（ユーザー）
- UC8：対象タスクを選び、Challengeを作成する（payment確認後、challenge_tasksへタスクをコピー）（ユーザー）

### 4. チャレンジ開始
- UC9：Challengeを手動で開始する（ユーザー）
- UC10：Challengeが5分後に自動開始される（システム／手動と排他制御）

### 5. タスク完了（チャレンジ進行中）
- UC11：タスクを4秒長押しして完了操作する（バッテリー充電アニメーション）（ユーザー）
- UC12：長押しを中断し、進捗を0にリセットする（ユーザー）
- UC13：支援機能（スクリーンリーダー等）利用時、確認ダイアログで完了操作する（ユーザー）
- UC14：サーバーが完了可否を判定し確定する（完了拒否時は逆再生＋エラー表示）（システム／サーバー側）
- UC15：全タスク完了によりChallengeがSUCCESSになる（システム）

### 6. チャレンジ終了処理
- UC16：deadline到達時、未完了ならChallengeがFAILEDになる（システム）
- UC17：SUCCESS時にモック返金を受け取る（`complete_task`によるシステム自動処理。UIは成功演出・文言で受け取りを表示）
- UC18：FAILED時、未返金分が教育用途ポイントとして付与される（システム）

### 7. QR
- UC19：SUCCESS後、QRコードをカメラで読み取り利用する（ユーザー、二重利用防止・サーバー検証あり）

### 8. ポイント
- UC20：保有ポイントと進捗（n pt／4/7／あと3日等）を確認する（ユーザー）
- UC21：ポイントを書籍・学習教材等と交換する（ユーザー）
- UC22：ポイントを現金化する（7回成功かつ1週間以上継続、手数料10%）（ユーザー）
- UC23：ポイントが3か月で失効する（システム）

### 9. 履歴
- UC24：チャレンジ履歴一覧を確認する（日付・金額・結果）（ユーザー）
- UC25：履歴詳細（タスクごとの完了／未完了）を確認する（ユーザー）

### 10. 設定
- UC26：ユーザー名・利用規約等を確認する（ユーザー）

---

## 付録A：長押しタスク完了機能の検討詳細（①〜㉑）

本文4章・9章・13章に反映済みの決定事項について、検討時の背景を含めた詳細を記録する。

| # | 論点 | 状態 | 決定内容／現状 |
|---|---|---|---|
| ① | アニメーション実装 | 決定 | CustomPainterでバッテリー筐体を描画。進捗はAnimationController（4秒）のvalueで表現。単色＋満タン時のみ軽い光の演出。共通コントローラーを1つだけ使用。 |
| ② | ジェスチャー制御 | 決定 | 中断時（release/cancel）は進捗を即座に0へリセット。独自move判定は追加しない。 |
| ③ | クライアント/サーバー状態ズレ | 決定 | 4秒後は満タン+ローディング重ね。承認で緑へ、拒否で逆再生＋Snackbar。通信失敗時はやり直し。 |
| ④ | deadline境界 | 決定 | 残り時間5秒未満で長押し開始を禁止。最終判定はサーバー時刻で厳密に行う。 |
| ⑤ | 冪等性・トランザクション整合 | 決定 | idempotency keyはonLongPressStart時にUUID発行、メモリ保持のみ。 |
| ⑥ | ライフサイクル・端末差異 | 決定 | バックグラウンド遷移で即キャンセル。モーション削減はスコープ外。長押し中の振動なし。 |
| ⑦ | 不正対策・信頼境界 | 決定 | サーバー側での長押し時間検証はMVPではスコープ外（自己コミット型のため）。 |
| ⑧ | テスト実装 | 決定 | tester.pumpでアニメーション時間短縮。deadline境界テストに長押しケースを追加。 |
| ⑨ | 状態管理（Riverpod） | 決定 | 単一StateNotifierで長押し状態を一元管理。他端末リアルタイム同期はスコープ外。 |
| ⑩ | Edge Functionレスポンス設計 | 決定 | complete-taskはresult種別（completed/challenge_success/already_completed/deadline_exceeded/invalid_state）を返す。 |
| ⑪ | 押下可否の事前判定 | 決定 | 判定優先順位：Challenge状態→タスク完了済み→残り時間バッファ→通常。 |
| ⑫ | 他タスクとの排他制御 | 決定 | 長押しは同時に1タスクのみ許可。タップは排他対象外。 |
| ⑬ | デザインシステム整合 | 決定 | 充電＝プロセス表現、パズル＝結果表現として役割分離。 |
| ⑭ | ListView再利用時の破棄 | 要実機検証 | 進捗はProviderで一元管理のため致命傷になりにくいが、実機検証が必要。 |
| ⑮ | アクセシビリティ | 決定 | 支援機能有効時は確認ダイアログによる代替完了操作を提供。Semanticsで進捗を読み上げ可能に。 |
| ⑯ | 認証トークン失効タイミング | 未決定 | セッションリフレッシュのタイミング設計が必要。 |
| ⑰ | サーバー時刻オフセット取得方法 | 未決定 | 具体的な取得APIとオフライン時フォールバックが未定義。 |
| ⑱ | Postgresロック戦略 | 決定 | Challenge行をFOR UPDATEでロック。READ COMMITTED維持。ロック順序統一。lock_timeout明示設定。 |
| ⑲ | Edge Functionコールドスタート遅延 | 設計時考慮 | ローディング表示で体感を吸収する想定。 |
| ⑳ | タップとの併用によるジェスチャー競合 | 実装時対応 | ゴーストタップに画面ごと個別対応。 |
| ㉑ | アニメーションのテスト脆弱性 | テスト整備要 | 画面サイズ差異のゴールデンテストを別途整備。 |

## 付録B：技術選定の補足検討事項（T1〜T7）

本文14章に反映済みの技術選定補足事項について、詳細を記録する。

| # | 論点 | 状態 | 内容 |
|---|---|---|---|
| T1 | Edge Function内のトランザクション実装方式 | 未決定（推奨案あり） | PL/pgSQLストアドファンクションにロジックを実装し、Edge FunctionはRPCを1回呼ぶ方式を推奨。 |
| T2 | pg_cronの実行粒度 | 留意事項 | 最短1分単位。自動FAILED化に最大1分のタイムラグが生じ得るが、個々の完了判定には影響しない。 |
| T3 | 監視・エラートラッキング | 未選定 | Sentry等（Flutter/Deno双方対応）の導入を検討。 |
| T4 | 環境分離（dev/staging/production） | 未記載 | プロジェクト分離かスキーマ分離かを決定する必要がある。 |
| T5 | QRトークンの生成方式 | 未明記 | crypto.randomUUID()等、暗号学的に安全な乱数を使用する。 |
| T6 | 重要APIへのレート制限 | 未検討 | complete-task・use-qr等へのレート制限・不正リクエスト対策を検討。 |
| T7 | amount（金額）のデータ型 | 未明記 | 円単位・小数点なしのinteger型で統一する。 |


---

## 変更記録(v4)

### 変更1:長押し完了の視覚表現

- **変更前**:長押し中、バッテリーが充電されるように満ちていく(CustomPainterでバッテリー筐体を描画)。
- **変更後**:
  - 長押し中は、押しているタスク行の背景に緑の液体が下から上へチャージされる(4秒で0→100%、液面は波打つ)。この間、QRは変化させない。
  - サーバーが承認した後、そのタスクに割り当てたQRのセルが全体に散らばって現れる。完了するたびにQRが濃くなる。
  - 最後のタスクの承認で、位置検出パターンを含む残りのセルが現れ、QRが完成する。
- **変わらないもの**:4秒長押し、中断時の即時0リセット、同時に1タスクのみ、サーバー確定待ちのローディング、拒否時の逆再生とエラー表示、代替完了操作、残り5秒未満の開始禁止、冪等性。
- **役割の整理**:液体のチャージ=進行中(プロセス)の表現、QRの出現=達成結果の表現。「充電=プロセス、パズル=結果」の役割分離(9章・付録A⑬)はそのまま維持される。

### 変更2:ボトムナビゲーションのデザイン

- 半透明のガラス風(フローティングのカプセル型)とする。詳細な値は `docs/mock/code/` を参照。

### 影響範囲

| 箇所 | 影響 |
|---|---|
| 4章 タスク完了仕様 | 「バッテリー」の記述を「液体チャージ」に読み替える |
| 9章 UI・画面 | 同上。「CustomPainterで描画」は液体の波の描画に読み替える(実装手段は未確定) |
| 16章 Flutter構成 | challenge配下の長押しアニメーション実装が、バッテリー描画から液体チャージ+QRセル表示に変わる |
| 19章 テスト | 「バッテリー描画のゴールデンテスト」は「液体チャージ描画・QRセル表示のゴールデンテスト」に読み替える |
| 付録A ①、⑬、㉑ | 同上 |

### 未確定(勝手に仕様化しない)

- QRのセルをタスクごとに割り当てる具体的な方式(モックの方式をそのまま採用するか)
- 液体の波の描画をFlutterでどう実装するか


## 変更記録 v5(2026-10-05): DB設計の確定

### 1. 反映状況
- Migration 7ファイル(`supabase/migrations/20261005010000` 〜 `20261005070000`)を本番に適用済み
- 仕様書10章との照合で見つかったずれを `20261005080000_spec_alignment.sql` で修正(本番反映は別途)
- pgTAP 57項目(`supabase/tests/database/001_schema_constraints_rls.test.sql`)
- 適用済みのMigrationは書き換えない。修正は新しいMigrationで行う

### 2. 決定事項(①〜⑦)
| # | 項目 | 決定 | 理由 | 却下した案 |
|---|---|---|---|---|
| ① | QR行の作成時期 | **SUCCESS時に作成** | SUCCESS前はトークンがDBにもクライアントにも存在せず、漏洩しない。進行中画面は仮パターンを表示し、成功演出で本物に入れ替える | チャレンジ作成時に作成して利用拒否(トークンが先に端末へ渡る) / PENDING状態を追加(仕様にない状態が増える) |
| ② | ポイント失効(3か月) | 付与行に `remaining_amount` と `expires_at` を持ち、**期限が近い順(FIFO)に消費** | 付与ごとに期限が違い、一部使用後の失効額を決めるのに必要 | 残高のみ保持(3か月失効を満たせない) |
| ③ | 同時進行のChallenge | **ユーザーごとに1件**(WAITING / IN_PROGRESS)。部分ユニークインデックスで保証 | 後から緩めるのは容易 | 制限なし(同一タスクが複数Challengeに入る場合などの考慮が増える) |
| ④ | タスク削除時の `challenge_tasks.task_id` | `ON DELETE SET NULL`。`task_name_snapshot` で履歴を保持 | 元タスクは自由に削除でき、履歴とChallengeは変わらない | 進行中のタスクは削除禁止(ユーザーが混乱) |
| ⑤ | purchases / cashouts の status | `PENDING` / `COMPLETED` / `FAILED` | `completed_at` があり、この流れが自然 | - |
| ⑥ | `auto_start_at` と `deadline` | 起点はChallenge作成時刻、`auto_start_at` は5分後。`deadline > auto_start_at` をCHECK | 開始前に期限が来る事態を防ぐ | - |
| ⑦ | 手数料10%の端数 | `cashouts.points_used` は10の倍数に限定。`fee_points = points_used / 10` をCHECK | ポイントは整数で、端数が出ない | 端数の切り捨て・切り上げ(丸めの扱いが増える) |

### 3. Migration作成時の追加決定
| # | 決定 | 理由 | デメリット |
|---|---|---|---|
| 1 | `routine_tasks` / `challenge_tasks` に `user_id` を持たせ、**複合FKで持ち主の一致を保証** | RLSの漏れや `service_role` 経由でも不整合が入らない | 列が増え、INSERT時に `user_id` が必要 |
| 2 | SUCCESS遷移をDBで検証(タスク1件以上かつ全完了、`finished_at <= deadline`) | 関数側のバグがあっても不正な成功を止める | 関数側のロジックと二重管理 |
| 3 | WAITING → FAILED の直接遷移は禁止 | 厳しい側から始め、後から緩める | 開始前の取消機能を足す際はMigrationが必要 |
| 4 | Challenge作成はpaymentが `SUCCESS` のときのみ | 「決済成功後に作成」をDBが強制 | 決済と作成の間の失敗は⑧で別途対応 |
| 5 | 台帳・履歴の物理削除を禁止。`point_transactions` は `remaining_amount` の減算のみ可 | 監査と二重付与防止の土台 | 誤データの修正は打ち消し行の追加になる |
| 6 | 列単位のGRANT(`tasks` は `name` のみ更新可など) | `user_id` の付け替えを権限段階で止める | 列追加のたびにGRANTが必要 |
| 7 | サインアップトリガーは例外を握りつぶさない | 失敗を隠すと `users` 行のないユーザーが静かにできる | トリガー失敗時はサインアップも失敗 |
| 8 | ポイント付与(GRANT)は **FAILED のChallengeに対してのみ**許可 | 仕様書7章「FAILED時に付与」をDBが強制し、SUCCESSへの誤付与を防ぐ | 付与条件を広げる場合はMigrationが必要 |

### 4. 技術方針
- ID は `uuid`(`gen_random_uuid()`)、時刻は `timestamptz`、statusは `text + CHECK`(enum型は使わない)
- ユーザー参照のFKはすべて `ON DELETE RESTRICT`。退会は `deleted_at` で扱う
- 書き込みはサーバー側関数のみ。クライアントは `tasks` / `routines` / `routine_tasks` と `users.user_name` のみ書き込み可
- `anon` は何も不可。`idempotency_keys` はクライアントから一切不可
- 関数は `SECURITY DEFINER` + `search_path` 固定。実行権限は既定で誰にも与えず、使うものだけ個別に許可する
- ロック順序: `challenges` → `challenge_tasks` → `qr_codes` → `points` → `point_transactions`
- 完了判定は、Challenge行を `FOR UPDATE` で取得した後に `clock_timestamp()` と `deadline` を比べる(`now()` は使わない)。cronのFAILED化は最大1分遅れるため、IN_PROGRESSでも関数側で時刻を見て `deadline_exceeded` を返す
- 列指定の `ON DELETE SET NULL (task_id)` のため、PostgreSQL 15以上が必要

### 5. 影響範囲(仕様書の各章への影響)
| 章 | 影響 |
|---|---|
| 2章 金額・期限・チャレンジ / UC8 | ③により、WAITING / IN_PROGRESS のChallengeはユーザーごとに1件まで。進行中は新しいChallengeを作れない |
| 5章 タスク・ルーティーン | ④により、元タスクを削除してもChallengeと履歴は変わらない(`task_name_snapshot` で保持) |
| 7章 成功・失敗・ポイント | ②付与ごとに3か月の期限を持ち、期限が近い順に消費・失効する。⑦現金化に使うポイントは10の倍数。ポイント付与はFAILEDのChallengeのみ(追加決定8) |
| 8章 QR / 9章 UI | ①QRはSUCCESS時に作成する。進行中のセル表示は仮パターンで、読み取れるQRはSUCCESS時に初めて出る。13章「SUCCESS+QR AVAILABLE化を一体で確定」はこの方式で満たす |
| 10章 データモデル | 実装は10章に加えて次の列を持つ: `routine_tasks`(user_id, sort_order, created_at) / `challenge_tasks`(user_id, sort_order, updated_at) / `point_transactions`(remaining_amount, purchase_id, cashout_id) / `idempotency_keys`(request_hash, response, expires_at) / `payments`・`challenges`・`purchases`・`cashouts` の updated_at |
| 12章 状態遷移 | WAITING → FAILED は禁止。SUCCESSへの遷移はDBでも検証する(全タスク完了、`finished_at <= deadline`) |
| 13章 Transaction・競合制御 | ロック順序の末尾に `points` → `point_transactions` を追加する |
| 19章 テスト | 制約・遷移・RLS・二重付与防止は、pgTAP 57項目で確認済み |

### 6. 仕様書10章との照合結果(0008で対応)
| 項目 | 結果 | 対応 |
|---|---|---|
| `purchases.item_name` | 仕様書にあるが0005で漏れていた | 0008で追加(NOT NULL) |
| `idempotency_keys` の `operation` / `resource_id` | 仕様書にあるが0005で漏れていた | 0008で追加。0005で独自に入れた `request_hash` は必須をやめた |
| 外部決済ID | 仕様書の `payments` に無く、PayPayはモック | 追加しない |
| 他のテーブル | 仕様書の列を満たしている(`updated_at` など一部は仕様書より多い) | 変更なし |

### 7. 未確定事項
- **⑧ 決済成功後にChallengeを作らず離脱したpayment**: 今回は対応しない
- **`point_transactions.type` の値**: 仕様書に値の定義がない。現在は `GRANT` / `PURCHASE` / `CASHOUT` / `EXPIRE`
- **金額とポイントの換算**: 仕様書に記載がない。付与額とChallenge金額の関係、`cashouts.cash_amount` の式チェックは未設定
- **開始前の取り消し**: 仕様書2章に「取り消しは取り消し完了とする」とあるが、対応する状態・遷移の定義がない。現在は WAITING → FAILED を禁止
- **QRセルの割り当て方式**(v4から継続): 進行中の表示は仮パターンで、読み取れるQRはSUCCESS時に作成される
- **未作成のもの**: Challenge作成・完了・失効などのサーバー関数、pg_cronのジョブ、`idempotency_keys` の期限切れ削除

## 変更記録 v6(2026-10-06): Mock Payment API仕様の確定

### 変更前
- Mock Paymentは3つのEdge Function候補名と「モック決済」としての方針のみ定義され、Request/Response、エラー、冪等性、RPC、同時実行の詳細は未定義だった。

### 変更後
- `mock-payment-create`、`mock-payment-success`、`mock-payment-failure`のRequest/Response、入力検証、HTTP status、error codeを定義した。
- Payment状態遷移を`PENDING → SUCCESS`または`PENDING → FAILED`に限定し、PENDINGの自動FAILED化、終端状態の再利用・再開を行わないことを定義した。
- `idempotency_keys`のoperation、resource_id、request_hash、response、期限切れkeyの再利用不可、cleanup非実装を定義した。
- Edge FunctionからPostgreSQL RPCを呼び出し、`SECURITY DEFINER`、`auth.uid()`、ユーザー単位advisory lock、`SELECT FOR UPDATE`、3秒のlock timeout、同一transaction処理を行う設計を定義した。
- `create-challenge`へはSUCCESS後の`payment_id`とTask/RoutineのIDだけを渡し、amountやdeadline等をFlutterから送信しないことを定義した。

### 影響範囲

| 箇所 | 影響 |
|---|---|
| 6章 支払い・PayPayモック | Mock Payment APIの正式な状態遷移、API契約、冪等性、エラー、Security、Flutter接続を追加 |
| 10章 データモデル | 既存の`payments`および`idempotency_keys`の利用方法を明確化。スキーマ変更は行わない |
| 15章 アーキテクチャ責務 | Payment操作をEdge Function→PostgreSQL RPCで処理する責務を明確化 |
| 17章 Edge Functions | 既存のMock Payment 3 Function候補に正式契約を付与 |
| 18章 実装順序 | DB RPC・Edge Function・Flutter接続の前提仕様を確定 |

### 変更しないもの
- 既存migration、DB schema、RLS、grants、`create-challenge`、Flutterコード、Edge Functionコード、package、`.env`、Remote環境は変更しない。

## 変更記録 v7(2026-10-06): start-challenge仕様の確定

### 変更前
- Challenge開始APIのRequest/Response、冪等性、手動開始と自動開始の共通処理が未確定だった。

### 変更後
- `start-challenge`は`challenge_id`と`idempotency_key`だけを受け取り、UUIDはcanonical lowercase、keyは1〜200文字とする。
- 状態遷移は`WAITING → IN_PROGRESS`のみとし、手動開始は`auto_start_at`前でもサーバー時刻で開始する。`IN_PROGRESS`の再要求は既存の`started_at`を保持して現在状態を返す。
- `SUCCESS`/`FAILED`およびdeadline到達後は開始不可とし、手動開始と自動開始はChallenge行ロックを使う共通DB処理で競合を排除する。
- idempotency operationは`start-challenge`とし、同一key・同一request hashは保存済みResponseを返し、異なるoperationまたはhashは`idempotency_key_reused`とする。
- 自動開始は`process-auto-start`が共通の開始処理を実行する。定期実行のRemote設定はpg_cron/pg_net/Vaultの構成確定と承認後に行う。

### 影響範囲

| 箇所 | 影響 |
|---|---|
| 3章 開始仕様 | 手動開始、5分後自動開始、deadline、競合制御を明確化 |
| 13章 Transaction・競合制御 | `challenges`行ロックと`started_at`の一度だけ設定を適用 |
| 17章 Edge Functions | `start-challenge`と`process-auto-start`の責務を追加 |
| Flutter | WAITING画面から`start-challenge`を呼び、IN_PROGRESSを表示 |

## 変更記録 v8(2026-10-08): complete-task HTTP契約の明文化

### 変更前
- 17章の`complete-task`はresult種別を含める旨のみで、業務上の成功・ソフト拒否と認証・入力・競合等のエラーをHTTP statusとJSONでどう切り分けるかが本文に未記載だった。

### 変更後
- 業務上の結果は HTTP 200 の`result`（`completed` / `challenge_success` / `already_completed` / `deadline_exceeded` / `invalid_state`）で返す。`invalid_state`は challenge が IN_PROGRESS でない場合（未開始・SUCCESS 済み・FAILED 済み）。認証・入力不正・対象なし・冪等キー不整合・競合・一時障害は`error_code`と 4xx/5xx で返す。

### 影響範囲

| 箇所 | 影響 |
|---|---|
| 17章 Edge Functions | `complete-task`のHTTP 200`result`と`error_code`+4xx/5xxの切り分けを明文化 |
| Flutter / Edge Function | 既存実装（決定D）の契約を仕様本文に反映。付録A⑩のresult種別一覧は変更なし |

## 変更記録 v9(2026-10-08): SUCCESS時モック返金（決定C）

### 変更前
- 7章は「SUCCESS時にチャレンジ金額をモック返金」とあるが、台帳・API・`complete_task`との一体処理が未定義だった。

### 変更後
- 返金は`complete_task`内でチャレンジ初回`SUCCESS`と同一トランザクション。記録は`challenges.refunded_at`（金額は`challenges.amount`全額）。`payments`は終端`SUCCESS`を維持。
- `complete_task`の`challenge_success`レスポンスに`refunded: true`と`refund_amount`を含める。

### 影響範囲

| 箇所 | 影響 |
|---|---|
| 7章・10章・12章・13章 | 返金のデータとトランザクション境界を定義 |
| 17章・UC17 | complete-taskレスポンスとUC17の処理主体を明確化 |
| DB / Flutter | 新migration・RPC変更・pgTAP・Flutterは未実装（別タスク） |