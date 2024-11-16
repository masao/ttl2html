# ttl2html  [![Ruby test](https://github.com/masao/ttl2html/actions/workflows/ruby.yml/badge.svg)](https://github.com/masao/ttl2html/actions/workflows/ruby.yml) [![Maintainability](https://api.codeclimate.com/v1/badges/6897bef51f3280ae64e5/maintainability)](https://codeclimate.com/github/masao/ttl2html/maintainability)

<div align="right">日本語: https://github.com/masao/ttl2html/blob/master/README-ja.md</div>

## 📘 Documentation

Fnid a detailed documentation at https://ttl2html-doc.readthedocs.io/.

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
* ``top_additional_property``: For each set of resources expanded by ``top_class`` setting, specify a list of additional sub-hierarchies to be expanded. The properties that make up the sub-hierarchy are specified as a list.
* ``output_turtle``: Whether to output the RDF/Turtle format file corresponding to each resource URI, as ``true`` / ``false``. Default is ``true`` (i.e. output RDF/Turtle format files).
* ``template_dir``: Local template directory to find a template file. Default template files are available at [here](https://github.com/masao/ttl2html/tree/master/templates). To overwrite the contents of the original template, copy the original file to the directory specified here and rewrite it.
* ``locale``: Locale name for the output messages. Default: ``en`` (e.g. ``ja``, ``en``)
* ``about_file``: Specified filename is used for documenting schemas of the dataset. It requires SHACL documentation within the dataset. By default, the filename `about.html` is used.
* ``about_toc``: ``true`` / ``false`` to specify whether to output a table of contents in ``about.html``. The default is ``false``, which means no table of contents.
* ``admin_name``: Name of the dataset publisher displayed at the footer.
* ``copyright_year``: Copyright year statement displayed at the footer along with the ``admin_name`` parameter above.
* ``logo``: The logo image file to be displayed on the menu. Specify the file path or URL.
* ``custom_css``: Specify the code snippet of the CSS stylesheet (e.g. `` nav.navbar {background-color: pink} ``).
* ``css_file``: The path of the CSS stylesheet file to use locally.
* ``javascript_file``: The path of the JavaScript file to use locally.
* ``navbar_class``: Specifies the class setting for displaying the navigation bar at the top of the screen. If not specified, ``navbar-light`` is used. Use this if you want to specify a black background color as follows:
  ```yaml
  navbar_class: navbar-dark bg-dark
  ```
* ``additional_link``: Addional links displayed at the top menu. Specify an array of link items with two keys ``href`` and ``label``. e.g. ``[ { "href": "http://example.org", "label": "Link" } ]``
* ``breadcrumbs``: Configuration for creating a hierarchical breadcrumb list of multiple resources. Define a list of properties that are higher level resources or related resources of the resource. In the example below, the ``schema:hasPart`` and ``jp-cos:hasOfStudy`` properties, if present, respectively, are used to construct the navigation menu by considering resources linked from the current resource to be higher-level resources. The default display label on the breadcrumb list is "title", but if the ``label`` attribute is defined, the value of the property defined in the ``label`` attribute can be used as a breadcrumb link. Also, if the ``inverse`` attribute is present, then the resource being transitioned to as a property to the current resource is considered to be a higher level. It is also possible to specify a resource that spans a multi-level relationship with an empty node, etc. In that case, add a list to the ``property`` attribute and add a ``property`` attribute to its subordinate items as well. At the end of the example below, the ``schema:isPartOf`` property of the resource to which the ``schema:workExample`` property of the resource in question is specified can be used as a navigation resource.

  ```yaml
  - property: http://schema.org/hasPart
    inverse: true
    label: https://w3id.org/jp-cos/sectionNumber
  - property: https://w3id.org/jp-cos/courseOfStudy
  - property:
    - property: http://schema.org/workExample
    - property: http://schema.org/isPartOf
  ```
* ``shape_orders``: controls the order in which resource descriptions are output to about.html. The descriptions are output in the order of the resource shapes listed here. If not set, the default is alphabetical order of shape URIs. Set as a list, as in the following example:
  ```yaml
  shape_orders:
    - https://example.org/ItemShape
    - https://example.org/BookShape
  ```
* ``google_analytics``: Google tracking code for usage statistics by [Google Analytics](https://analytics.google.com).
  ```yaml
  google_analytics: G-XXXXXXXXXXXX
  ```
* ``google_custom_search_id``: Specify the search engine ID for setting up a site search form using [Google Custom Search](https://developers.google.com/custom-search). .
  ```yaml
  google_custom_search_id: 0123456789
* ``ogp``: Specify [OGP (Open Graph Protocol)](https://ogp.me) settings if you have additional logo settings for social networking sites, etc. You can specify ``ogp:image``, ``ogp:type``, etc.
  ```yaml
  ogp:
    image: https://example.org/logo2.png
    type: article
  ```

A more detailed instructions can be found at https://ttl2html-doc.readthedocs.io/.

## See also

There is another tool **``xlsx2shape``** to describe a dataset schema using SHACL. See [README-xlsx2shape.md](README-xlsx2shape.md) for details.

This tool is based on experiences from publishing Japanese Textbook LOD dataset [JP-TEXTBOOK:2017].

## References

* [TBL:2006] Tim-Berner Lee (2006). "Linked Data". https://www.w3.org/DesignIssues/LinkedData.html
* [JP-TEXTBOOK:2017] Y. Egusa & M. Takaku (2017). "Japanese Textbook LOD". https://w3id.org/jp-textbook/
