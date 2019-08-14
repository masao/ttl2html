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
  context "#output_html_files" do
    it "should deal with path separators" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      expect {
        ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
        ttl2html.output_html_files
      }.not_to raise_error
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
      cont = File.open("/tmp/html/a/b.html").read
      html = Capybara.string cont
      expect(html).to have_title("no title")
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
    end
  end
  context "#cleanup" do
    it "should cleanup" do
      ttl2html = TTL2HTML::App.new(File.join(spec_base_dir, "example/example.yml"))
      ttl2html.load_turtle(File.join(spec_base_dir, "example/example.ttl"))
      ttl2html.output_html_files
      expect(File.exist?("/tmp/html/a/b.html")).to be true
      expect(File.exist?("/tmp/html/a/b.ttl")).to be true
      ttl2html.cleanup
      expect(File.exist?("/tmp/html/a/b.html")).to be false
      expect(File.exist?("/tmp/html/a/b.ttl")).to be false
    end
  end
end
