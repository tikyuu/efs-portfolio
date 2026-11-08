# EFSを理解するポートフォリオ

開始日：2026年11月7日。現在地：Terraformのバージョン・Provider設定、VPCと4つのサブネット、Internet Gatewayとパブリック用ルート、SGと許可ルール、EFS本体と2つのマウントターゲット、4種類のVPCエンドポイント、ECRリポジトリ、ロググループ、ECSクラスター、タスク実行ロールと共通アプリ用のタスク定義を定義済み。FastAPIで登録・一覧・ダウンロード・画面配信・ヘルスチェックを実装済み。Dockerfileをマルチステージ構成にし、React成果物をPython 3.14のイメージへ組み込み済み。ローカルのビルド成功と画面表示を本人の共有ログ・画面で確認。AWS未構築。

## 現在の構成方針（2026年11月7日更新）

フロント画面の配信・登録・閲覧を1つのアプリにまとめる。1クラスター・1サービス・同じイメージとタスク定義から起動する2タスクを基本とし、1a・1cに分散配置する方針。各タスクで同じEFSを読み書きする。複数タスク間のファイル共有と、タスク入れ替え後もファイルが残ることを検証する。

当初の「登録・閲覧の2サービス」は、別アプリ間のEFS共有と権限差を学ぶ目的だった。今回の題材では両機能を独立して運用する要件がないため、本人と相談し、アプリを統合して理解しやすい構成を選択した。Reactのビルド成果物は共通のPythonアプリと同じイメージに含め、FastAPIで配信する構成。フロント専用サービスやS3・CloudFrontは現時点では追加しない。

**共通タスク定義・ロググループ・ターゲットグループを各1種類に統合済み。** 共通アプリはEFSを読み書きできるマウント設定とする。共通ターゲットグループは `tg-efs-app` とする。ECSサービス本体は定義済み。Python側の機能は実装済み。Reactの登録・一覧・ダウンロードAPI接続を実装済み。画面用ファイルのイメージへの組み込みとローカルでの画面表示を確認済み。

ALBは共通のターゲットグループ1つへ転送する構成に変更する。`/upload/` と `/files/` はアプリ内のAPIとして区別し、ALBで役割別に転送先を分けるルールは不要になる。証明書の申請・所有確認用CNAME・発行完了待ちは定義済み。HTTPSリスナーは定義済み。ECSサービスも定義済みで、Python側の登録/閲覧処理は実装済みで、登録・一覧・ダウンロードの画面接続は実装済み。以下では、定義済みのコードと今後の統合作業を区別する。


## 目的と進め方

AWSでEFSを構築し、仕組みと設計理由を説明できるようになることを目指す。AIによる実装支援を活用しながら、目的・構成・動作・検証結果の理解を優先し、要求→構成→実装→検証へ進める。

主な学習対象はEFS。2026年11月7日、接続元を単体のEC2からECSタスクへ変更する方針を選択。実行基盤はFargate（Linux）を選択。

## 構成図

[EFS共有ファイル基盤の構成図（draw.io）](docs/architecture/efs-architecture.drawio)。AWS未構築の構成案です。ALBから共通ターゲットグループを通じて1サービスの2タスクへ転送し、同じEFSを読み書きする新方針を示します。タスクは同じアプリで、画面配信・登録・閲覧を担当します。共通タスク定義・ログ・ターゲットグループの統合は実施済みで、ECSサービスとPython側の処理は実装済みで、画面接続とコンテナへの画面組み込みは実装済みです。ローカルで画面表示を確認し、AWSでの検証は未実施です。

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

## 題材

**同じアプリの2タスクで使う共有ファイル基盤を、架空データで構築・検証する。**

資料の登録・一覧・ダウンロードと、Reactの画面配信を1つのアプリにまとめる。同じアプリを2タスク起動し、どちらで登録しても共通のEFSから読み出せることを確認する。Python側は登録・一覧・ダウンロードと画面ファイルを返す処理まで実装済み。Reactは登録・一覧・ダウンロードAPIへの接続を実装済み。ローカルでは画面表示と保存先未接続のエラー表示を確認。保存・取得の成功とAWSでの動作は未確認。

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

FargateのEFS対応はLinuxプラットフォーム1.4.0以降。1ページ目はEFSへのデータ経路、2ページ目はイメージ取得・ログ送信、3ページ目はSGと許可ルールの関係を示す。タスク定義やECSクラスター等の管理上の関係は省略している。同じアプリを2AZで動かす方針で、配置と補充を管理するECSサービスを定義済み。

