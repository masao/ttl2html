RSpec.describe XLSX2Shape do
  include XLSX2Shape
  spec_base_dir = File.dirname(__FILE__)
  context "#xlsx2shape" do
    it "should work without error" do
      shape = nil
      expect {
        shape = xlsx2shape(File.join(spec_base_dir, "example", "example.xlsx"))
      }.not_to raise_error
      io = StringIO.new(shape)
      expect {
        turtle = RDF::Turtle::Reader.for(:turtle).new(shape)
        turtle.statements
      }.not_to raise_error
    end
  end
end
