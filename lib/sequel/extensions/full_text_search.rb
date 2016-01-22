require 'sequel/extensions/full_text_search/version'

module Sequel
  module FullTextSearch
    module DatasetMethods
      COUNT_FUNCTION = Sequel.function(:count, Sequel.lit('*')).freeze

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

      def facets(columns, filters: {})
        results       = {}
        count_columns = {}
        selections    = []

        columns.each do |column|
          count_column          = "#{column}_count".to_sym
          results[column]       = {}
          count_columns[column] = count_column
          aggregate             = COUNT_FUNCTION

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