## イメージ取得・ログ送信の構成案

構成図は1ファイル・3ページ構成。01はALBから共通アプリの2タスクとEFSへの経路、02はECRからのイメージ取得とCloudWatch Logsへの送信、03はEFS・VPC endpoint向けのSG通信を示す。ALB関連の経路は同シートでは省略している。02は同じ2タスクの通信をまとめた論理図で、タスクやVPCを追加する意味ではない。ログ送信先は図・コードともに `/ecs/efs/app` へ統合済み。

- ECR用のInterface endpointは `ecr.api` と `ecr.dkr` の2種類。Private DNSを有効にし、各エンドポイントのENIは1aのサブネットだけに配置する。1cのタスクも1aの入口を利用する。
- ECRのイメージレイヤーはS3から取得するため、S3 Gateway endpointを両サブネットが暗黙に利用するVPCのメインルートテーブルへ関連付ける。将来個別のルートテーブルを作る場合は関連付け先を変更する。図のS3はECR管理の保存先で、アプリ用バケットの追加ではない。
- `awslogs`による送信には `logs` Interface endpointを使用し、1aのサブネットだけに配置する。
- Interface endpointの図形は論理リソースを表す。図とTerraformの配置先はともに1aのみ。S3 Gateway endpointはサブネット内のENIではなく、ルートテーブル経由で利用する。
- endpointのSecurity Groupは関連付け済み。エンドポイントポリシーの絞り込み、イメージの事前push、利用費用の確認はAWS構築前に行う。今回の通信にはNAT Gatewayを使わない案で、任意のインターネット接続を提供する構成ではない。

公式情報：[ECRのVPCエンドポイント](https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html)（2026年11月7日確認）。`infra/endpoints.tf` にInterface 3つとS3 Gateway 1つを定義済み。Interfaceは既存のendpoint SGを利用し、1a障害時には両AZのタスクのイメージ取得・ログ送信に影響する。エンドポイントポリシーの絞り込みは未実施で、現時点は既定のポリシーを使用する。サービスへのアクセスには別途IAM権限が必要。AWSへのplan・applyと通信確認は未実施。

## DNSの定義

`infra/dns.tf` に `tikyuu.click` のパブリックホストゾーンと、`efs.tikyuu.click` をALBに向けるAレコード（エイリアス）を定義した。ALBのIPを固定値で書かず、`aws_lb.efs.dns_name` と `aws_lb.efs.zone_id` を参照する。`evaluate_target_health = true` を指定しているが、今回の単一レコードのシンプルルーティングではDNS回答による正常系への切り替えは行わない。

Terraformの整形・定義検証は成功。AWSへの適用は未実施。ホストゾーン作成だけではドメイン登録側のネームサーバーは切り替わらないため、実際のDNS委任は既存設定・影響・費用を確認してから別途行う。証明書・所有確認用レコード・発行完了待ちの定義は追加済み。

## 証明書の定義

`infra/certificate.tf` に東京リージョンの `efs.tikyuu.click` 用ACM証明書をDNS検証で申請する定義を追加。ACMが返す所有確認用の名前・種類・値を参照し、Route 53へCNAMEを登録する。今回は1ドメインだけなので `tolist(...)[0]` でその1件を参照する。`aws_acm_certificate_validation` は証明書の発行完了を待つための定義。

Terraformの整形・定義検証は成功。AWSへの申請・DNS登録・証明書発行は未実施。初回はドメイン登録側のネームサーバーを新しいホストゾーンに合わせる作業が必要で、単にapplyして待つだけでは所有確認は完了しない。AWS適用時には既存DNS・影響・費用を確認し、DNSの初期準備と発行待ちを進める順番を決める。HTTPSリスナーは発行完了待ちの証明書を参照する定義を追加済み。

## ALB本体

`infra/alb.tf` にインターネット向けの `alb-efs` を定義。IPv4、Public subnetの1a・1c、ALB用SGを指定し、IGW接続後に作成する。共通ターゲットグループ `tg-efs-app` を1つ定義。HTTP・8000、種類 `ip`、ヘルスチェック `/health`（200）を指定する。ECSサービスにこのグループを関連付け、適用後のタスク登録をECSに管理させる。HTTPSリスナーは443番で受け付け、共通ターゲットグループへ転送する。証明書は `aws_acm_certificate_validation.efs.certificate_arn` を参照し、発行完了後に作成する。TLSポリシーは `ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09` を使用する。Terraformの整形・定義検証は確認済みで、AWSへの適用は未実施。

