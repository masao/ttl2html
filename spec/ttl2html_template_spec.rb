RSpec.describe TTL2HTML::Template do
  template_dir = "/tmp/html-#$$"
  before(:each) do
    FileUtils.mkdir template_dir
    FileUtils.touch File.join(template_dir, "layout.html.erb")
  end
  after(:each) do
    FileUtils.rm_rf template_dir
  end
  context "#new" do
    it "should have a new instance" do
      expect(TTL2HTML::Template.new("")).to be_truthy
    end
  end
  context "#relative_path_uri" do
    it "should generate relative path" do
      tmpl = TTL2HTML::Template.new("", output_file: "a.html")
      path = tmpl.relative_path_uri("http://example.org/a", "http://example.org/")
      expect(path).to eq Pathname.new("a")
      path = tmpl.relative_path_uri("http://example.com/a", "http://example.org/")
      expect(path).to eq "http://example.com/a"
    end
  end
  context "find_template" do
    it "should find proper template file" do
      template = TTL2HTML::Template.new("")
      path = template.find_template_path("layout.html.erb")
      expect(path).to eq File.expand_path(File.join(File.dirname(__FILE__), "..", "templates", "layout.html.erb"))
      template = TTL2HTML::Template.new("", template_dir: template_dir)
      path = template.find_template_path("layout.html.erb")
      expect(path).to eq File.join(template_dir, "layout.html.erb")
    end
  end
  context "format_property" do
    it "should return formatted values" do
      labels = {
        "http://schema.org/name" => "Title",
        "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" => "Class",
      }
      template = TTL2HTML::Template.new("")
      expect(template.format_property("http://schema.org/name")).to eq "Name"
      value = template.format_property("http://schema.org/name", labels)
      expect(value).to eq "Title"
      value = template.format_property("http://www.w3.org/1999/02/22-rdf-syntax-ns#type", labels)
      expect(value).to eq "Class"
    end
  end
  context "get_title" do
    it "should get title from rdf:label" do
      data = { "http://schema.org/name" => ["test name"] }
      template = TTL2HTML::Template.new("")
      title = template.get_title(data)
      expect(title).to eq "test name"
      data = {
        "http://schema.org/name" => ["test name"],
        "http://www.w3.org/2000/01/rdf-schema#label" => ["test label"],
      }
      title = template.get_title(data)
      expect(title).to eq "test label"
      title = template.get_title({})
      expect(title).to eq "no title"
    end
  end
  context "expand_shape" do
    spec_base_dir = File.dirname(__FILE__)
    it "should generate shape documentation" do
      ttl2html = TTL2HTML::App.new
      data = ttl2html.load_turtle(File.join(spec_base_dir, "example", "shape.ttl"))
      template = TTL2HTML::Template.new("", {locale: :en})
      cont = template.expand_shape(data, "https://example.org/AShape")
      html = Capybara.string cont
      expect(html).to have_css("tbody > tr")
      expect(html).to have_css("strong", text: "Required")
    end
    it "should respect i18n locale" do
      ttl2html = TTL2HTML::App.new
      data = ttl2html.load_turtle(File.join(spec_base_dir, "example", "shape.ttl"))
      template = TTL2HTML::Template.new("", {locale: :ja})
      cont = template.expand_shape(data, "https://example.org/AShape")
      html = Capybara.string cont
      expect(html).to have_css("table > tr > th")
      expect(html).to have_css("th", text: "プロパティ名")
    end
  end
  context "build_breadcrums" do
    it "should build breadcrums data" do
      settings = {
        breadcrums: [
          property: "http://www.w3.org/2004/02/skos/core#broader",
        ],
        data_global: {
          "https://example.org/a" => {
            "http://schema.org/name" => ["a"]
          }
        }
      }
      template = TTL2HTML::Template.new("", settings)
      data = {
        "http://www.w3.org/2004/02/skos/core#broader" => [ "https://example.org/a" ]
      }
      breadcrums = template.build_breadcrums(data)
      expect(breadcrums.size).to eq 1
    end
  end
end