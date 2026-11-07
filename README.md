# EFSを理解するポートフォリオ

開始日：2026年11月7日。現在地：Terraformのバージョン・Provider設定、VPCと4つのサブネット、Internet Gatewayとパブリック用ルート、SGと許可ルール、EFS本体と2つのマウントターゲット、4種類のVPCエンドポイント、ECRリポジトリ、ロググループ、ECSクラスター、タスク実行ロールと登録・閲覧側のタスク定義を定義済み。FastAPIのヘルスチェックAPIとPython 3.14ベースのDockerfileを作成済み。AWS未構築。

## 目的と進め方

AWSでEFSを構築し、仕組みと設計理由を説明できるようになることを目指す。AIによる実装支援を活用しながら、目的・構成・動作・検証結果の理解を優先し、要求→構成→実装→検証へ進める。

主な学習対象はEFS。2026年11月7日、接続元を単体のEC2からECSタスクへ変更する方針を選択。実行基盤はFargate（Linux）を選択。

## 構成図

[EFS共有ファイル基盤の構成図（draw.io）](docs/architecture/efs-architecture.drawio)。AWS未構築の構成案です。ALBから登録・閲覧の2つのECSサービスへ振り分け、同じEFSを利用する構成へ更新済みです。パブリックサブネットとIGWへの経路は定義済みで、ALB・ECSサービスは未実装です。

AWS公式アイコン（2026年7月31日版、11月7日確認）はファイル内に埋め込み済みで、このファイルだけで開いて編集できます。管理接続・権限・バックアップの詳細は今後設計します。

## ネットワークの命名・CIDR

整理日：2026年11月7日。本人が提示した `vpc-efs` を基準とする。VPC、Private・Public各2つのサブネット、IGWとパブリック用ルートはTerraformへ反映済み。AWS環境との重複は未確認。

命名は `種類-efs-用途-AZ` とし、AZは `1a`・`1c` のように数字を含める。用途・AZが不要な場合は省略する。AWS上の表示名は `Name` タグで付け、Terraform内の参照名はアンダースコアを使う。

| 対象 | Nameタグ | Terraform参照名 | CIDR | AZ |
|---|---|---|---|---|
| VPC | `vpc-efs` | `aws_vpc.efs` | `10.30.0.0/16` | — |
| Public subnet A | `subnet-efs-public-1a` | `aws_subnet.public_1a` | `10.30.0.0/24` | `ap-northeast-1a` |
| Public subnet C | `subnet-efs-public-1c` | `aws_subnet.public_1c` | `10.30.1.0/24` | `ap-northeast-1c` |
| Private subnet A | `subnet-efs-private-1a` | `aws_subnet.private_1a` | `10.30.10.0/24` | `ap-northeast-1a` |
| Private subnet C | `subnet-efs-private-1c` | `aws_subnet.private_1c` | `10.30.11.0/24` | `ap-northeast-1c` |
| Route table A | `rtb-efs-private-1a` | `aws_route_table.private_1a` | — | — |
| Route table C | `rtb-efs-private-1c` | `aws_route_table.private_1c` | — | — |

Public subnetは共通の `rtb-efs-public` に関連付け、`0.0.0.0/0` を `igw-efs` へ向ける定義を追加。Private subnetの個別ルートテーブルは未定義で、VPCのメインルートテーブルが暗黙に使われる。

既存ECSのローカル定義は `10.20.0.0/16` のため、別の `10.30.0.0/16` を提案。サブネットはVPCの範囲内で重複しない2つの `/24` とする。ECSタスクの配置先とマウントターゲットは同じAZのサブネットを使う案。Fargateはawsvpcネットワークモードを使用する。EFSファイルシステム自体にサブネットCIDRを割り当てる意味ではない。

VPCの `/16` は拡張余地を持たせた学習用の案で、今回の台数から必要になる大きさではない。実際の接続先ネットワークとの重複や利用可能なAZは構築前に確認する。イメージ取得・ログ送信はVPCエンドポイントを使う案とし、ALB用に2つのPublic subnetを追加した。CIDRは1aを `10.30.0.0/24`、1cを `10.30.1.0/24` で定義。全体図にはIGWと2つのPublic subnetのCIDRを示し、ALBとの関連付けを点線で表している。Public subnet、IGW、ルートと関連付けはTerraformに定義済み。NAT Gatewayは使わない。HTTPS・アクセス制限・通信設定の詳細は今後設計する。

