# Copilot Instructions

## プロジェクト概要
ToDo完遂型のコミットアプリ。ユーザーが金額(100〜5000円、100円単位)をコミットし、期限内に全タスクを完了すると返金(モック)される。失敗した場合は返金されなかった金額が教育用途ポイントになる。
**仕様の正は `docs/spec.md`。末尾の「変更記録(v4)」を含めて、実装前に該当章を確認すること。**

## 技術スタック
- Flutter(UI・アニメーション・カメラ・長押し・画面遷移)
- 状態管理: Riverpod
- Supabase(Auth / PostgreSQL / Edge Functions / Cron / RLS)
- PayPayはモック実装のみ。本番決済APIは実装しない。将来差し替えやすい構造にする。

## 最重要原則
- 重要状態はサーバー・DBを正とする。画面上の成功表示とサーバー確定を混同しない。
- Challengeの SUCCESS/FAILED、ポイント残高、QR使用済みなどを、Flutterから直接 INSERT/UPDATE しない。必ずEdge Functions経由にする。
- 重要処理は冪等にする(同じリクエストが複数回届いても二重完了・二重報酬にしない)。
- 履歴は、Challenge作成時点のスナップショット(`task_name_snapshot` 等)を参照する。
- `service_role` キーをFlutterのコードやリポジトリに含めない。秘密情報は `.env` に置き、コミットしない。

## データベース
- 金額(amount)は円単位・小数点なしの integer。
- 外部キー、UNIQUE、CHECK制約をMigrationで必ず定義する。
- RLSは「誰のデータにアクセスできるか」、Edge Functionsは「何をしてよいか」を担当する。
- トランザクション分離レベルは READ COMMITTED を維持し、SERIALIZABLE は使わない。
- Challenge行は `SELECT ... FOR UPDATE` でロックする。ロック順序は **challenges → challenge_tasks → qr_codes** に統一する。
- `lock_timeout` を数秒に明示設定する。
- 次の処理は、それぞれ1トランザクションで扱う。
  - Challenge作成 + challenge_tasks作成
  - Task完了 + 全タスク確認 + SUCCESS化 + QR AVAILABLE化
  - FAILED化 + ポイント付与
  - ポイント交換、現金化、QR使用

## タスク完了(4秒長押し)
- 完了操作は4秒長押し。押しているタスク行の背景に、緑の液体が下から上へチャージされる(0→100%を4秒、液面は波打つ)。長押し中はQRを変化させない。
- 承認後、そのタスクに割り当てたQRのセルが現れる。最後のタスクの承認でQRが完成する。
- 中断時(指を離す/キャンセル/バックグラウンド化)は進捗を即座に0へリセットする。
- 長押しは同時に1タスクのみ。残り5秒未満は長押し開始を禁止する(UXガード。最終判定はサーバー時刻)。
- 長押し完了 ≠ 完了確定。サーバーが判定するまでローディングを重ねる。拒否時は液体が逆再生で下がり、エラー表示。
- idempotency key は長押し開始時にクライアントで発行し、メモリ上にのみ保持する(永続化しない)。
- スクリーンリーダー等の支援機能が有効な場合は、確認ダイアログによる代替完了操作を提供する(同じ complete-task を呼ぶ)。
- complete-task のレスポンスの `result` は次のいずれか: `completed` / `challenge_success` / `already_completed` / `deadline_exceeded` / `invalid_state`

## QR
- トークンは暗号学的に安全な乱数(`crypto.randomUUID()` 等)で生成する。
- SUCCESS前は利用不可。AVAILABLE→USEDの一度きり。サーバーでChallenge状態とQR状態を検証する。
- 完成したQRは、実際のカメラで読み取れること。

## UIモック(参考資料)
- `docs/mock/code/` にGoogle AI Studioで作ったUIモック(React + Tailwind)がある。**見た目・色・余白・文言・画面遷移・アニメーションの参考にのみ使う。**
- モックはWeb製。コードをそのまま移植せず、Flutter(Riverpod)で再実装する。モックの依存パッケージ(`@google/genai` など)は無視する。
- **仕様書とモックが食い違う場合は、仕様書を優先する。** 食い違いに気づいたら、実装を始める前にユーザーに報告する。
- モック内の状態保持や判定ロジック(タスク完了判定、SUCCESS判定など)は参考にしない。重要状態の判定はサーバー側で行う。
- ボトムナビはガラス風(半透明・ぼかし)。Flutterでは `BackdropFilter` + `ImageFilter.blur` で表現する。

## 未確定事項(勝手に仕様化しない)
次は未決定または未選定。実装が必要になったら、勝手に決めずにユーザーに確認すること。
- Edge Function内のトランザクション実装方式(推奨案: PL/pgSQLのストアドファンクション+RPC1回呼び出し)
- 監視・エラートラッキングの選定
- 環境分離(dev/staging/production)
- 重要APIのレート制限
- 認証トークンのリフレッシュ設計
- サーバー時刻オフセットの取得方法
- QRのセルをタスクへ割り当てる具体的な方式
- 液体チャージの描画のFlutter実装方法

## 進め方
- 小さな単位で実装し、変更内容を説明する。
- 仕様書にない挙動を追加・補完しない。必要な場合は先に質問する。
- 破壊的な操作(ファイル削除、`git push --force` 等)は実行前に確認する。
- 仕様変更が発生したら、変更前・変更後・影響範囲を `docs/spec.md` の変更記録に追記する。