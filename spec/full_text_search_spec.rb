require 'spec_helper'

class FullTextSearchSpec < MiniTest::Spec
  it "should have a version number" do
    refute_nil Sequel::FullTextSearch::VERSION
  end

  describe "Dataset#text_search" do
    it "should search for the given term in the searchable_text column" do
      albums = Album.order_by{random{}}.first(3)
      albums.each { |a| a.update description: 'popular' }

      assert_equal albums.map(&:id).sort, DB[:albums].text_search('popular').select_order_map(:id)
    end
  end
end
