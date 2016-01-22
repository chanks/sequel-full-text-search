require 'sequel/extensions/full_text_search/version'

module Sequel
  module FullTextSearch
    class Error < StandardError; end

    module DatasetMethods
      COUNT_FUNCTION = Sequel.function(:count, Sequel.lit('*')).freeze
      OPTS = {}.freeze

      def text_search(text)
        full_text_search(
          :searchable_text,
          text,
          tsvector: true,
          plain: true,
          rank: true,
          language: 'english'.freeze
        )
      end

      def facets(columns, filters: OPTS)
        results       = {}
        count_columns = {}
        selections    = []
        aggregate     = COUNT_FUNCTION

        # Make sure filters make sense.
        filters.each do |column, values|
          raise Error, "You tried to filter on '#{column}' without faceting on it" unless columns.include?(column)
        end

        columns.each do |column|
          count_columns[column] = count_column = "#{column}_count".to_sym

          results[column] = {}

          if (filter = filters.except(column)).any?
            aggregate = aggregate.filter(SQL::BooleanExpression.from_value_pairs(filter))
          end

          selections << column << aggregate.as(count_column)
        end

        naked.unordered.group_by(*columns).grouping_sets.select(*selections).each do |row|
          count_columns.each do |column, count_column|
            next if (value = row.fetch(column)).nil?
            next if (count = row.fetch(count_column)).zero?

            results[column][value] = count
          end
        end

        results
      end
    end
  end

  Dataset.register_extension :full_text_search, FullTextSearch::DatasetMethods
end
