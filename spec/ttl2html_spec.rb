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
  end
  context "#find_turtle" do
    include TTL2HTML
    it "should find a turtle file" do
      file = find_turtle(File.join(spec_base_dir, "example/example.ttl"))
      expect(file).to eq File.join(spec_base_dir, "example/example-20211023.ttl.gz")
    end
  end
  context "#output_html_files" do
    after(:each) do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.cleanup
    end
    it "should deal with path separators" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      expect {
        ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
        ttl2html.output_html_files
      }.not_to raise_error
    end
    it "should deal with URIs ending with '/'" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_ending_slash.ttl"))
      ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a/index.html")).to be true
      expect(File.exist?("/tmp/html/a/.html")).to be false
    end
    it "should respect output dir" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a")).to be true
      expect(File.exist?("/tmp/html/a/index.html")).to be true
      expect(File.exist?("/tmp/html/a/b.html")).to be true
    end
    it "should respect title property" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
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
      expect(html).to have_title("test title", exact: true)
    end
    it "should respect title property settings" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_title.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_title("test title example")
    end
    it "should respect title property per class settings" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_title_perclass.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_title_perclass.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/a/index.html").read
      html = Capybara.string cont
      expect(html).to have_title("test description")
    end
    it "should use title labels as a link text" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_link("test title", href: "a")
    end
    it "should respect labels" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Class")
    end
    it "should respect shape labels" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Name")

      original_locale = I18n.locale
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_ja.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_shape.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "名称")
      I18n.locale = original_locale
    end
    it "should respect inverse properties" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_link "a"
      expect(html).to have_css("dt", text: /Referred to as/)
    end
    it "should accept top_class config" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      expect(File).to exist "/tmp/html/index.html"
      cont = File.open("/tmp/html/index.html").read
      html = Capybara.string cont
      expect(html).to have_link href: "a"
      expect(html).to have_link href: "c"
      expect(html).not_to have_link href: "b"
    end
    it "should generate URI order for index.html" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      expect(File).to exist "/tmp/html/index.html"
      cont = File.open("/tmp/html/index.html").read
      html = Capybara.string cont
      expect(html.find("div.row ul li:nth-child(1)")).to have_link href: "a"
      expect(html.find("div.row ul li:nth-child(2)")).to have_link href: "a/b"
      expect(html.find("div.row ul li:nth-child(3)")).to have_link href: "c"
    end
    it "should be fine even if no instance available" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_noclass.ttl"))
      expect {
        ttl2html.output_html_files
      }.not_to raise_error
      expect(File).not_to exist "/tmp/html/index.html"
    end
    it "should work even if config does not have output_dir paramerter" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_nooutput_dir.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      expect {
        ttl2html.output_html_files
        ttl2html.output_turtle_files
      }.not_to raise_error
      ttl2html.cleanup
    end
    it "should generate about.html" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      ttl2html.output_html_files
      ttl2html.output_turtle_files
      expect(File).to exist "/tmp/html/about.html"
      expect(File).to exist "/tmp/html/AShape.html"
      expect(File).to exist "/tmp/html/AShape.ttl"
      ttl2html.cleanup
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h3", text: "Book")
      expect(html).to have_css("p", text: "This class represents a Book instance.")
    end
    it "should generate resouce instance with the shape order" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_order.ttl"))
      ttl2html.output_html_files
      expect(File).to exist "/tmp/html/a.html"
      cont = open("/tmp/html/a.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dl dt:nth-child(1)", text: /^Name$/)
      expect(html).to have_css("dl dt:nth-of-type(2)", text: /^Description$/)
    end
    it "should accept sh:or node for about.html" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_or.ttl"))
      expect {
        ttl2html.output_html_files
      }.not_to raise_error
      expect(File).to exist "/tmp/html/about.html"
    end
    it "should use Class label for title" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/shape.ttl"))
      ttl2html.output_html_files
      cont = open("/tmp/html/about.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("h3", text: "Book")
    end
    it "should accept labels_with_class settings per target class" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_labels_with_class.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = open("/tmp/html/a/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Description")
      cont = open("/tmp/html/b.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Class")
    end
    it "should accept uri_maping parameters in config.yml" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_mapping.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_mapping.ttl"))
      ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a.html")).to be true
      expect(File.exist?("/tmp/html/123/4567890123.html")).to be true
      cont = open("/tmp/html/123/4567890123.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("a[href='../000/0000000001']")
      expect(html).to have_css("footer a[href='4567890123.ttl']")
    end
    it "should respect i18n settings for names" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_ja.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/shape_ja.ttl"))
      ttl2html.output_html_files
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
    it "should not have a link to rdf data at index.html" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = open("/tmp/html/index.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).not_to have_css("footer a")
    end
    it "should output breadcrumbs according to the settings" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs.ttl"))
      ttl2html.output_html_files
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
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs_inverse.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs_inverse.ttl"))
      ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title$/)
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title 2$/)
      expect(html).to have_css("nav ol.breadcrumb li.active", text: "test title 3")
    end
    it "should output breadcrumbs with multiple property settings" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example_breadcrumbs_multi.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example_breadcrumbs_multi.ttl"))
      ttl2html.output_html_files
      cont = open("/tmp/html/c.html"){|io| io.read }
      html = Capybara.string cont
      expect(html).to have_css("nav ol.breadcrumb")
      expect(html.all("nav ol.breadcrumb li.breadcrumb-item").size).to eq 5
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title$/)
      expect(html).to have_css("nav ol.breadcrumb a", text: /^test title 2$/)
      expect(html).to have_css("nav ol.breadcrumb li.active", text: "test title 3")
    end
  end
  context "#output_turtle_files" do
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
      expect(File.exist?("/tmp/html/c.ttl")).to be true
      RDF::Turtle::Reader.new(open("/tmp/html/c.ttl")) do |reader|
        reader.statements.each do |statement|
          if statement.predicate == RDF::URI("http://purl.org/dc/terms/title")
            expect(statement.object).to be_language
            expect(statement.object.language).to eq :ja
          end
        end
      end
    end
  end
  context "#cleanup" do
    it "should cleanup" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      expect(File.exist?("/tmp/html/index.html")).to be true
      expect(File.exist?("/tmp/html/a/b.html")).to be true
      expect(File.exist?("/tmp/html/a/b.ttl")).to be true
      ttl2html.cleanup
      expect(File.exist?("/tmp/html/a")).to be false
      expect(File.exist?("/tmp/html/a/b.html")).to be false
      expect(File.exist?("/tmp/html/a/b.ttl")).to be false
      expect(File.exist?("/tmp/html/index.html")).to be false
    end
  end
end
