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

      def facets(inputs, filters: OPTS)
        count_names = {}
        expressions = {}
        results     = {}

        # First a bit of housekeeping - figure out what the expressions we're
        # grouping by and the aliases we're using are.
        inputs.each do |input|
          name = expression = nil

          case input
          when Symbol
            name       = input
            expression = input
          when SQL::AliasedExpression
            name       = input.aliaz
            expression = input.expression
          else
            raise Error, "Unsupported input to Dataset#facets: #{input.class}"
          end

          count_names[name] = "#{name}_count".to_sym
          expressions[name] = expression
          results[name]     = {}
        end

        # Make sure the filters we were given make sense.
        filters.each do |name, values|
          unless expressions.has_key?(name)
            raise Error, "You tried to filter on '#{name}' without faceting on it"
          end
        end

        # Now to accumulate the actual SELECT components we'll pass to the DB.
        selections = []

        expressions.each do |name, expression|
          aggregate = COUNT_FUNCTION

          # Figure out what filters to apply to an aggregate, considering that
          # we don't want filters on an expression to affect that expression's
          # own facets.
          if (filter = filters.except(name)).any?
            new_filter = {}

            filter.each do |name, value|
              new_filter[expressions[name]] = value
            end

            aggregate = aggregate.filter(SQL::BooleanExpression.from_value_pairs(new_filter))
          end

          selections << Sequel.as(expression, name) << Sequel.as(aggregate, count_names[name])
        end

        # Build the actual query.
        ds =
          naked.
          unordered.
          group_by(*expressions.values).
          grouping_sets.
          select(*selections)

        # Iterate over rows so we can use streaming if it's enabled.
        ds.each do |row|
          count_names.each do |name, count_name|
            next if (value = row.fetch(name)).nil?
            next if (count = row.fetch(count_name)).zero?

            results[name][value] = count
          end
        end

        results
      end
    end
  end

  Dataset.register_extension :full_text_search, FullTextSearch::DatasetMethods
end
