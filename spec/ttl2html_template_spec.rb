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
end
