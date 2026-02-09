# Movie Store — サブスクリプション管理API

動画ストリーミングサービス向けのAppleアプリ内課金サブスクリプションを管理するRuby on Rails APIです。クライアントからの仮登録、Apple Server-to-Server Webhookによる有効化・更新・キャンセルまで、サブスクリプションのライフサイクル全体を処理します。

## アーキテクチャ概要

```
┌──────────┐   POST /api/subscriptions    ┌──────────────┐
│ クライアント│ ──────────────────────────► │              │
│   アプリ   │   (Apple購入後)             │  Rails API   │
└──────────┘                              │              │
                                          │  ┌────────┐  │     ┌─────────┐
┌──────────┐   POST /api/webhooks/apple   │  │ MySQL  │  │     │ Swagger │
│  Apple    │ ──────────────────────────► │  │   DB   │  │     │   UI    │
│ サーバー   │   (PURCHASE/RENEW/CANCEL)   │  └────────┘  │     │/api-docs│
└──────────┘                              └──────────────┘     └─────────┘
```

## サブスクリプションのライフサイクル

```
  クライアント購入
        │
        ▼
    ┌─────────┐   Apple PURCHASE    ┌────────┐   Apple RENEW    ┌────────┐
    │ pending  │ ─────────────────► │ active │ ───────────────► │ active │
    └─────────┘                     └────────┘                  └────────┘
    (視聴不可)                      (視聴可能)                  (視聴可能、新しい期間)
                                        │
                                        │ Apple CANCEL
                                        ▼
                                   ┌───────────┐
                                   │ cancelled │
                                   └───────────┘
                                   (expires_dateまで視聴可能)
```

- **pending** — クライアントが購入を報告済み、Apple Webhookの確認待ち。視聴不可。
- **active** — AppleがPURCHASEまたはRENEW Webhookで確認済み。視聴可能。
- **cancelled** — AppleがCANCEL Webhookを送信。`expires_date`まで視聴可能。

## APIエンドポイント

| メソッド | パス | 説明 |
|--------|------|-------------|
| `POST` | `/api/subscriptions` | クライアント側の購入後にサブスクリプションを仮登録する |
| `GET` | `/api/subscriptions/:user_id` | ユーザーの全サブスクリプションを取得する |
| `POST` | `/api/webhooks/apple` | Apple Server-to-Server通知を受信する |

対話型APIドキュメントは `/api-docs`（Swagger UI）で利用できます。

### POST /api/subscriptions

Appleアプリ内課金の完了後にクライアントアプリから呼び出されます。

```json
{
  "subscription": {
    "user_id": "user_123",
    "transaction_id": "txn_abc",
    "product_id": "com.samansa.subscription.monthly"
  }
}
```

新規サブスクリプションの場合は `201 Created`、transaction_idが既に存在する場合は `200 OK` を返します（冪等性）。

### POST /api/webhooks/apple

サブスクリプションのライフサイクルイベントに関するAppleサーバー通知を受信します。

```json
{
  "webhook": {
    "notification_uuid": "notif_001",
    "type": "PURCHASE",
    "transaction_id": "txn_abc",
    "product_id": "com.samansa.subscription.monthly",
    "amount": "3.9",
    "currency": "USD",
    "purchase_date": "2025-10-01T12:00:00Z",
    "expires_date": "2025-11-01T12:00:00Z"
  }
}
```

対応タイプ: `PURCHASE`（有効化）、`RENEW`（期間延長）、`CANCEL`（キャンセル処理）。

## データベース設計

### subscriptions

各ユーザーのサブスクリプション状態を追跡するメインテーブルです。

