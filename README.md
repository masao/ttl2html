# ttl2html  [![Build Status](https://travis-ci.com/masao/ttl2html.svg?branch=master)](https://travis-ci.com/masao/ttl2html) [![Maintainability](https://api.codeclimate.com/v1/badges/6897bef51f3280ae64e5/maintainability)](https://codeclimate.com/github/masao/ttl2html/maintainability)

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

### Options

You can setup several options on the command line and/or configuration file.

```yaml
output_dir: /var/www/html/dataset/
```

## Origin

This tool is based on experiences from publishing Japanese Textbook LOD dataset [JP-TEXTBOOK:2017].

## References

* [TBL:2006] Tim-Berner Lee (2006). "Linked Data". https://www.w3.org/DesignIssues/LinkedData.html
* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
