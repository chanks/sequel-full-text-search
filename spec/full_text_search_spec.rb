require 'spec_helper'

class FullTextSearchSpec < SequelFTSSpec
  it "should have a version number" do
    refute_nil Sequel::FullTextSearch::VERSION
  end

  describe "Dataset#text_search" do
    before do
      @albums = Album.order_by{random{}}.first(3)
      @albums.each { |a| a.update description: 'popular' }
    end

    it "should search for the given term in the searchable_text column" do
      assert_equal @albums.map(&:id).sort, DB[:albums].text_search('popular').select_order_map(:id)
    end
  end

  describe "Dataset#facets" do
    before do
      @albums = Album.order_by{random{}}.first(20)
      @albums.each { |a| a.update description: 'popular' }
    end

    it "should return aggregates on the total count of records for each passed facet" do
      result = DB[:albums].text_search('popular').facets(:track_count, :high_quality)

      track_counts = {}
      high_quality = {}

      @albums.each do |album|
        track_counts[album.track_count] ||= 0
        track_counts[album.track_count]  += 1

        high_quality[album.high_quality] ||= 0
        high_quality[album.high_quality]  += 1
      end

      expected = {
        track_count: track_counts,
        high_quality: high_quality,
      }

      assert_equal(expected, result)
    end
  end
end
