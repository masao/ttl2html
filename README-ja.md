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

より詳細な説明マニュアルは https://ttl2html-doc.readthedocs.io/ja/ をご覧ください。

## ニュース

### 2024-12-22

:trophy: [LODチャレンジ2024](https://2024.lodc.jp/)において **「技術賞」** を受賞しました。

（関連情報）
* Linked Open Data チャレンジ 2024 実行委員会. [【プレスリリース】Linked Open Data チャレンジ Japan 2024 受賞作品発表](https://2024.lodc.jp/awardPressRelease2024.html). 2024-11-27.
* Linked Open Data チャレンジ 2024 実行委員会. [【開催報告】LODチャレンジ2024 授賞式シンポジウム](https://2024.lodc.jp/awardSymposium2024Report.html). 2025-01-11.
* 江草由佳. [「LODチャレンジ2024」で「技術賞」を受賞しました](https://www.nier.go.jp/03_laboratory/pdf/222.pdf#page=10). NIER NEWS. 2025, No.222, p.10.

## 関連ツール

SHACLに基づくデータセットスキーマ記述を簡便に行うためのツール **`xlsx2shape`** も同梱しています。詳細は [README-xlsx2shape-ja.md](README-xlsx2shape-ja.md) をご覧ください。

本ツールの開発にあたっては教科書LODデータセット[JP-TEXTBOOK:2017]における経験をもとにしています。

## 参照文献

* [TBL:2006] Tim-Berner Lee (2006). "Linked Data". https://www.w3.org/DesignIssues/LinkedData.html
* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
