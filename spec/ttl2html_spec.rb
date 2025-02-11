RSpec.describe TTL2HTML::App do
  spec_base_dir = File.dirname(__FILE__)
  context "#new" do
    it "should construct a new instance" do
      ttl2html = TTL2HTML::App.new
      expect(ttl2html).not_to be_nil
    end
    it "should accept an argument" do
      ttl2html = TTL2HTML::App.new("config.yml")
      expect(ttl2html).not_to be_nil
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      expect(ttl2html).not_to be_nil
    end
  end
  context "#load_tutle" do
    it "should load files properly, with/without gz" do
      ttl2html = TTL2HTML::App.new
      data = ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      expect(data.size).to be > 0
      data = ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl.gz"))
      expect(data.size).to be > 0
    end
    it "should print accurate resource counts" do
      ttl2html = TTL2HTML::App.new
      expect {
        ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      }.to output(/9 triples. 4 subjects/).to_stderr
      expect {
        ttl2html.load_turtle(File.join(spec_base_dir, "example/example2.ttl"))
      }.to output(/9 triples. 4 subjects/).to_stderr
    end
  end
  context "#find_turtle" do
    include TTL2HTML
    it "should find a turtle file" do
      file = find_turtle(File.join(spec_base_dir, "example/example.ttl"))
      expect(file).to eq File.join(spec_base_dir, "example/example-20211023.ttl.gz")
    end
  end
  context "#each_data" do
    it "should output a progress bar to stderr" do
      ttl2html = TTL2HTML::App.new
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      expect {
        ttl2html.each_data{|e| e }
      }.to output(/each_data/).to_stderr
    end
  end
  context "#output_html_files" do
    before(:each) do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
    end
    after(:each) do
      @ttl2html.cleanup
      I18n.locale = I18n.default_locale
    end
    it "should have no errors in HTML structures" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      doc = Nokogiri::HTML5::Document.parse(open("/tmp/html/index.html").read, max_errors: -1)
      expect(doc.errors).to be_empty
      doc = Nokogiri::HTML5::Document.parse(open("/tmp/html/a/index.html").read, max_errors: -1)
      expect(doc.errors).to be_empty
    end
    it "shoud have no errors in HTML for versions info" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/versions.ttl"))
      @ttl2html.output_html_files
      [ "/tmp/html/index.html", "/tmp/html/about.html" ].each do |file|
        cont = open(file).read
        doc = Nokogiri::HTML5::Document.parse(cont, max_errors: -1)
        expect(doc.errors).to be_empty
      end
    end
    it "shoud have no errors in HTML for shapes info" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_with_instances.ttl"))
      @ttl2html.output_html_files
      doc = Nokogiri::HTML5::Document.parse(open("/tmp/html/about.html").read, max_errors: -1)
      expect(doc.errors).to be_empty
    end
    it "should deal with path separators" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      expect {
        @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
        @ttl2html.output_html_files
      }.not_to raise_error
    end
    it "should deal with URIs ending with '/'" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_ending_slash.ttl"))
      @ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a/index.html")).to be true
      expect(File.exist?("/tmp/html/a/.html")).to be false
    end
    it "should support stable path links" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_links.ttl"))
      @ttl2html.output_html_files
      expect(File.exist?("/tmp/html/bbbb.html")).to be true
      cont = File.open("/tmp/html/bbbb.html").read
      html = Capybara.string cont
      expect(html).to have_link("test title", href: "a/")
    end
    it "should respect output dir" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a")).to be true
      expect(File.exist?("/tmp/html/a/index.html")).to be true
      expect(File.exist?("/tmp/html/a/b.html")).to be true
    end
    it "should respect title property" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a/index.html").read
      html = Capybara.string cont
      expect(html).to have_title("test title")
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_title("no title")
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_title("test label")
      cont = File.open("/tmp/html/c.html").read
      html = Capybara.string cont
      expect(html).to have_title("test title")
    end
    it "should respect title property settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_title.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_title("test title example")
    end
    it "should respect title property per class settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_title_perclass.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_title_perclass.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a/index.html").read
      html = Capybara.string cont
      expect(html).to have_title("test description")
    end
    it "should use title labels as a link text" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_link("test title", href: "a/")
    end
    it "should respect labels" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Class")
    end
    it "should respect shape labels" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Name")
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_ja.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "名称")
    end
    it "should respect shape labels with sh:or" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape2.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Name")
    end
    it "should respect inverse properties" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_link "a"
      expect(html).to have_css("dt", text: /Referred to as/)
    end
    it "should respect inverse blank property labels with shapes" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_with_instances.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Library")
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Author")
      cont = File.open("/tmp/html/00b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Author")
      cont = File.open("/tmp/html/libraryA.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Library")
      expect(html).to have_css("dt", text: "Holding")
    end
    it "should respect inverse property labels with shapes with locale" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_ja.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_with_instances_ja.ttl"))
      @ttl2html.output_html_files
      cont = File.open("/tmp/html/a.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Library")
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "氏名")
      expect(html).to have_css("dt", text: "著者")
    end
    it "should accept top_class config" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      expect(File).to exist "/tmp/html/index.html"
      cont = File.open("/tmp/html/index.html").read
      html = Capybara.string cont
      expect(html).to have_link href: "a/"
      expect(html).to have_link href: "c"
      expect(html).not_to have_link href: "b"
      expect(html).to have_title /^Test website$/
      expect(html).to have_css("h2", text: "List of test label")
    end
    it "should accept multiple top_class config" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_multi_top_class.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_multi_top_class.ttl"))
      @ttl2html.output_html_files
      expect(File).to exist "/tmp/html/index.html"
      cont = File.open("/tmp/html/index.html").read
      html = Capybara.string cont
      expect(html).to have_link href: "a/"
      expect(html).to have_link href: "c"
    end
    it "should generate URI order for index.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      expect(File).to exist "/tmp/html/index.html"
      cont = File.open("/tmp/html/index.html").read
      html = Capybara.string cont
      expect(html.find("div.row ul li:nth-child(1)")).to have_link href: "a/"
      expect(html.find("div.row ul li:nth-child(2)")).to have_link href: "a/b"
      expect(html.find("div.row ul li:nth-child(3)")).to have_link href: "c"
    end
    it "should be fine even if no instance available" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_noclass.ttl"))
      expect {
        @ttl2html.output_html_files
      }.not_to raise_error
      expect(File).not_to exist "/tmp/html/index.html"
    end
    it "should work even if config does not have output_dir paramerter" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_nooutput_dir.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      expect {
        @ttl2html.output_html_files
        @ttl2html.output_turtle_files
      }.not_to raise_error
      @ttl2html.cleanup
    end
    it "should generate about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      @ttl2html.output_html_files
      @ttl2html.output_turtle_files
      expect(File).to exist "/tmp/html/about.html"
      expect(File).to exist "/tmp/html/AShape.html"
      expect(File).to exist "/tmp/html/AShape.ttl"
      @ttl2html.cleanup
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h2#shapes")
      expect(html).to have_css("h3", text: "Book")
      expect(html).to have_css("p", text: "This class represents a Book instance.")
      expect(html).to have_title(/^About Test website$/)
    end
    it "should generate toc in about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_toc.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("div.row nav#toc")
    end
    it "should generate id attr for shape headings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h2#shapes")
      expect(html).to have_css("h3#AShape", text: "Book")
    end
    it "should ignore empty shape in about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/empty_shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h2#shapes")
      expect(html).not_to have_css("h3#BShape")
    end
    it "should generate resouce instance with the shape order" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_order.ttl"))
      @ttl2html.output_html_files
      expect(File).to exist "/tmp/html/a.html"
      cont = open("/tmp/html/a.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dl dt:nth-child(1)", text: /^Name$/)
      expect(html).to have_css("dl dt:nth-of-type(2)", text: /^Description$/)
    end
    it "should accept sh:or node for about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_or.ttl"))
      expect {
        @ttl2html.output_html_files
      }.not_to raise_error
      expect(File).to exist "/tmp/html/about.html"
    end
    it "should respect order of resources at about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_shape_orders.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_with_instances_ja.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h2#shapes")
      expect(html).to have_css("h2#shapes + h3", text: "Item")
    end
    it "should use Class label for title" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h3", text: "Book")
      expect(html).to have_link("http://schema.org/Book")
    end
    it "should setup work break on URL-like string for about page." do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h3", text: "Book")
      expect(html).to have_link("http://schema.org/Book")
    end
    it "should generate versions information" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/versions.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h2#versions + dl")
      expect(html.all("h2#versions + dl dt").size).to eq 2
      expect(html).to have_css("dt", text: /^2021-12-11$/)
      expect(html).to have_css("dt", text: /^2021-12-12$/)
      expect(html).to have_css("h2#versions + dl dd a[href='dataset-1.ttl']")
      expect(html).to have_css("h2#versions + dl dd a", text: "subset1.ttl")
      expect(html).to have_css("h2#versions + dl dd a", text: "subset2.ttl")
      expect(html).to have_css("h2#versions + dl dd a[href='https://example.org/note.html']")
      expect(html).to have_css("h2#versions + dl dd a[href='https://blog.example.org/features/2']")
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h2#versions", text: /^Latest dataset/)
      expect(html).to have_css("h2#versions + dl dt", text: /^2021-12-12$/)
      expect(html).to have_css("h2#versions + dl + p a[href='about#versions']")
    end
    it "should generate toplevel dataset metadata" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/toplevel.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("div.jumbotron p", text: /^Toplevel description$/)
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("div.jumbotron p", text: /^Toplevel description$/)
      expect(html).to have_css("p a[href='mailto:admin@example.org']")
    end
    it "should support license data" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/license.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_link "https://creativecommons.org/publicdomain/zero/1.0/"
    end
    it "should support multiple dataset files" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/versions_multi.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_link "dataset-a-1.ttl"
      expect(html).to have_link "dataset-b-1.ttl"
      expect(html).to have_link "https://creativecommons.org/publicdomain/zero/1.0/"
      expect(html).to have_link "https://creativecommons.org/licenses/by/4.0/"
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).not_to have_link("", href: "")
      doc = Nokogiri::HTML5.parse(cont)
      expect(doc.errors).to be_empty
    end
    it "should output license and icon image for datasets" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/versions-thumbnail.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_selector ".license"
      expect(html).to have_selector ".license img"
      expect(html).to have_selector ".license img[alt='']"
    end
    it "should add link to the SPARQL endpoint info on index and about pages" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/versions-endpoint.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_link "https://example.org/endpoint"
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_link "https://example.org/endpoint"
    end
    it "should include about.html template for about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_about.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("div.container p", text: "Test description")
    end
    it "should include an additional content template with template_dir" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_content.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("p.additional-content", text: "Test description")
    end
    it "should respect prefix for sh:path description on about.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("td code", text: "ex:title")
    end
    it "should display prefix mappings at shape captions" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("table tfoot dl dt", text: "ex:")
      expect(html).to have_css("table tfoot dl dd", text: "https://example.org/")
    end
    it "should add class=url for the name and example columns in shapes table" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("table td.url", text: "ex:title")
    end
    it "should accept labels_with_class settings per target class" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_labels_with_class.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Description")
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Class")
    end
    it "should respect labels_with_class settings for inverse properties" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_labels_with_class.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_multi_top_class.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Has Part")
    end
    it "should accept uri_maping parameters in config.yml" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_mapping.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_mapping.ttl"))
      @ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a.html")).to be true
      expect(File.exist?("/tmp/html/123/4567890123.html")).to be true
      cont = open("/tmp/html/123/4567890123.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("a[href='../000/0000000001']")
    end
    it "should respect i18n settings for names" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_ja.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_ja.ttl"))
      @ttl2html.output_html_files
      expect(File.exist?("/tmp/html/AShape.html")).to be true
      cont = open("/tmp/html/AShape.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("footer img[alt='RDFデータ']")
      expect(File.exist?("/tmp/html/about.html")).to be true
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("td", text: /^名称$/)
      expect(html).to have_css("td", text: /^名前を示すプロパティ$/)
      expect(html).to have_css("p", text: /^このクラスは書籍リソースをあらわします$/)
    end
    it "should have html lang attribute" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("html[lang='en']", visible: false)
    end
    it "should have html lang attribute with locale setting" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_ja.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("html[lang='ja']", visible: false)
    end
    it "should not have a link to rdf data at index.html" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).not_to have_css("footer a")
    end
    it "should display admin name" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_copyright.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("footer p", text: "Dataset Admin")
      expect(html).to have_css("footer p", text: "© 2021")
    end
    it "should link to home and about" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar a.nav-link[href='./']", text: "Home")
      expect(html).to have_css("nav.navbar a.nav-link[href='about.html']", text: "About")
      expect(html).to have_css("div.jumbotron a[href='about.html']", text: "About")
      cont = open("/tmp/html/a/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar a.nav-link[href='../']", text: "Home")
      expect(html).to have_css("nav.navbar a.nav-link[href='../about.html']", text: "About")
    end
    it "should respect navbar_class setting" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/navbar_dark.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar.navbar-dark")
      expect(html).to have_css("nav.navbar.bg-dark")
    end
    it "should output logo" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_logo.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar > a.navbar-brand img[src='logo.png']")
      expect(html).to have_css("nav.navbar > a.navbar-brand[href='./']")
      cont = open("/tmp/html/a/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar > a.navbar-brand img[src='../logo.png']")
      expect(html).to have_css("nav.navbar > a.navbar-brand[href='../']")
    end
    it "should output logo with absolute path" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_logo2.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar > a.navbar-brand img[src='https://example.org/logo.png']")
      expect(html).to have_css("nav.navbar > a.navbar-brand[href='./']")
      cont = open("/tmp/html/a/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar > a.navbar-brand img[src='https://example.org/logo.png']")
      expect(html).to have_css("nav.navbar > a.navbar-brand[href='../']")
    end
    it "should output ogp tags" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_logo.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("meta[property='og:title'][content='Test website']", visible: false)
      expect(html).to have_css("meta[property='og:type'][content='website']", visible: false)
      expect(html).to have_css("meta[property='og:image'][content='https://example.org/logo.png']", visible: false)
    end
    it "should output additional links" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_additional_link.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav.navbar a.nav-link[href='https://example.com/']", text: "Link1")
      expect(html).to have_css("nav.navbar a.nav-link[href='https://example.org/']", text: "Link2")
    end
    it "should link to custom javascript_file" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/javascript_file.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("script[src='../custom.js']", visible: false)
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("script[src='custom.js']", visible: false)
    end
    it "should link to multiple custom javascript_file" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/javascript_file2.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("script[src='../custom2.js']", visible: false)
      expect(html).to have_css("script[src='../custom1.js']", visible: false)
    end
    it "should link to multiple css_file" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/css_file.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("link[href='../custom2.css']", visible: false)
      expect(html).to have_css("link[href='../custom1.css']", visible: false)
    end
    it "should output breadcrumbs according to the settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title$/)
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html.all("nav ol.breadcrumb li.breadcrumb-item").size).to eq 4
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title$/)
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title 2$/)
      expect(html).to have_css("nav ol.breadcrumb li.active", text: "test title 3")
    end
    it "should output breadcrumbs with inverse property settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs_inverse.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs_inverse.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title$/)
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title 2$/)
      expect(html).to have_css("nav ol.breadcrumb li.active", text: "test title 3")
    end
    it "should output breadcrumbs with multiple property settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs_multi.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs_multi.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html.all("nav ol.breadcrumb li.breadcrumb-item").size).to eq 5
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title$/)
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title 2$/)
      expect(html).to have_css("nav ol.breadcrumb li.active", text: "test title 3")
    end
    it "should output breadcrumbs with a sequence of multiple properties" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs_propsequence.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs_propsequence.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/d.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html.all("nav ol.breadcrumb li.breadcrumb-item").size).to eq 6
    end
    it "shoud output breadcrumbs with uri_mappings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs_urimappings.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs_urimappings.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      cont = open("/tmp/html/012/345/6789012.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html).to have_css("nav ol.breadcrumb a[href='../../']", text: "Home")
    end
    it "should support google_analytics" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example_analytics.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("head script[src='https://www.googletagmanager.com/gtag/js?id=zzz']", visible: false)
    end
    it "should support inverse property of blank node" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example_blank_subject.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dl dd dl dt a[href='b']")
      expect(html).to have_css("dl dd dl dt", text: /^C$/)
      expect(html).to have_css("dl dd dl dd a[href='a']")
      expect(html).not_to have_css("dd", text: "FFF")
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dl dd dl.border")
    end
    it "should output properties in a stable order" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example_blank_order.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/a.html"){|io| io.read }
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example_blank_order2.ttl"))
      @ttl2html.output_html_files
      cont2 = open("/tmp/html/a.html"){|io| io.read }
      expect(cont).to eq cont2
    end
    it "should output lang attr for literals with language tag" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dl dd[lang='ja']", text: "test title")
    end
    it "should output generator and version meta tag" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("meta[name=generator][content~=ttl2html]", visible: false)
    end
    it "should supprt gcse settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example_gcse.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("script[src='https://cse.google.com/cse.js?cx=0123456789:qidabcdefg']", visible: false)
      expect(html).to have_css("div.gcse-search")
      FileUtils.cp "/tmp/html/b.html", "/tmp/b.html"
    end
    it "should support og: settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example_ogp.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("meta[property='og:image'][content='https://example.org/logo2.png']", visible: false)
    end
    it "should support priotize og:image over logo settings" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example_ogp_with_logo.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("meta[property='og:image'][content='https://example.org/logo2.png']", visible: false)
      expect(html).not_to have_css("meta[property='og:image'][content='https://example.org/logo.png']", visible: false)
    end
    it "should include description.html template for top and about pages" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example_content.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example.ttl"))
      @ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("div.jumbotron div.description")
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("div.jumbotron div.description")
    end
    it "should output files/dirs accurately, even in parallel execution" do
      @ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example_content.yml"))
      @ttl2html.load_turtle(File.join(spec_base_dir, "example", "example_order.ttl"))
      expect {
        @ttl2html.output_html_files
      }.not_to raise_error
      expect(Pathname("/tmp/html/a")).to be_directory
      expect(Pathname("/tmp/html/b")).to be_directory
    end
  end
  context "#output_turtle_files" do
    ttl2html = nil
    after(:each) do
      ttl2html.cleanup
    end
    it "should generate files" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      expect {
        ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
        ttl2html.output_turtle_files
      }.not_to raise_error
      expect(File.exist?("/tmp/html/a.ttl")).to be true
      expect(File.exist?("/tmp/html/a/b.ttl")).to be true
      expect {
        ttl2html.load_turtle("/tmp/html/a.ttl")
        ttl2html.load_turtle("/tmp/html/a/b.ttl")
      }.not_to raise_error
    end
    it "should generate files" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_turtle_files
      expect(File.exist?("/tmp/html/b.ttl")).to be true
      data = ttl2html.load_turtle("/tmp/html/b.ttl")
      expect(data.size).to be > 1
    end
    it "should accept uri_maping parameters in config.yml" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_mapping.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_mapping.ttl"))
      ttl2html.output_turtle_files
      expect(File.exist?("/tmp/html/a.ttl")).to be true
      expect(File.exist?("/tmp/html/123/4567890123.ttl")).to be true
    end
    it "should skip blank subjects in inverse statements" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_blank_subject.ttl"))
      ttl2html.output_turtle_files
      expect(File.exist?("/tmp/html/a.ttl")).to be true
      RDF::Turtle::Reader.new(open("/tmp/html/a.ttl")) do |reader|
        reader.statements.each do |statement|
          expect(statement.subject.to_s).not_to start_with("_:")
        end
      end
    end
    it "should support literals with langauge tags" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      ttl2html.output_turtle_files
      expect(File).to exist("/tmp/html/c.ttl")
      RDF::Turtle::Reader.new(open("/tmp/html/c.ttl")) do |reader|
        reader.statements.each do |statement|
          if statement.predicate == RDF::URI("http://purl.org/dc/terms/title")
            expect(statement.object).to be_language
            expect(statement.object.language).to eq :ja
          end
        end
      end
    end
    it "should support literals with datatypes" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_datatype.ttl"))
      ttl2html.output_turtle_files
      expect(File).to exist("/tmp/html/c.ttl")
      RDF::Turtle::Reader.new(open("/tmp/html/c.ttl")) do |reader|
        reader.statements.each do |statement|
          if statement.predicate == RDF::URI("https://example.org/propInt")
            expect(statement.object).to be_datatype
            expect(statement.object.datatype).to eq RDF::XSD.integer
          end
        end
      end
    end
    it "should expand blank nodes" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_blank_subject.ttl"))
      ttl2html.output_turtle_files
      expect(File).to exist("/tmp/html/b.ttl")
      RDF::Turtle::Reader.new(open("/tmp/html/b.ttl")) do |reader|
        statements = reader.statements
        blank_statement = statements.find{|e| e.predicate == RDF::URI("https://example.org/c") }
        expect(blank_statement).not_to be_nil
        blank_subject = blank_statement.object
        expect(blank_subject).to be_resource
        blank_statement = statements.find{|e| e.subject == blank_subject }
        expect(blank_statement).not_to be_nil
      end
    end
    it "should output properties in a stable order" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example", "example_blank_order.ttl"))
      ttl2html.output_turtle_files
      cont = open("/tmp/html/a.ttl"){|io| io.read }
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example", "example_blank_order2.ttl"))
      ttl2html.output_turtle_files
      cont2 = open("/tmp/html/a.ttl"){|io| io.read }
      expect(cont).to eq cont2
    end
    it "should output properties in a stable order with respect to order properties" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example", "example.yml"))
      ttl = File.join(spec_base_dir, "example", "example_blank_qborder.ttl")
      ttl2 = File.join(spec_base_dir, "example", "example_blank_qborder2.ttl")
      ttl2html.load_turtle(ttl)
      ttl2html.output_turtle_files
      cont = open("/tmp/html/a.ttl"){|io| io.read }
      cont2 = open(ttl2){|io| io.read }
      expect(cont).to eq cont2
    end
  end
  context "#output_files" do
    ttl2html = nil
    after(:each) do
      ttl2html.cleanup
    end
    it "should support output_turtle settings" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/disable_turtle.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_files
      expect(File).not_to exist("/tmp/html/b.ttl")
    end
  end
  context "#cleanup" do
    it "should cleanup" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      expect(File).to exist("/tmp/html/index.html")
      expect(File).to exist("/tmp/html/a/b.html")
      ttl2html.cleanup
      expect(File.exist?("/tmp/html/a")).to be false
      expect(File.exist?("/tmp/html/a/b.html")).to be false
      expect(File.exist?("/tmp/html/a/b.ttl")).to be false
      expect(File.exist?("/tmp/html/index.html")).to be false
    end
  end
  context "#shapes2labels" do
    it "should import labels from shape" do
      ttl_file = File.join(spec_base_dir, "example/shape.ttl")
      graph = RDF::Graph.load(ttl_file, format:  :ttl)
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(ttl_file)
      shapes = graph.query([nil, RDF.type, RDF::URI("http://www.w3.org/ns/shacl#NodeShape")])
      labels = ttl2html.shapes2labels(shapes.subjects.map{|s| s.to_s })
      expect(labels).to have_key "http://schema.org/Book"
      expect(labels["http://schema.org/Book"]).to have_key "https://example.org/name"
    end
    it "should support sh:or shapes" do
      ttl_file = File.join(spec_base_dir, "example/shape_or.ttl")
      graph = RDF::Graph.load(ttl_file, format:  :ttl)
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(ttl_file)
      shapes = graph.query([nil, RDF.type, RDF::URI("http://www.w3.org/ns/shacl#NodeShape")])
      labels = ttl2html.shapes2labels(shapes.subjects.map{|s| s.to_s })
      expect(labels).to have_key "https://example.org/Item"
      expect(labels["https://example.org/Item"]).to have_key "https://example.org/b"
      expect(labels["https://example.org/Item"]["https://example.org/b"].first).to eq "Foo"
    end
  end
end
