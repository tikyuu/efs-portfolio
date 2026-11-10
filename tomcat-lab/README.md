# Java・Tomcatの動作を理解する

Linux上でJava・Tomcat・WARがどう動くかを確認し、その後のコンテナ化・ECS移行の理解につなげる学習用アプリ。EFSの既存アプリとは別の題材として、同じリポジトリ内で管理する。顧客のコード・設定は使用しない。

## 現在地

- Mac側に `src/HelloServlet.java` を作成した。GETリクエストに対して `Hello from Tomcat` を文字列で返す。
- 学習環境はUTM上のUbuntu、OpenJDK 25、Tomcat 11。本人の共有した出力と説明で、Tomcat付属ページの表示とJavaプロセスの起動を確認した。
- 今回作成したソースのUbuntuへの転送、コンパイル、WAR作成、Tomcatへの配置・動作確認は未実施。

## 次の工程

MacからSSHを使う `scp` でUbuntuへソースをコピーする。その後、Ubuntuでコンパイルして `hello.war` にまとめ、Tomcatの `webapps` に配置する。アプリ内の `/` に対応するServletを、`/hello/` から呼び出す想定。

このServletはTomcat 11のJakarta Servlet APIを使用する。実務環境のTomcat 8でそのまま動くことを示すものではない。接続先IP・認証情報・Tomcat配布物や生成したWARはリポジトリへ含めない。
