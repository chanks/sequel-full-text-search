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

      def facets(*columns)
        result = {}
        columns.each do |column|
          result[column] = unordered.group_by(column).select_hash(column, Sequel.as(SQL::Function.new(:count, Sequel.lit('*')), :count))
        end
        result
      end
    end
  end

  Dataset.register_extension :full_text_search, FullTextSearch::DatasetMethods
end