## ECSクラスターとアプリの土台

- `infra/ecs.tf`：クラスター `ecs-efs-cluster` と共通のタスク定義 `ecs-efs-app-task` を定義。コンテナ名は `efs-app`。Fargate、0.25 vCPU・512 MiB、awsvpc、ポート8000、イメージ `ecr-efs:v1` を指定。ログは `/ecs/efs/app` に集約する。同じEFSを `/mnt/shared` に暗号化通信でマウントし、`readOnly = false` とする。Python側の画面配信・登録・一覧・ダウンロードは実装済み。Reactの登録・一覧・ダウンロード接続は実装済み。画面用ファイルをコンテナへ組み込み、ローカルで画面表示を確認済み。
- `infra/ecs.tf`：サービス `ecs-efs-app-service` を定義。共通タスク定義をFargateのLinuxプラットフォーム1.4.0で2タスク維持し、1a・1cのPrivate subnetとタスク用SGを指定。Public IPは付与しない。`tg-efs-app` にコンテナ `efs-app` の8000番を登録する。AZ間の再調整を有効にし、起動後60秒のヘルスチェック猶予を設定。HTTPSリスナー、マウントターゲット、実行ロールのポリシー、VPC endpointの作成後にサービスを作る。配置結果・起動・補充・通信はAWSで未確認。イメージ `v1` の事前pushとDNS委任・証明書発行が適用時の前提。
- `infra/iam.tf`：実行ロール `iam-efs-task-execution-role` を定義し、ECSタスクへの信頼設定とAWS管理の `AmazonECSTaskExecutionRolePolicy` を関連付ける。ECR取得とログ送信を許可するポリシーで、アプリ用のタスクロールとは別。

タスク定義のTerraform検証は成功。AWSへのplan・apply、イメージの事前push、タスク起動は未実施。`v1` のイメージ登録が必要で、将来ビルドするイメージのCPUアーキテクチャもタスクと合わせる。
- `app/main.py`：FastAPIで登録・一覧・ダウンロード・画面配信・ヘルスチェックを実装。処理の詳細は次節を参照。
- `app/requirements.txt`：FastAPI・Uvicorn・ファイル受信用のpython-multipartのバージョンを固定。`app/Dockerfile` はPython 3.14の環境へ依存ライブラリとコードをコピーし、Uvicornをポート8000で起動する。Node.js 24の段階でReactをビルドし、成果物だけをPythonの段階の `/app/static/` へコピーする。リポジトリ直下の `.dockerignore` で必要なファイルだけをビルド対象にし、PC側のnode_modules・dist・環境設定ファイル等を除外する。

## Pythonが担当する処理（2026年11月8日）

| リクエスト | Pythonが行うこと |
|---|---|
| `POST /upload/` | 受け取ったファイルを `/mnt/shared` に保存し、名前とバイト数を返す |
| `GET /files/` | 保存先のファイル名とバイト数を一覧で返す |
| `GET /files/{filename}` | 指定ファイルの中身をダウンロード用に返す |
| `GET /`・`GET /assets/...` | 配置済みのHTML・JavaScript・CSSをブラウザへ返す |
| `GET /health` | Pythonアプリが応答できることを返す。EFS接続の検査ではない |

EFSのマウントはタスク定義の役割。Pythonはマウント済みの `/mnt/shared` を通常のフォルダとして読み書きする。AWS APIでEFSを作成・操作する処理ではない。

1ファイルは10 MiBまで。同名ファイルは上書きせず拒否する。不正な名前、保存先の外へのアクセス、シンボリックリンクの取得を拒否する。保存途中の一時ファイルは一覧から除き、同時登録でも既存ファイルを上書きしない。フォルダ階層、削除、帳票の集計・生成、利用者認証は今回実装していない。

Reactの登録・一覧・ダウンロードAPI接続は実装済み。サンプル表示を廃止し、保存先直下の一覧を取得する。画面用ファイルはDockerのビルド時に `/app/static/` へ配置する。ソース側の `app/static/` は作成しない。Docker経由で起動すると `/` から画面を配信できるが、画面用ファイルがない状態でPythonだけを直接起動すると503を返す。保存先がない場合も503を返し、代わりのフォルダは自動作成しない。フォルダの存在確認だけではEFSのマウント成功を証明できないため、AWSで別途確認する。