| カラム | 型 | 説明 |
|--------|------|-------------|
| `user_id` | string | ユーザー識別子 |
| `transaction_id` | string | AppleトランザクションID（一意） |
| `product_id` | string | サブスクリプションプランID |
| `status` | string | `pending`、`active`、または `cancelled` |
| `purchase_date` | datetime | 現在の期間の開始日（Webhookで設定） |
| `expires_date` | datetime | 現在の期間の終了日 / 次回更新日（Webhookで設定） |
| `amount` | decimal | 課金額 |
| `currency` | string | 通貨コード |

インデックス: `transaction_id`にユニーク、`(user_id, status)`に複合インデックス、`expires_date`にインデックス。

### subscription_events

受信した全てのApple Webhook通知の不変な監査ログです。

| カラム | 型 | 説明 |
|--------|------|-------------|
| `notification_uuid` | string | Apple通知ID（一意、冪等性のため） |
| `transaction_id` | string | サブスクリプションへの紐付け |
| `event_type` | string | `PURCHASE`、`RENEW`、または `CANCEL` |
| `product_id` | string | プランID |
| `amount` / `currency` | decimal/string | 課金詳細 |
| `purchase_date` / `expires_date` | datetime | 期間情報 |
| `processed_at` | datetime | イベントが処理された日時 |

## 設計方針

### 冪等性

- **クライアントエンドポイント**: 同じ `transaction_id` で `POST /api/subscriptions` を重複送信した場合、重複作成せずに既存のレコードを返します。DBのユニークインデックスで担保されています。
- **Webhookエンドポイント**: 重複する `notification_uuid` を検出し、安全に `200 OK`（`"already_processed"`）を返します。アプリケーションレベルのチェックとDBユニーク制約の両方で競合状態を防止します。

### 二段階有効化

サブスクリプションはクライアントから作成された時点では `pending`（視聴不可）として開始します。AppleがPURCHASE Webhookで確認した場合にのみ `active`（視聴可能）になります。これにより、Appleが支払いを確認する前にユーザーがアクセスすることを防止します。

### キャンセル時の猶予期間

キャンセルされたサブスクリプションは `expires_date` まで視聴可能のまま維持されます。`viewable?` メソッドはステータスと有効期限の両方をチェックするため、ユーザーは既に支払った期間のアクセスを保持できます。

### イベントソーシング（監査証跡）

全てのWebhook通知は `subscription_events` に不変のログとして記録されます。これにより以下が可能になります:
- 決済問題のデバッグ
- 収益分析（イベントごとの金額/通貨）
- サブスクリプション履歴の再構築

### トランザクションの整合性

Webhook処理は `ActiveRecord::Base.transaction` を使用し、イベントレコードとサブスクリプション状態の更新がアトミックであることを保証します — 両方が成功するか、どちらも実行されないかのいずれかです。

### スケーラビリティに関する考慮事項

- 頻繁にクエリされるカラム（`user_id`、`transaction_id`、`expires_date`）へのデータベースインデックス
- ユーザーのサブスクリプション検索を効率化する `(user_id, status)` の複合インデックス
- ステートレスなAPI設計 — ロードバランサーの背後で水平スケーリングが可能
- DBレベルのユニーク制約が分散ロックなしで競合状態を処理

## 技術スタック

- **Ruby on Rails** 8.1（APIモード）
- **MySQL** 8.0（Docker経由）
- **rswag** Swagger/OpenAPIドキュメント生成用

## はじめに

### 前提条件

- Ruby 3.4以上
- Docker & Docker Compose
- `libmysqlclient-dev`（`sudo apt-get install libmysqlclient-dev`）

### セットアップ

```bash
# MySQLを起動
cd samansa-backend
docker compose up -d

# 依存関係をインストール
bundle install

# データベースを作成・マイグレーション
bin/rails db:create db:migrate

# サーバーを起動
bin/rails server
```

### Swaggerドキュメントの生成

```bash
bundle exec rake rswag:specs:swaggerize
```

http://localhost:3000/api-docs にアクセスすると、対話型APIドキュメントを利用できます。

### テストの実行

```bash
bundle exec rspec
```
