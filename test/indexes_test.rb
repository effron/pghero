require_relative "test_helper"

class IndexesTest < Minitest::Test
  def test_index_hit_rate
    database.index_hit_rate
    assert true
  end

  def test_index_caching
    assert database.index_caching
  end

  def test_index_usage
    assert database.index_usage
  end

  def test_missing_indexes
    assert database.missing_indexes
  end

  def test_unused_indexes
    assert database.unused_indexes
  end

  def test_reset_stats
    assert database.reset_stats
  end

  def test_last_stats_reset_time
    database.last_stats_reset_time
    assert true
  end

  def test_invalid_indexes
    assert_equal [], database.invalid_indexes
  end

  def test_indexes
    assert database.indexes.find { |i| i[:name] == "cities_pkey" }
  end

  def test_duplicate_indexes
    duplicate = database.duplicate_indexes.find { |i| i[:unneeded_index][:name] == "index_cities_on_name_copy" }
    assert duplicate
    assert_equal "index_cities_on_name", duplicate[:covering_index][:name]
    assert database.duplicate_indexes.find { |i| i[:unneeded_index][:name] == "index_users_on_zip_code_including_email_copy" }
    duplicate = database.duplicate_indexes.find { |i| i[:unneeded_index][:name] == "index_users_on_id" }
    assert duplicate
    assert_equal "users_pkey", duplicate[:covering_index][:name]
    refute database.duplicate_indexes.find { |i| i[:unneeded_index][:name] == "users_pkey" }
  end

  def test_overlapping_indexes
    overlap = database.overlapping_indexes.find { |i| i[:index][:name] == "index_users_on_city_id" }
    assert overlap
    assert_equal "index_users_on_city_id_and_email", overlap[:overlapping_index][:name]
    refute database.overlapping_indexes.find { |i| i[:index][:name] == "index_users_on_id" }
  end

  def test_duplicate_indexes_require_identical_definitions
    index = {
      schema: "public",
      table: "users",
      name: "index_users_on_email",
      valid: true,
      primary: false,
      unique: false,
      using: "btree",
      columns: ["email"],
      indexprs: nil,
      indpred: nil,
      definition: "CREATE INDEX index_users_on_email ON public.users USING btree (email)"
    }
    definitions = [
      {
        using: "hash",
        definition: "CREATE INDEX index_users_on_email_hash ON public.users USING hash (email)"
      },
      {
        definition: "CREATE INDEX index_users_on_email_desc ON public.users USING btree (email DESC)"
      },
      {
        definition: "CREATE INDEX index_users_on_email_include_id ON public.users USING btree (email) INCLUDE (id)"
      },
      {
        indexprs: "lower(email)",
        definition: "CREATE INDEX index_users_on_lower_email ON public.users USING btree (lower(email))"
      },
      {
        indpred: "(active)",
        definition: "CREATE INDEX index_users_on_email_active ON public.users USING btree (email) WHERE (active)"
      },
      {
        definition: "CREATE INDEX index_users_on_email_text_pattern ON public.users USING btree (email text_pattern_ops)"
      },
      {
        definition: "CREATE INDEX index_users_on_email_collated ON public.users USING btree (email COLLATE \"C\")"
      }
    ]

    definitions.each do |changes|
      other = index.merge(changes).merge(name: "index_users_on_email_copy")
      assert_empty database.duplicate_indexes(indexes: [index, other])
    end
  end

  def test_nonunique_index_can_be_covered_by_a_greater_named_unique_index
    index = {
      schema: "public",
      table: "users",
      name: "index_users_on_email",
      valid: true,
      primary: false,
      unique: false,
      using: "btree",
      columns: ["email"],
      indexprs: nil,
      indpred: nil,
      definition: "CREATE INDEX index_users_on_email ON public.users USING btree (email)"
    }
    unique_index = index.merge(
      name: "z_users_email_unique",
      unique: true,
      definition: "CREATE UNIQUE INDEX z_users_email_unique ON public.users USING btree (email)"
    )

    duplicates = database.duplicate_indexes(indexes: [index, unique_index])
    assert_equal 1, duplicates.size
    assert_equal "index_users_on_email", duplicates.first[:unneeded_index][:name]
    assert_equal "z_users_email_unique", duplicates.first[:covering_index][:name]
  end

  def test_index_bloat
    assert_equal [], database.index_bloat
    assert database.index_bloat(min_size: 0).find { |i| i[:index] == "index_users_on_updated_at" }
  end
end