## 推奨する題材（検討中）

**複数の業務アプリが使う共有ファイル基盤を、架空データで構築・検証する。**

当初の帳票作成・参照案から、資料の登録・閲覧APIを常駐するECSサービスで動かす題材へ整理した。登録側がEFSに保存した架空のファイルを、閲覧側が読み出す。構成図では1つのALBと2つのターゲットグループを使い、`/upload/*` を登録側、`/files/*` を閲覧側へ振り分ける案を示す。現在のアプリはヘルスチェックAPIのみで、登録・閲覧処理は未実装。各サービス1タスクの配置案であり、同じサービスの冗長化はしていない。

フォルダ構成・容量・利用アプリの対応を、共有範囲や権限を考える材料として扱う。公開情報と架空データによる個人検証であり、実在する顧客環境は再現しない。

## 全体の到達点と順序

1. **共有の仕組み**：2つのECSタスクから同じファイルを読み書きし、コンテナ内の一時的な保存先との違いを説明する。タスク定義のEFSボリュームとコンテナのマウント先の関係を学ぶ。EFS、マウント、マウントターゲット、VPC・AZの関係を学ぶ。
2. **アクセス制御**：共有領域とアプリ別領域を設け、Security Group、POSIX権限、Access Point、IAMの役割を順に検証する。想定した接続経路で許可・拒否を確認し、Access Pointを作るだけで他経路を防げると扱わない。
3. **障害調査・復旧**：個人検証環境で接続や権限の設定を一つずつ変更し、失敗の観察・原因切り分け・復旧を記録する。接続を失うこととファイルを失うことを区別する。
4. **性能・費用・保護**：小さいファイルを多数扱う場合と大きいファイルを扱う場合を測定。バックアップと別の復元先への復元を検証する。具体的な試験量・機能・費用は実行前に決める。
5. **説明できる成果物**：要求、構成図、IaC、試験手順、測定結果、失敗と復旧の記録、EFSを選ぶ条件・選ばない条件、後片付け手順を残す。

全体構想を小さく限定せず、最初の検証は「2つのタスクから同じファイルを使う」に区切る。バックアップ等を未実施の段階で完了としない。

## 比較と限界

- 当初はEC2でマウントを直接確認する案だったが、ECSからEFSを利用する学習へ変更。タスク定義・IAMロール・コンテナイメージの取得・ログ送信も必要になるため、EFS接続とタスク起動の失敗を分けて理解する。
- 題材がうまく合わない条件：アプリがファイルシステムとしての共有を必要とせず、ファイルの保存・取得だけで足りる場合。その場合はS3等も比較し、EFSを業務上の最適解と断定しない。
- 顧客NASからEFSへそのまま移せること、アプリ互換性、本番可用性をこの個人検証だけで証明したとは扱わない。

## これから決めること

- 題材への納得、架空の利用者・処理・共有要件。
- タスクの実行方法、イメージ取得・ログ送信の通信経路と確認方法。
- 利用時間、データ量、バックアップ保持期間、概算費用、後片付け対象。

AWSの作成・変更・削除、課金、公開・pushは、対象・影響・概算費用を説明してプロジェクト所有者の承認後に実行する。現時点で承認済みとは扱わない。

## 公式情報

確認日：2026年11月7日。機能の根拠であり、構成・料金の詳細は設計時に再確認する。

