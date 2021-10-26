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
    it "should respect labels" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_css("dt", text: "Class")
    end
    it "should respect inverse properties" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      cont = File.open("/tmp/html/b.html").read
      html = Capybara.string cont
      expect(html).to have_link "https://example.org/a"
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
      expect(html).to have_css("h3", text: "Bookをあらわすリソース")
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
