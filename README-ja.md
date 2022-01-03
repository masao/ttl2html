# ttl2html [![Ruby test](https://github.com/masao/ttl2html/actions/workflows/ruby.yml/badge.svg)](https://github.com/masao/ttl2html/actions/workflows/ruby.yml) [![Maintainability](https://api.codeclimate.com/v1/badges/6897bef51f3280ae64e5/maintainability)](https://codeclimate.com/github/masao/ttl2html/maintainability)

<div align="right">English: https://github.com/masao/ttl2html/blob/master/README.md</div>

## 概要

Linked Dataのための静的サイト生成ツールです。

本ツールは、RDF/Turtle形式のファイルを入力として受けつけ、そのコンテンツに対応したHTMLファイル群を生成します。

「Linked Data原則」の提案[TBL:2006]では、事物はそれに対応するHTTP URIリソースを同定し、ウェブ上のURIとして解決できるようにすべきと推奨されています。本ツールは、Linked Dataデータセット用のウェブサイトを生成し、Web上で公開することを支援します。

## 機能一覧

まず始めに以下のコマンドによりインストールしてください: `gem install ttl2html`

* RDF/TurtleファイルからHTMLファイル群の生成
* プロパティラベルの変換（ラベル置換）
* タイトルプロパティの指定
* BootstrapベースのERBテンプレート

## 使用法

コマンドラインツール ``ttl2html`` が使えます。

まず始めに、実行時に使うディレクトリ上に``config.yml``というファイル名の設定ファイルが必要です。
このファイル内における設定項目では1つの設定項目 ``base_uri`` だけが必須で、他の設定項目は任意オプションとなっています。
以下のように、設定項目とその値を指定します:

```yaml
base_uri: https://www.example.org/
```

上記の設定ファイルを作成したら、以下のようにデータセットのRDF/Turtle形式のファイルを引数に指定して、コマンドを実行します:

```sh
ttl2html dataset.ttl
```

コマンドが正常に終了すれば、HTMLファイル群の生成が終わりです。

### コマンドラインオプション

```sh
ttl2html --config test.yml dataset.ttl
```

コマンド ``ttl2html`` では以下のオプション引数を指定できます:

* ``--config file``:  設定ファイルを``file``から読み込みます (Default: ```config.yml```).

### 設定ファイル

設定ファイルでは、以下のような設定項目を指定できます:

```yaml
base_uri: https://www.example.org/
output_dir: /var/www/html/dataset/
labels:
  http://www.w3.org/1999/02/22-rdf-syntax-ns#type: Class
  http://schema.org/name: Title
site_title: A sample dataset
title_property: https://www.example.org/title
top_class: http://schema.org/Book
```

* ``base_uri``: (必須) データセット用のベースURIを指定します。ベースURIは出力されるファイル群に対する接頭辞とみなし、先頭一致したURIリソースのみが生成対象となります。
* ``output_dir``: 出力ディレクトリを指定します。
* ``label``: 個別プロパティの出力ラベル名を指定します。
* ``site_title``: ウェブサイト全体のメインタイトルを指定します。
* ``title_property``: 指定したURIをタイトルとして指定します。指定されていない場合、もしくは指定したプロパティが存在しない場合は以下のプロパティの存在を走査して、その値をタイトルとみなします:
  - https://www.w3.org/TR/rdf-schema/#label
  - http://purl.org/dc/terms/title
  - http://purl.org/dc/elements/1.1/title
  - http://schema.org/name
  - http://www.w3.org/2004/02/skos/core#prefLabel
* ``top_class``: トップページに表示すべきレコード一覧に対応するクラスURIを指定する。デフォルトではトップページは生成されない。
* ``template_dir``: ローカルのテンプレートディレクトリ。未指定の場合はカレントディレクトリ内の ``templates/``ディレクトリを用いる。なお、テンプレートを上書きするには、[標準のテンプレートファイル](https://github.com/masao/ttl2html/tree/master/templates)をローカルのテンプレートディレクトリにコピーしてきて、内容を書き換えること。
* ``locale``: 出力メッセージの言語指定。デフォルトは ``en`` （例: ``ja``, ``en``）
* ``about_file``: 指定された名前のファイルにスキーマ説明を出力する。データセット内にSHACL記述が存在するときのみ有効。ファイル名 `about.html` に出力する。
* ``admin_name``: フッタ―に表示するデータ提供管理者の名称。
* ``copyright_year``: 上記 ``admin_name`` とセットにして出力する著作権表示年。
* ``logo``: メニューに表示するロゴ。ファイルパスまたはURLを指定する。
* ``custom_css``: CSSスタイルシートのコードを直接指定します（例: ``nav.navbar { background-color: pink }``）。
* ``css_file``: ローカルで用いるCSSスタイルシートファイルのパスを指定します。

## 関連情報

SHACLに基づくデータセットスキーマ記述を簡便に行うためのツール **`xlsx2shape`** も同梱しています。詳細は [README-xlsx2shape-ja.md](README-xlsx2shape-ja.md) をご覧ください。

本ツールの開発にあたっては教科書LODデータセット[JP-TEXTBOOK:2017]における経験をもとにしています。

## 参照文献

* [TBL:2006] Tim-Berner Lee (2006). "Linked Data". https://www.w3.org/DesignIssues/LinkedData.html
* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
