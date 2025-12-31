require "open3"

spec_base_dir = File.dirname(__FILE__)
RSpec.describe "bin/catttl" do
  it "should warn a duplicate prefix" do
    stdout, stderr, status = Open3.capture3("ruby -I#{spec_base_dir}/../lib bin/catttl spec/example/prefix1.ttl spec/example/prefix2.ttl spec/example/prefix3.ttl")
    msg = stdout
    err_msg = stderr
    expect(err_msg).to include "Duplicate prefixes: ex: \[\"https://example.org/\", \"https://example.com/\"\]"
  end
end