一時フォルダを保存先とした10件のテストで、登録・一覧・取得、同名競合、容量制限、失敗時の片付け、保存先外へのアクセス拒否、画面配信を確認。AWS・EFS実環境での動作検証ではない。

テストはPython 3.14の仮想環境で `pip install -r app/requirements-dev.txt`、続いてリポジトリのルートから `python -m unittest discover -s app/tests -v` を実行する。テスト依存はコンテナの依存とは分ける。

## Reactの操作画面

`frontend/` にReactとViteで登録・一覧・ダウンロードの1画面を作成。生成りの背景、深緑、細い線と余白を使う。登録ボタンから同じサイトの `POST /upload/` へファイルを送信する処理を実装済み。AWSでの通信確認は未実施。

- ファイル選択・選び直しを実装。架空サンプルの一覧とダウンロードを削除。
- ファイル選択後に登録でき、送信中は再登録・選び直しを止める。成功時はファイル名、失敗時はエラーを表示する。10 MiB超は送信前にも拒否する。
- 画面を開いたとき・更新ボタンを押したとき・登録成功後に `GET /files/` で一覧を取得する。ファイル名と容量を表示し、保存先直下だけを対象とする。階層表示とページ分割は未実装。
- 読み込み中・空の一覧・取得失敗を表示する。更新失敗時は前回取得した一覧を残し、その旨を表示する。登録成功後の一覧取得に失敗しても、登録自体の成功とは分けて表示する。
- ダウンロードボタンから `GET /files/{filename}` を呼び、受け取ったファイルを元の名前で保存する。日本語・空白・記号を含む名前はURL用に変換して送る。取得中は重複操作を防ぎ、失敗時はエラーを表示する。ローカルの画面表示と、保存先未接続時のAPIエラー表示を確認済み。登録・取得の成功とAWSでの動作は未確認。
- 狭い画面では縦並びに切り替えるCSSを実装。ブラウザでの表示確認はデスクトップで実施。

Node.js 24で、リポジトリのルートから起動する。

```bash
cd frontend
npm ci --ignore-scripts
npm run dev
```

表示先は `http://127.0.0.1:5173/`。`npm run build` でビルドできることを確認済み。成果物 `frontend/dist/` はGit対象外。CIにもビルド確認を追加した。コンテナへの画面組み込みは実装済み。Vite単体のプレビューにはPython APIがないため、登録・一覧・ダウンロードの実動作には同じサイトからPythonへ届く環境が必要。

主なファイル：`src/App.jsx` が画面・操作、`src/styles.css` が見た目、`package.json` が依存関係と起動コマンド、`package-lock.json` が実際の依存バージョンを管理する。

