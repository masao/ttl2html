# ttl2html [![Ruby test](https://github.com/masao/ttl2html/actions/workflows/ruby.yml/badge.svg)](https://github.com/masao/ttl2html/actions/workflows/ruby.yml) [![Maintainability](https://api.codeclimate.com/v1/badges/6897bef51f3280ae64e5/maintainability)](https://codeclimate.com/github/masao/ttl2html/maintainability)

<div align="right">English: https://github.com/masao/ttl2html/blob/master/README.md</div>

## 📘 ドキュメント

詳細なドキュメントは以下をご覧ください： https://ttl2html-doc.readthedocs.io/ja/

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
* ``labels``: 個別プロパティの出力ラベル名を指定します。
* ``site_title``: ウェブサイト全体のメインタイトルを指定します。
* ``title_property``: 指定したURIをタイトルとして指定します。指定されていない場合、もしくは指定したプロパティが存在しない場合は以下のプロパティの存在を走査して、その値をタイトルとみなします:
  - https://www.w3.org/TR/rdf-schema/#label
  - http://purl.org/dc/terms/title
  - http://purl.org/dc/elements/1.1/title
  - http://schema.org/name
  - http://www.w3.org/2004/02/skos/core#prefLabel
* ``top_class``: トップページに表示すべきレコード一覧に対応するクラスURIを指定する。デフォルトではトップページは生成されない。
* ``top_additional_property``: ``top_class``設定で展開されるリソース群に対して、追加でサブ階層として展開されるべきリストを指定する。サブ階層を構成するプロパティをリストとして指定する。
* ``output_turtle``: 各リソースURIに対応するRDF/Turtle形式のファイルを出力するかどうかを ``true`` / ``false`` で指定します。デフォルトは ``true`` です（つまりRDF/Turtle形式を出力します）。
* ``template_dir``: ローカルのテンプレートディレクトリ。未指定の場合はカレントディレクトリ内の ``templates/``ディレクトリを用いる。なお、テンプレートを上書きするには、[標準のテンプレートファイル](https://github.com/masao/ttl2html/tree/master/templates)をローカルのテンプレートディレクトリにコピーしてきて、内容を書き換えること。
* ``locale``: 出力メッセージの言語指定。デフォルトは ``en`` （例: ``ja``, ``en``）
* ``about_file``: 指定された名前のファイルにスキーマ説明を出力する。データセット内にSHACL記述が存在するときのみ有効。ファイル名 `about.html` に出力する。
* ``about_toc``: ``about.html``内に目次を出力するかどうかを ``true`` / ``false`` で指定する。デフォルトでは ``false``、目次を出力しない。
* ``admin_name``: フッタ―に表示するデータ提供管理者の名称。
* ``copyright_year``: 上記 ``admin_name`` とセットにして出力する著作権表示年。
* ``logo``: メニューに表示するロゴ。ファイルパスまたはURLを指定する。
* ``custom_css``: CSSスタイルシートのコードを直接指定します（例: ``nav.navbar { background-color: pink }``）。
* ``css_file``: ローカルで用いるCSSスタイルシートファイルのパスを指定します。
* ``javascript_file``: ローカルで用いるJavaScriptファイルのパスを指定します。
* ``navbar_class``: 画面上部に配置するナビゲーションバーの表示用クラス設定を指定します。指定がなければ ``navbar-light`` が指定されたものとみなします。以下のように黒色系の背景色を指定したい場合に用います。
  ```yaml
  navbar_class: navbar-dark bg-dark
  ```
* ``additional_link``: メニューに置かれる追加的なリンク。``href``, ``label`` の2つのキーを持つ各リンク情報を配列として設定できる。例: ``[ { "href": "http://example.org", "label": "Link" } ]``
* ``breadcrumbs``: 複数のリソースを階層化したパンくずリストを作るための設定。当該リソースの上位階層リソースまたは関連リソースにあたるプロパティをリストとして定義します。下記の例では ``schema:hasPart`` プロパティ、``jp-cos:couseOfStudy``プロパティそれぞれの順でもし存在すれば、当該リソースの上位階層とみなしてナビゲーションメニューを構築します。また、パンくずリスト上の表示ラベルはデフォルトでは「タイトル」を用いますが、``label``属性が定義されていれば、当該``label``属性に定義されたプロパティの値をパンくずリンクとして用いることができます。また、`inverse`属性がある場合は、当該リソースへのプロパティとして遷移されたリソースを上位階層とみなします。また、空ノード等で多段階の関係をまたいだリソースを指定することもできます。その場合、``property``属性にリストを追加してその下位アイテムに同様に``property``属性を追加します。下記の末尾の例では、当該リソースの``schema:workExample``プロパティ指定先リソースのさらに``schema:isPartOf``プロパティ先のリソースをナビゲーションリソースとして用いることができます。
  ```yaml
  - property: http://schema.org/hasPart
    inverse: true
    label: https://w3id.org/jp-cos/sectionNumber
  - property: https://w3id.org/jp-cos/courseOfStudy
  - property:
    - property: http://schema.org/workExample
    - property: http://schema.org/isPartOf
  ```
* ``shape_orders``: about.htmlに出力されるリソース説明の順序を制御する。ここに一覧されたリソースシェイプの順に説明が出力される。設定されない場合、デフォルトではシェイプURIのアルファベット順に出力される。以下の例のようにリストとして設定する：
  ```yaml
  shape_orders:
    - https://example.org/ItemShape
    - https://example.org/BookShape
  ```
* ``google_analytics``: [Googleアナリティクス](https://analytics.google.com)による利用統計用の設定コードを指定します。
  ```yaml
  google_analytics: G-XXXXXXXXXX
  ```
* ``google_custom_search_id``: [Googleカスタム検索](https://developers.google.com/custom-search?hl=ja)を利用したサイト内検索フォームを設置するための検索エンジンIDを指定します。
  ```yaml
  google_custom_search_id: 0123456789
  ```
* ``ogp``: [OGP (Open Graph Protocol)](https://ogp.me)設定を指定します。SNS等で用いるための追加のロゴ設定などがあれば、こちらを指定してください。``ogp:image``, ``ogp:type``などの指定が可能です。
  ```yaml
  ogp:
    image: https://example.org/logo2.png
    type: article
  ```

より詳細な説明マニュアルは https://ttl2html-doc.readthedocs.io/ja/ をご覧ください。

## 関連情報

SHACLに基づくデータセットスキーマ記述を簡便に行うためのツール **`xlsx2shape`** も同梱しています。詳細は [README-xlsx2shape-ja.md](README-xlsx2shape-ja.md) をご覧ください。

本ツールの開発にあたっては教科書LODデータセット[JP-TEXTBOOK:2017]における経験をもとにしています。

## 参照文献

* [TBL:2006] Tim-Berner Lee (2006). "Linked Data". https://www.w3.org/DesignIssues/LinkedData.html
* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
