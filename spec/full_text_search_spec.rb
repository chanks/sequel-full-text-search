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
      result = DB[:albums].text_search('popular').facets([:track_count, :high_quality])

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

    it "should respect other filters on the dataset" do
      result = DB[:albums].text_search('popular').where{track_count > 10}.facets([:track_count, :high_quality])

      track_counts = {}
      high_quality = {}

      @albums.select{|a| a.track_count > 10}.each do |album|
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

    it "should respect filters passed to the facets argument" do
      result = DB[:albums].text_search('popular').facets([:track_count, :high_quality], filters: {track_count: [10]})

      track_counts = {}
      high_quality = {}

      @albums.each do |album|
        if album.track_count == 10
          high_quality[album.high_quality] ||= 0
          high_quality[album.high_quality]  += 1
        end

        track_counts[album.track_count] ||= 0
        track_counts[album.track_count]  += 1
      end

      expected = {
        track_count: track_counts,
        high_quality: high_quality,
      }

      assert_equal(expected, result)



      result = DB[:albums].text_search('popular').facets([:track_count, :high_quality], filters: {track_count: [10, 12]})

      track_counts = {}
      high_quality = {}

      @albums.each do |album|
        if [10, 12].include?(album.track_count)
          high_quality[album.high_quality] ||= 0
          high_quality[album.high_quality]  += 1
        end

        track_counts[album.track_count] ||= 0
        track_counts[album.track_count]  += 1
      end

      expected = {
        track_count: track_counts,
        high_quality: high_quality,
      }

      assert_equal(expected, result)



      result = DB[:albums].text_search('popular').facets([:track_count, :high_quality], filters: {track_count: [10, 12], high_quality: [true]})

      track_counts = {}
      high_quality = {}

      @albums.each do |album|
        if [10, 12].include?(album.track_count)
          high_quality[album.high_quality] ||= 0
          high_quality[album.high_quality]  += 1
        end

        if album.high_quality
          track_counts[album.track_count] ||= 0
          track_counts[album.track_count]  += 1
        end
      end

      expected = {
        track_count: track_counts,
        high_quality: high_quality,
      }

      assert_equal(expected, result)
    end
  end
end
