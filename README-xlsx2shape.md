# xlsx2shape

<div align="right">日本語: https://github.com/masao/ttl2html/blob/master/README-xlsx2shape-ja.md</div>

## Description

Application profile generator for Linked Data using SHACL.

This tool accepts MS Excel format as a description of Metadata model (Aplication Profile) through SHACL validation schema.
It allows metadata publishers to describe and publish their own metadata model on the web.

## Features

* Describe an application profile in MS Excel file with SHACL shape expression schema.
* Convert a description in MS Excel into SHACL schema.

## Usage

At first, you need to describe your own schema into MS Excel file.
An example of Excel file is available at [example.xlsx](https://github.com/masao/ttl2html/blob/master/spec/example/example.xlsx?raw=true).
In the Excel file, each sheet represents each node type, and describes property structures and constraints on the node.

Once you get an Excel file, you can use the command line tool ``xlsx2shape`` with argument of spreadsheet file(s).

```sh
xlsx2shape metadata.xlsx
```

The command parses spreadsheets and generate a SHACL format for validation in RDF/Turtle.

## History

This tool is based on experiences from publishing Japanese Textbook LOD dataset [JP-TEXTBOOK:2017].

## References

* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
