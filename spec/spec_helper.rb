$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'sequel-full-text-search'

require 'minitest/autorun'
require 'minitest/pride'
require 'minitest/hooks'

require 'faker'
require 'pry'

Sequel.extension :full_text_search

DB = Sequel.connect "postgres:///sequel-full-text-search-test"

DB.extension :full_text_search

DB.drop_table? :tracks, :albums, :artists

DB.create_table :artists do
  primary_key :id

  text :name
  text :description

  tsvector :searchable_text, null: false

  index :searchable_text, type: :gin
end

DB.create_table :albums do
  primary_key :id

  foreign_key :artist_id, :artists

  text :name
  text :description

  integer :track_count,  null: false
  boolean :high_quality, null: false
  date    :release_date, null: false
  numeric :money_made,   null: false

  tsvector :searchable_text, null: false

  index :searchable_text, type: :gin
end

DB.create_table :tracks do
  primary_key :id

  foreign_key :album_id, :albums

  text :name
  text :description

  tsvector :searchable_text, null: false

  index :searchable_text, type: :gin
end

[:artists, :albums, :tracks].each do |table|
  DB.drop_function("#{table}_set_searchable_text".to_sym)

  DB.run <<-SQL
    CREATE FUNCTION #{table}_set_searchable_text() RETURNS trigger AS $$
    BEGIN
      new.searchable_text :=
        setweight(to_tsvector('pg_catalog.english', new.name), 'A') ||
        setweight(to_tsvector('pg_catalog.english', new.description), 'B');
      RETURN new;
    END
    $$ LANGUAGE plpgsql;

    CREATE TRIGGER #{table}_set_searchable_text BEFORE INSERT OR UPDATE
      ON #{table} FOR EACH ROW EXECUTE PROCEDURE #{table}_set_searchable_text();
  SQL
end

artist_ids = DB[:artists].multi_insert(
  25.times.map {
    {
      name:        Faker::Name.name,
      description: Faker::Hipster.paragraph,
    }
  },
  return: :primary_key
)

album_ids = DB[:albums].multi_insert(
  artist_ids.map { |artist_id|
    10.times.map {
      {
        artist_id:    artist_id,
        name:         Faker::Lorem.sentence,
        description:  Faker::Hipster.paragraph,
        track_count:  (8..14).to_a.sample,
        high_quality: rand > 0.7,
        release_date: Date.today - (rand * 5 * 365).round,
        money_made:   (rand * 100000000).round(2),
      }
    }
  }.flatten(1),
  return: :primary_key
)

track_ids = DB[:tracks].multi_insert(
  album_ids.map { |album_id|
    10.times.map {
      {
        album_id:    album_id,
        name:        Faker::Lorem.sentence,
        description: Faker::Hipster.paragraph,
      }
    }
  }.flatten(1),
  return: :primary_key
)

class Artist < Sequel::Model
  one_to_many :albums
end

class Album < Sequel::Model
  many_to_one :artist
  one_to_many :tracks
end

class Track < Sequel::Model
  many_to_one :album
end

class SequelFTSSpec < Minitest::Spec
  include Minitest::Hooks

  make_my_diffs_pretty!

  def around
    DB.transaction(rollback: :always, savepoint: true, auto_savepoint: true) { super }
  end
end
