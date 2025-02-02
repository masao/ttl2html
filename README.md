# ttl2html  [![Ruby test](https://github.com/masao/ttl2html/actions/workflows/ruby.yml/badge.svg)](https://github.com/masao/ttl2html/actions/workflows/ruby.yml) [![Maintainability](https://api.codeclimate.com/v1/badges/6897bef51f3280ae64e5/maintainability)](https://codeclimate.com/github/masao/ttl2html/maintainability)

<div align="right">日本語: https://github.com/masao/ttl2html/blob/master/README-ja.md</div>

## 📘 Documentation

Find a detailed documentation at https://ttl2html-doc.readthedocs.io/.

## Description

Static site generator for Linked Data.

This tool accepts RDF/Turtle format as input to generate the corresponding HTML files.

The Linked Data Principle [TBL:2006] suggests that identifying things as HTTP URIs (resources) and resolving them on the Web is important. This tool helps to generate a website for a Linked Data dataset and publish it on the Web.

## Features

Install with `gem install ttl2html`

* RDF/Turtle to HTML files
* Mapping property labels
* Mapping title properties
* ERB templates based on Bootstrap
* SHACL to documentation for the dataset schema

## Usage

You can use a command line tool ``ttl2html``.
You need to create a configuration file named ``config.yml`` with a YAML format, as follows:
One required key for the configuration is ``base_uri``.

```yaml
base_uri: https://www.example.org/
```

With this configuration file, you can execute a command:

```sh
ttl2html dataset.ttl
```

The command parses a dataset file and generate a HTML files.

### Commandline options

```sh
ttl2html --config test.yml dataset.ttl
```

The command ``ttl2html`` accepts the following options:

* ``--config file``:  Read the configuration file from ``file`` (Default: ```config.yml```).

### Configuration file

You can setup several options on the configuration file, ``config.yml`` (default).

```yaml
base_uri: https://www.example.org/
output_dir: /var/www/html/dataset/
labels:
  http://www.w3.org/1999/02/22-rdf-syntax-ns#type: Class
  http://schema.org/name: Title
site_title: A sample dataset
title_property: http://example.org/title
top_class: http://schema.org/Book
```

* ``base_uri``: (Required) Base URI for the dataset. Base URI is considered as the prefix for the target resources, and only the matched URIs with the prefix are picked up for the generation.
* ``output_dir``: Output directory for the dataset.
* ``labels``: Mappings for the custom property labels.
* ``site_title``: Main title for the whole website.
* ``title_property``: Specified URI is regarded as a title property for the resource. In default, a title is matched with the following properties:
  - https://www.w3.org/TR/rdf-schema/#label
  - http://purl.org/dc/terms/title
  - http://purl.org/dc/elements/1.1/title
  - http://schema.org/name
  - http://www.w3.org/2004/02/skos/core#prefLabel
* ``top_class``: Specified URI is the class of the records listed in the top page. By default, this tool does not generate the top page.

A more detailed instructions can be found at https://ttl2html-doc.readthedocs.io/.

## News

### 2024-12-22

:trophy: We received the **Technology Award** at the [LOD Challenge Japan 2024](https://2024.lodc.jp/) 

* Linked Open Data Challenge Japan 2024 Organizing Committee. [[Press release] Linked Open Data Challenge Japan 2024 Winners Announced](https://2024.lodc.jp/awardPressRelease2024.html). 2024-11-27. (in Japanese)
* Linked Open Data Challenge Japan 2024 Organizing Committee. [[Event report] LOD Challenge Japan 2024 Award Ceremony Symposium](https://2024.lodc.jp/awardSymposium2024Report.html). 2025-01-11. (in Japanese)
* Yuka Egusa. [We received the "Technology Award" at the "LOD Challenge 2024"](https://www.nier.go.jp/03_laboratory/pdf/222.pdf#page=10). NIER NEWS. 2025, No.222, p.10. (in Japanese)

## Bundled tool

There is another tool **``xlsx2shape``** to describe a dataset schema using SHACL. See [README-xlsx2shape.md](README-xlsx2shape.md) for details.

This tool is based on experiences from publishing Japanese Textbook LOD dataset [JP-TEXTBOOK:2017].

## References

* [TBL:2006] Tim-Berner Lee (2006). "Linked Data". https://www.w3.org/DesignIssues/LinkedData.html
* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
