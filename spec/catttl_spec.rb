require "open3"

spec_base_dir = File.dirname(__FILE__)
RSpec.describe "bin/catttl" do
  it "should accept inputs from exact file name(s)" do
    stdout, stderr, status = Open3.capture3("ruby -I#{spec_base_dir}/../lib ./bin/catttl -f spec/example/example.ttl spec/example/example.ttl")
    msg = stdout
    err_msg = stderr
    expect(err_msg).not_to include "spec/example/example.ttl not found. skipping."
    expect(err_msg).to include "spec/example/example.ttl"
  end
  it "should warn a duplicate prefix" do
    stdout, stderr, status = Open3.capture3("ruby -I#{spec_base_dir}/../lib bin/catttl spec/example/prefix1.ttl spec/example/prefix2.ttl spec/example/prefix3.ttl")
    msg = stdout
    err_msg = stderr
    expect(err_msg).to include "Duplicate prefixes: ex: \[\"https://example.org/\", \"https://example.com/\"\]"
  end
end
