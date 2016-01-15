require 'spec_helper'

class FullTextSearchSpec < MiniTest::Spec
  it "should have a version number" do
    refute_nil Sequel::FullTextSearch::VERSION
  end
end
