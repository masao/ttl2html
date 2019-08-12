require_relative "../ttl2html"

RSpec.describe TTL2HTML do
  context "#new" do
    it "should construct a new instance" do
      ttl2html = TTL2HTML.new
      expect(ttl2html).not_to be_nil
    end
    it "should accept an argument" do
      ttl2html = TTL2HTML.new("config.yml")
      expect(ttl2html).not_to be_nil
      ttl2html = TTL2HTML.new(File.join(File.dirname(__FILE__), "example/example.yml"))
      expect(ttl2html).not_to be_nil
    end
  end
  context "#output_html_files" do
    it "should deal with path separators" do
      ttl2html = TTL2HTML.new
    end
  end
end
