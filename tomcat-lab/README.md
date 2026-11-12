# Java・Tomcatの動作を理解する

Linux上でJava・Tomcat・WARがどう動くかを確認し、その後のコンテナ化・ECS移行の理解につなげる学習用アプリ。EFSの既存アプリとは別の題材として、同じリポジトリ内で管理する。顧客のコード・設定は使用しない。

## 現在地

- Mac側の `src/main/java/HelloServlet.java` にソースを配置。Mavenの標準ディレクトリ構成へ移動し、コードの内容は変更していない。GETリクエストに対して `Hello from Tomcat` を文字列で返す。
- 学習環境はUTM上のUbuntu、OpenJDK 25、Tomcat 11。本人の共有した出力と説明で、Tomcat付属ページの表示とJavaプロセスの起動を確認した。
- 本人の共有ログで、ソースのUbuntuへのscp転送と配置確認は実施済み。その後、MacでWARをビルドしてUbuntuへ転送する方針へ変更した。
- MacのJDK 25とMavenの導入、MavenがJava 25を使うことを本人の共有ログで確認。`pom.xml` にアプリの識別情報とWAR形式、Java 25向けのコンパイルとソースの文字コードUTF-8を指定した。
- Servlet API 6.1.0を `provided` で指定。コンパイル時に参照し、実行時はTomcatが提供するためWARには含めない。`finalName` を `hello` とし、成果物は `target/hello.war`。`target/` はGit対象外。
- 2026年11月11日、本人の共有ログでMacの `mvn package` が `BUILD SUCCESS` となり、`target/hello.war` が作成されたことを確認。WARのUbuntuへの転送、Tomcatへの配置・動作確認は未実施。
- 続報：本人からWAR転送後にブラウザで `Hello from Tomcat` が表示されたと共有があり、アプリの動作を確認。その後、共有された `shutdown.sh` とプロセス検索の出力で、手動起動したTomcatの停止を確認した。
- 2026年11月12日、`systemd/tomcat.service` を作成。`[Unit]` の説明と、`[Service]` に `Type=simple`・`User=ken`・`ExecStart` を記載し、`catalina.sh run` でTomcatをフォアグラウンド実行する起動方法を定義した。Ubuntuへのサービス登録・サービス起動・自動起動・自動再起動の設定は未実施。
- 続報：本人がサービス定義をUbuntuへ配置し、`daemon-reload`・`systemctl start tomcat` を実行。共有ログの `active (running)` と `Main PID: 5420 (java)`、本人のブラウザでの応答確認により、systemd経由の起動とアプリの応答を確認した。
- サービス定義に `[Install]`・`WantedBy=multi-user.target` を追加し、Ubuntuへ反映。本人の共有ログで、`systemctl enable tomcat` によるリンク作成と `is-enabled` の `enabled` を確認した。
- Ubuntu再起動後、本人が共有した状態確認の出力で `enabled`・`active (running)`・新しいJavaプロセス（PID 659）を確認。本人から再起動後にブラウザでも開けたとの共有があり、OS起動時のTomcatの自動起動とアプリ応答を確認できた。
- サービス定義に `Restart=on-failure`・`RestartSec=5` を追加し、Ubuntuへ反映。共有ログの `Restart=on-failure`・`RestartUSec=5s` で設定反映を確認。異常終了時に5秒待って再起動する設定で、`systemctl stop` による意図した停止は対象外。プロセスが動いたまま返すHTTPエラーも、この設定の検知対象ではない。
- 個人検証用TomcatのメインプロセスをSIGKILLで強制終了する手順を案内し、その後の共有ログでPIDが659から1137へ変わり、`active (running)` に戻ったことを確認。プロセスの自動再起動を検証できた。再起動後のブラウザ確認への返答は「ok」のみのため、アプリ応答までの復旧は明確な報告が得られるまで要確認とする。

## 次の工程

異常終了からの自動再起動後にアプリが応答したかを確認し、コンテナ化を説明と理解を区切りながら進める。

## コンテナ化の現在地

`Dockerfile` に `FROM tomcat:11.0.27-jre25-temurin-noble` と、WARを配置する `COPY` を記載。Docker Official ImageのTomcat 11.0.27・Java 25実行環境（Eclipse Temurin）・Ubuntu 24.04系を土台にする。2026年11月12日に公式配布ページでタグを確認した。`tomcat-lab` をビルドコンテキストとし、MacのMavenで作成済みの `target/hello.war` をイメージ内の `/usr/local/tomcat/webapps/hello.war` へコピーする。イメージのビルド・コンテナ起動・ECRへの送信・ECSへの配置は未実施。

起動コマンドは土台のイメージにある `catalina.sh run` を継承する。systemdのサービス定義はイメージへ含めない。ECSへ配置する際は、この起動設定でコンテナを動かし、タスク数の維持はECSサービスへ任せる方針。

このServletはTomcat 11のJakarta Servlet APIを使用する。実務環境のTomcat 8でそのまま動くことを示すものではない。接続先IP・認証情報・Tomcat配布物や生成したWARはリポジトリへ含めない。
