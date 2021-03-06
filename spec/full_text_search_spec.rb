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

    def counts_of_column(ds, expression)
      exp =
        case expression
        when Symbol                         then expression
        when Sequel::SQL::AliasedExpression then expression.expression
        else raise "Bad expression: #{expression}"
        end

      ds.unordered.group_by(exp).select_hash(Sequel.as(exp, :value), Sequel.as(Sequel::SQL::Function.new(:count, Sequel.lit('*')), :count))
    end

    it "should return aggregates on the total count of records for each passed facet" do
      result = ds.facets([:track_count, :high_quality, :number_of_stars])

      expected = {
        track_count:     counts_of_column(ds, :track_count),
        high_quality:    counts_of_column(ds, :high_quality),
        number_of_stars: counts_of_column(ds, :number_of_stars)
      }

      assert_equal(expected, result)
    end

    it "should respect other filters on the dataset" do
      result = ds.where{track_count > 10}.facets([:track_count, :high_quality, :number_of_stars])

      expected = {
        track_count:     counts_of_column(ds.where{track_count > 10}, :track_count),
        high_quality:    counts_of_column(ds.where{track_count > 10}, :high_quality),
        number_of_stars: counts_of_column(ds.where{track_count > 10}, :number_of_stars)
      }

      assert_equal(expected, result)
    end

    it "should raise an error when a filter doesn't match a provided column" do
      error = assert_raises(Sequel::FullTextSearch::Error) { ds.facets([:track_count, :high_quality], filters: {number_of_stars: 4}) }
      assert_equal "You tried to filter on 'number_of_stars' without faceting on it", error.message
    end

    it "should respect a single filter on a value" do
      result = ds.facets([:track_count, :high_quality, :number_of_stars], filters: {track_count: 10})

      expected = {
        track_count:     counts_of_column(ds, :track_count),
        high_quality:    counts_of_column(ds.where(track_count: 10), :high_quality),
        number_of_stars: counts_of_column(ds.where(track_count: 10), :number_of_stars)
      }

      assert_equal(expected, result)
    end


    it "should respect a single filter on multiple values" do
      result = ds.facets([:track_count, :high_quality, :number_of_stars], filters: {track_count: [10, 12]})

      expected = {
        track_count:     counts_of_column(ds, :track_count),
        high_quality:    counts_of_column(ds.where(track_count: [10, 12]), :high_quality),
        number_of_stars: counts_of_column(ds.where(track_count: [10, 12]), :number_of_stars),
      }

      assert_equal(expected, result)
    end

    it "should respect two distinct filters" do
      result = ds.facets([:track_count, :high_quality, :number_of_stars], filters: {track_count: [10, 12], high_quality: true})

      expected = {
        track_count:     counts_of_column(ds.where(:high_quality), :track_count),
        high_quality:    counts_of_column(ds.where(track_count: [10, 12]), :high_quality),
        number_of_stars: counts_of_column(ds.where(:high_quality).where(track_count: [10, 12]), :number_of_stars),
      }

      assert_equal(expected, result)
    end

    it "should respect facets on arbitrary expressions" do
      result = ds.facets([Sequel.extract(:month, :release_date).as(:month_of_year), :high_quality], filters: {high_quality: true})

      expected = {
        month_of_year: counts_of_column(ds.where(:high_quality), Sequel.extract(:month, :release_date).as(:month_of_year)),
        high_quality:  counts_of_column(ds, :high_quality),
      }

      assert_equal(expected, result)
    end

    it "should respect filters on facets that are arbitrary expressions" do
      result = ds.facets([Sequel.extract(:month, :release_date).as(:month_of_year), :high_quality], filters: {high_quality: true, month_of_year: 3})

      expected = {
        month_of_year: counts_of_column(ds.where(:high_quality), Sequel.extract(:month, :release_date).as(:month_of_year)),
        high_quality:  counts_of_column(ds.where(Sequel.extract(:month, :release_date) => 3), :high_quality),
      }

      assert_equal(expected, result)
    end
  end
end