- [EFSの仕組み](https://docs.aws.amazon.com/efs/latest/ug/how-it-works.html)：複数クライアントの共有アクセス、NFSとマウントターゲット。
- [マウントターゲットの管理](https://docs.aws.amazon.com/efs/latest/ug/accessing-fs.html)：AZ・サブネット・接続点の関係。
- [EFS FAQ](https://aws.amazon.com/efs/faq/)：Access Point、接続元、ストレージ方式等。

## 変更の進め方

このディレクトリを独立したGitリポジトリとして管理する。機能単位のブランチで変更し、PRに目的・検証結果・未実施事項を残してmainへ取り込む。

## ECSへの変更方針（2026年11月7日）

VPCと2つのサブネットのTerraform定義は維持し、帳票作成・参照をECSタスクで実行する。EFSと各AZのマウントターゲットを共有する構想は維持する。単体EC2へのSession Manager接続を前提とした次工程は見直す。実行基盤はFargate（Linux）を選択し、構成図を更新。タスクの起動・確認方法を理解してから実装する。ECSでのEFS利用はAWS公式の[対応条件](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/efs-volumes.html)を確認する。

FargateのEFS対応はLinuxプラットフォーム1.4.0以降。1ページ目はEFSへのデータ経路、2ページ目はイメージ取得・ログ送信、3ページ目はSGと許可ルールの関係を示す。タスク定義やECSクラスター等の管理上の関係は省略している。作成側・参照側のAZ配置は検証用の案で、自動冗長化を意味しない。

## イメージ取得・ログ送信の構成案

構成図は1ファイル・3ページ構成。01はALBから登録・閲覧サービスとEFSへの経路、02はECRからのイメージ取得とCloudWatch Logsへの送信、03は現在定義済みのSGと許可ルールを示す。ALB用のSG・許可ルールは次工程。02は同じ2タスクの通信をまとめた論理図で、タスクやVPCを追加する意味ではない。

- ECR用のInterface endpointは `ecr.api` と `ecr.dkr` の2種類。Private DNSを有効にし、各エンドポイントのENIは1aのサブネットだけに配置する。1cのタスクも1aの入口を利用する。
- ECRのイメージレイヤーはS3から取得するため、S3 Gateway endpointを両サブネットが暗黙に利用するVPCのメインルートテーブルへ関連付ける。将来個別のルートテーブルを作る場合は関連付け先を変更する。図のS3はECR管理の保存先で、アプリ用バケットの追加ではない。
- `awslogs`による送信には `logs` Interface endpointを使用し、1aのサブネットだけに配置する。
- Interface endpointの図形は論理リソースを表す。図とTerraformの配置先はともに1aのみ。S3 Gateway endpointはサブネット内のENIではなく、ルートテーブル経由で利用する。
- endpointのSecurity Groupは関連付け済み。エンドポイントポリシーの絞り込み、イメージの事前push、利用費用の確認はAWS構築前に行う。今回の通信にはNAT Gatewayを使わない案で、任意のインターネット接続を提供する構成ではない。

公式情報：[ECRのVPCエンドポイント](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html)（2026年11月7日確認）。`infra/endpoints.tf` にInterface 3つとS3 Gateway 1つを定義済み。Interfaceは既存のendpoint SGを利用し、1a障害時には両AZのタスクのイメージ取得・ログ送信に影響する。エンドポイントポリシーの絞り込みは未実施で、現時点は既定のポリシーを使用する。サービスへのアクセスには別途IAM権限が必要。AWSへのplan・applyと通信確認は未実施。

## ECSクラスターとアプリの土台

- `infra/ecs.tf`：クラスター `ecs-efs-cluster` と、登録側 `ecs-efs-writer-task`・閲覧側 `ecs-efs-reader-task` のタスク定義を定義。Fargate、0.25 vCPU・512 MiB、awsvpc、コンテナのポート8000を指定。イメージは `ecr-efs:v1`、ログは登録側 `/ecs/efs/writer`・閲覧側 `/ecs/efs/reader` に分ける。現在は同じヘルスチェック用イメージで、登録・閲覧のアプリ処理は未実装。両タスクで同じEFSを `/mnt/shared` にマウントする定義を追加済み。登録側は `readOnly = false`、閲覧側は `readOnly = true`。ECSサービスは未実装。
- `infra/iam.tf`：実行ロール `iam-efs-task-execution-role` を定義し、ECSタスクへの信頼設定とAWS管理の `AmazonECSTaskExecutionRolePolicy` を関連付ける。ECR取得とログ送信を許可するポリシーで、アプリ用のタスクロールとは別。

タスク定義のTerraform検証は成功。AWSへのplan・apply、イメージの事前push、タスク起動は未実施。`v1` のイメージ登録が必要で、将来ビルドするイメージのCPUアーキテクチャもタスクと合わせる。
- `app/main.py`：FastAPIアプリの `GET /health` が `{"status": "ok"}` を返す。EFSへの接続を検査するAPIではない。
- `app/requirements.txt`：FastAPIとUvicornのバージョンを固定。`app/Dockerfile` はPython 3.14の環境へ依存ライブラリとコードをコピーし、Uvicornをポート8000で起動する。CSVの登録・閲覧処理は未実装。

## ローカルのコンテナ起動

リポジトリのルートで実行する。ビルド対象は `./app`。ECRへのpushやAWSへのデプロイは行わない。

```bash
docker build -t ecr-efs:local ./app
docker run --rm -p 127.0.0.1:8000:8000 ecr-efs:local
```

別のターミナルから `curl http://127.0.0.1:8000/health` を実行すると `{"status":"ok"}` が返る。停止は起動したターミナルでCtrl+C。現在はヘルスチェックのみで、EFSはマウントしていない。

## イメージとログの保存先

- `infra/ecr.tf`：非公開ECRリポジトリ `ecr-efs` を定義。タグは `IMMUTABLE` とし、既存タグへの上書きを禁止する。イメージのビルド・pushと、自動削除の保持ルールは未実施。
- `infra/logs.tf`：登録側 `/ecs/efs/writer` と閲覧側 `/ecs/efs/reader` の2つのロググループを定義。保持期間はいずれも30日。各タスク定義に対応する送信先を設定済み。実環境での送信確認は未実施。

Terraformのfmt・validateは確認済み。AWSへの作成・変更は未実施。

## EFS本体とマウントターゲット

`infra/efs.tf` に保存データの暗号化を有効にしたRegional EFSを1つ定義。`private_1a`・`private_1c` の各サブネットに同じEFSへのマウントターゲットを1つずつ配置し、両方に `aws_security_group.mount` を関連付ける。

Terraformのfmt・validateは確認済み。AWSへのplan・applyと実環境での通信確認は未実施。Fargateの両タスク定義にEFSボリュームとマウント先を指定し、通信の暗号化を有効化済み。EFS内の `/` をコンテナ内の `/mnt/shared` に対応させる。IAM認証・ファイル権限・バックアップ等は今後の工程。読み取り専用指定は閲覧コンテナのマウント設定であり、EFS側のIAMによる権限制限はまだ行っていない。

## セキュリティグループ

`infra/security_groups.tf` にSG本体3つと許可ルールを定義。タスク、EFSマウントターゲット、Interface endpointへの関連付けは、それぞれのリソースを作成するときに行う。

以下のSG名はNameタグ。AWSのSG本体名は`sg-`で始められないため、`efs-task`・`efs-mount`・`efs-endpoint`とする。

| SG | 関連付け先（今後作成） | インバウンド | アウトバウンド |
|---|---|---|---|
| `sg-efs-task` | Fargateタスク | なし | mount SGへTCP 2049、endpoint SGへTCP 443、東京のS3プレフィックスリストへTCP 443 |
| `sg-efs-mount` | EFSマウントターゲット | task SGからTCP 2049 | 新規通信の許可なし |
| `sg-efs-endpoint` | ECR API・DKR、LogsのInterface endpoint | task SGからTCP 443 | 新規通信の許可なし |

SGはステートフルなので、許可した通信への応答用ルールは不要。タスクに受信ルールを追加せず、ファイル共有のためのタスク間通信も許可しない。SGは通信を制御するもので、ファイルの読み書き権限は後続のIAM・POSIX権限等で設計する。

S3 Gateway endpointにSGは付けない。`data.aws_prefix_list.s3` はAWS管理の既存の宛先一覧を参照し、S3バケットを作成する定義ではない。実際の値の取得はplan/apply時にAWSへの照会が必要。SGの定義だけでは通信経路やサービスへのアクセス権は完成せず、エンドポイント・経路・IAM等は未実装。

## セキュリティ検査

[![Security checks](https://github.com/tikyuu/efs-portfolio/actions/workflows/security.yml/badge.svg)](https://github.com/tikyuu/efs-portfolio/actions/workflows/security.yml)

[検査の内容と制約](SECURITY.md)を参照してください。PRで秘密情報・依存関係を検査し、IaCの指摘も報告します。検査結果と対応履歴を確認しながら保守します。