参考：[Reactの構築手順](https://react.dev/learn/build-a-react-app-from-scratch)、[Viteのガイド](https://vite.dev/guide/)（2026年11月7日確認）。

## ローカルのコンテナ起動

このリポジトリのルート（`EFS/`）で実行する。コピー元の基準は `.`、Dockerfileの場所は `app/Dockerfile`。ECRへのpushやAWSへのデプロイは行わない。

```bash
docker build -f app/Dockerfile -t ecr-efs:local .
docker run --rm -p 127.0.0.1:8000:8000 ecr-efs:local
```

別のターミナルから `curl http://127.0.0.1:8000/health` を実行すると `{"status":"ok"}` が返る。停止は起動したターミナルでCtrl+C。この起動方法ではEFSをマウントしていないため、ファイルAPIは503を返す。`http://127.0.0.1:8000/` で画面を表示できる。画面は自動で一覧を取得するため、保存先未接続のエラーを表示する。

確認日：2026年11月8日。本人が共有したログでDockerビルドの成功、画面でPythonからのReact配信と保存先未接続時のエラー表示を確認。EFSを接続した検証ではない。ローカルのPython仮想環境はDocker内のライブラリ環境とは別。

## イメージとログの保存先

- `infra/ecr.tf`：非公開ECRリポジトリ `ecr-efs` を定義。タグは `IMMUTABLE` とし、既存タグへの上書きを禁止する。ローカル用イメージのビルドは確認済み。ECS向けCPUアーキテクチャでのビルド確認、ECRへのpushと、自動削除の保持ルールは未実施。
- `infra/logs.tf`：共通アプリの `/ecs/efs/app` を1つ定義し、保持期間は30日。共通タスク定義に送信先を設定済み。2タスク起動時は同じロググループ内の別ストリームに出力される。実環境での送信確認は未実施。

Terraformのfmt・validateは確認済み。AWSへの作成・変更は未実施。

## GitHub ActionsからECRへ送信するための権限

`infra/github_actions.tf` にGitHubのOIDCプロバイダーとロール `iam-efs-github-actions-role` を定義。AWS向けの身元情報であることと、今回のリポジトリのmainであることを完全一致で確認する。所有者・リポジトリのIDを含む `sub` の形式はGitHub APIで確認済み。ECSのタスク実行ロールとは別のロールを使う。

権限はECRの認証トークン取得と、`ecr-efs` へのイメージの確認・送信に限定する。認証トークン取得はリポジトリ単位で制限できないため `Resource = "*"`、イメージ操作は `aws_ecr_repository.efs.arn` を指定する。ECS更新・リポジトリ削除の権限は付与しない。

Terraformのfmt・validateは成功。AWSへの作成・変更、OIDC認証の実行、ECRへのpushは未実施。手動実行するGitHub Actionsワークフローは次の工程。AWS適用前に、同じGitHub OIDCプロバイダーがアカウントに既存か確認し、既存なら重複作成せず管理方法を決める。

## EFS本体とマウントターゲット

`infra/efs.tf` に保存データの暗号化を有効にしたRegional EFSを1つ定義。`private_1a`・`private_1c` の各サブネットに同じEFSへのマウントターゲットを1つずつ配置し、両方に `aws_security_group.mount` を関連付ける。

Terraformのfmt・validateは確認済み。AWSへのplan・applyと実環境での通信確認は未実施。Fargateの共通タスク定義にEFSボリュームとマウント先を指定し、通信の暗号化を有効化済み。EFS内の `/` をコンテナ内の `/mnt/shared` に対応させる。IAM認証・ファイル権限・バックアップ等は今後の工程。共通タスクのマウントは読み書きを許可する設定で、EFS側のIAMによる権限制限はまだ行っていない。

## セキュリティグループ

`infra/security_groups.tf` にALB・タスク・マウントターゲット・endpoint用のSG本体4つと許可ルールを定義。タスク、EFSマウントターゲット、Interface endpointへの関連付けは、それぞれのリソースを作成するときに行う。

以下のSG名はNameタグ。AWSのSG本体名は`sg-`で始められないため、`efs-alb`・`efs-task`・`efs-mount`・`efs-endpoint`とする。

| SG | 関連付け先（今後作成） | インバウンド | アウトバウンド |
|---|---|---|---|
| `sg-efs-alb` | ALB | 指定した接続元CIDRからTCP 443 | task SGへTCP 8000 |
| `sg-efs-task` | Fargateタスク | alb SGからTCP 8000 | mount SGへTCP 2049、endpoint SGへTCP 443、東京のS3プレフィックスリストへTCP 443 |
| `sg-efs-mount` | EFSマウントターゲット | task SGからTCP 2049 | 新規通信の許可なし |
| `sg-efs-endpoint` | ECR API・DKR、LogsのInterface endpoint | task SGからTCP 443 | 新規通信の許可なし |

SGはステートフルなので、許可した通信への応答用ルールは不要。タスクのTCP 8000はALBのSGから受信を許可する。ファイル共有のためのタスク間通信は許可しない。SGは通信を制御するもので、ファイルの読み書き権限は後続のIAM・POSIX権限等で設計する。

利用者の接続元は `infra/variables.tf` の `alb_allowed_cidr` にIPv4 CIDRで指定する（例：検証用PCのグローバルIP/32）。既定値はなく、plan/apply時に指定が必要。実際のIPを公開リポジトリへコミットしない。ALB本体は定義済み。HTTPS証明書の申請・DNS検証・発行完了待ちは定義済み。HTTPSリスナーも定義済みだが、AWSへの適用・証明書発行・通信確認は未実施。

S3 Gateway endpointにSGは付けない。`data.aws_prefix_list.s3` はAWS管理の既存の宛先一覧を参照し、S3バケットを作成する定義ではない。実際の値の取得はplan/apply時にAWSへの照会が必要。SGの定義だけでは通信経路やサービスへのアクセス権は完成せず、エンドポイントポリシーやEFSのIAM認証等は今後の工程。

## セキュリティ検査

[![Security checks](https://github.com/tikyuu/efs-portfolio/actions/workflows/security.yml/badge.svg)](https://github.com/tikyuu/efs-portfolio/actions/workflows/security.yml)

[検査の内容と制約](SECURITY.md)を参照してください。PRで秘密情報・依存関係を検査し、IaCの指摘も報告します。検査結果と対応履歴を確認しながら保守します。
