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
      ids = Album.order_by{random{}}.limit(20).select_map(:id)
      Album.where(id: ids).update(description: 'popular')
    end

    let(:ds) { DB[:albums].text_search('popular') }

    def counts_of_column(ds, column)
      ds.unordered.group_by(column).select_hash(column, Sequel.as(Sequel::SQL::Function.new(:count, Sequel.lit('*')), :count))
    end

    it "should return aggregates on the total count of records for each passed facet" do
      result = ds.facets([:track_count, :high_quality])

      expected = {
        track_count: counts_of_column(ds, :track_count),
        high_quality: counts_of_column(ds, :high_quality),
      }

      assert_equal(expected, result)
    end

    it "should respect other filters on the dataset" do
      result = ds.where{track_count > 10}.facets([:track_count, :high_quality])

      expected = {
        track_count: counts_of_column(ds.where{track_count > 10}, :track_count),
        high_quality: counts_of_column(ds.where{track_count > 10}, :high_quality),
      }

      assert_equal(expected, result)
    end

    it "should respect a filter on a value" do
      result = ds.facets([:track_count, :high_quality], filters: {track_count: [10]})

      expected = {
        track_count: counts_of_column(ds, :track_count),
        high_quality: counts_of_column(ds.where(track_count: 10), :high_quality),
      }

      assert_equal(expected, result)
    end


    it "should respect a filter on multiple values" do
      result = ds.facets([:track_count, :high_quality], filters: {track_count: [10, 12]})

      expected = {
        track_count: counts_of_column(ds, :track_count),
        high_quality: counts_of_column(ds.where(track_count: [10, 12]), :high_quality),
      }

      assert_equal(expected, result)
    end

    it "should respect filters on multiple values" do
      result = ds.facets([:track_count, :high_quality], filters: {track_count: [10, 12], high_quality: [true]})

      expected = {
        track_count: counts_of_column(ds.where(:high_quality), :track_count),
        high_quality: counts_of_column(ds.where(track_count: [10, 12]), :high_quality),
      }

      assert_equal(expected, result)
    end
  end
end
