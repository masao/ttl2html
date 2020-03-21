# xlsx2shape

<div align="right">English: https://github.com/masao/ttl2html/blob/master/README-xlsx2shape.md</div>

## 概要

SHACLに基づくLinked Data用のアプリケーションプロファイル生成ツール。

本ツールはメタデータモデルの説明用のMS Excelファイルを入力として、SHACL形式によるデータ検証スキーマを出力します。
このツールを使うことにより、手元の任意のデータセットの記述を形式して自動的な検証を行うことができ、さらに ttl2html と組み合わせることにより、ウェブ上でメタデータモデルの説明ページを提供できるようになります。

## 機能

* SHACL表現スキーマに基づく、MS Excelファイルによるアプリケーションプロファイル記述
* MS ExcelファイルからSHACLスキーマファイルへの変換

## 使用法

まず、スプレッドシートに各ノードに対応するスキーマ内容をSHACL準拠の形式で記述してください。
スプレッドシートファイルの例は [example.xlsx](https://github.com/masao/ttl2html/blob/master/spec/example/example.xlsx?raw=true) をダウンロードして確認してください。
各シートが一つのノード種類に対応する内容として、各ノード種類が持つプロパティの型を指定できます。

スプレッドシートファイルができたら、以下のように、対象となるExcelファイルを引数にとってコマンドラインツール ``xslx2shape`` を実行してください。

```sh
xlsx2shape metadata.xlsx
```

スプレッドシートの内容を解析し、検証用SHACLデータ内容をRDF/Turtle形式で出力します。

## History

This tool is based on experiences from publishing Japanese Textbook LOD dataset [JP-TEXTBOOK:2017].

## References

* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
