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

## 次の工程

`systemd/tomcat.service` をUbuntuへ転送・配置し、systemdによる起動・停止・状態確認を行う工程へ進む。OS起動時の自動起動と異常終了時の自動再起動は、その後に設定と動作を確認する。

このServletはTomcat 11のJakarta Servlet APIを使用する。実務環境のTomcat 8でそのまま動くことを示すものではない。接続先IP・認証情報・Tomcat配布物や生成したWARはリポジトリへ含めない。
