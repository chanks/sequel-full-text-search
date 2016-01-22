require 'sequel/extensions/full_text_search/version'

module Sequel
  module FullTextSearch
    module DatasetMethods
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
        ds = naked.unordered.group_by(*columns).grouping_sets

        selections = columns.map { |column|
          aggregate = Sequel.function(:count, Sequel.lit('*'))

          if (filter = filters.except(column)).any?
            if filter.length == 1
              aggregate = aggregate.filter(filter)
            else
              raise
              # ?
              # aggregate = aggregate.filter(filter.inject{|a,b| ::Sequel::SQL::BooleanExpression.new(:AND, a, b)})
            end
          end

          [column, aggregate.as("#{column}_count".to_sym)]
        }

        ds = ds.select(*selections.flatten)

        results = {}

        columns.each do |column|
          results[column] = {}
        end

        # TODO: What to do about actually nil values?
        ds.each do |row|
          columns.each do |column|
            value = row.fetch(column)
            count = row.fetch("#{column}_count".to_sym)
            unless value.nil? || count.zero?
              results[column][value] = count
            end
          end
        end

        results
      end
    end
  end

  Dataset.register_extension :full_text_search, FullTextSearch::DatasetMethods
end
