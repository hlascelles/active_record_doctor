# frozen_string_literal: true

class ActiveRecordDoctor::Detectors::MismatchedForeignKeyTypeTest < Minitest::Test
  def test_pk_bigint_fk_integer_is_reported
    Context.create_table(:companies, id: :bigint)
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :integer # FK is integer
    end

    expected_message =
      if sqlite?
        "users.company_id is an integer foreign key referencing companies.id (INTEGER). It must be bigint."
      else
        "users.company_id is an integer foreign key referencing companies.id (bigint). It must be bigint."
      end

    assert_problems(expected_message)
  end

  def test_pk_integer_fk_integer_is_reported
    Context.create_table(:companies, id: :integer) # PK is integer
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :integer # FK is integer
    end

    expected_message =
      if sqlite?
        "users.company_id is an integer foreign key referencing companies.id (INTEGER). It should be bigint for future compatibility."
      else
        "users.company_id is an integer foreign key referencing companies.id (integer). It should be bigint for future compatibility."
      end

    assert_problems(expected_message)
  end

  def test_pk_bigint_fk_bigint_is_not_reported
    Context.create_table(:companies, id: :bigint) # PK is bigint
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :bigint # FK is bigint
    end

    refute_problems
  end

  def test_pk_integer_fk_bigint_is_not_reported
    Context.create_table(:companies, id: :integer) # PK is integer
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :bigint # FK is bigint
    end

    refute_problems
  end

  # Test with a non-integer/non-bigint type to ensure it's not flagged by the new logic
  def test_other_types_mismatch_is_not_reported_by_this_specific_logic
    # This test assumes the old behavior for other type mismatches is still desired
    # OR that this detector is now *only* concerned with integer/bigint FKs.
    # Based on the change, it only flags integer FKs.
    # So a smallint PK and integer FK (which was the original test_mismatched_foreign_key_type_is_reported)
    # will now be flagged because the FK is integer.
    Context.create_table(:companies, id: :smallint)
    Context.create_table(:users) do |t|
      # Using type: :int because :integer might resolve to bigint on some systems by default with AR helpers
      # and we want to explicitly test an integer FK.
      t.references :company, foreign_key: true, type: :integer
    end

    expected_message =
      if sqlite?
        "users.company_id is an integer foreign key referencing companies.id (smallint). It should be bigint for future compatibility."
      else
        "users.company_id is an integer foreign key referencing companies.id (smallint). It should be bigint for future compatibility."
      end
    assert_problems(expected_message)
  end


  def test_mismatched_foreign_key_with_non_primary_key_type_is_not_reported_if_fk_is_bigint
    # This test is to ensure that non-PK FKs are not incorrectly flagged if they are bigint.
    # The original test_mismatched_foreign_key_with_non_primary_key_type_is_reported
    # would be problematic if the FK `users.code` was `integer` as it would be flagged.
    # If it's `bigint` (or any other non-integer type), it should pass.
    Context.create_table(:companies, id: :bigint) do |t|
      t.string :code # This will be varchar/character varying
      t.index :code, unique: true
    end
    Context.create_table(:users) do |t|
      t.string :code # Matched type with companies.code
      t.foreign_key :companies, column: :code, primary_key: :code
    end

    refute_problems
  end

   def test_mismatched_foreign_key_with_non_primary_key_type_is_reported_if_fk_is_integer
    Context.create_table(:companies, id: :bigint) do |t|
      t.string :code_pk # PK for this FK relation, type string
      t.index :code_pk, unique: true
    end
    Context.create_table(:users) do |t|
      t.integer :code_fk # FK is integer, PK is string. This should be caught by the "FK is integer" rule.
      t.foreign_key :companies, column: :code_fk, primary_key: :code_pk
    end

    # The referenced type (string) doesn't neatly fit the bigint/integer distinction in the message,
    # so the generic part of the message might be used, or it might be specific.
    # The core is that `users.code_fk` is `integer`.
    fk_type_name = sqlite? ? "INTEGER" : "integer"
    pk_type_name = sqlite? ? "varchar" : "character varying" # Assuming string maps to varchar

    # Based on the new logic, any integer FK is a problem.
    # The message formatting might need adjustment if this specific scenario isn't handled gracefully.
    # The current message structure is:
    # "#{from_table}.#{from_column} is an integer foreign key referencing #{to_table}.#{to_column} (#{to_type}). It should be bigint for future compatibility."
    # OR
    # "#{from_table}.#{from_column} is an integer foreign key referencing #{to_table}.#{to_column} (#{to_type}). It must be bigint."
    # The choice depends on to_type being 'bigint' or not. Here to_type is 'varchar' or 'character varying'.
    # So it should use the "should be bigint for future compatibility"
     expected_message = "users.code_fk is an integer foreign key referencing companies.code_pk (#{pk_type_name}). It should be bigint for future compatibility."

    assert_problems(expected_message)
  end


  def test_config_ignore_tables
    Context.create_table(:companies, id: :bigint)
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :integer # FK is integer, would normally be flagged
    end

    config_file(<<-CONFIG)
      ActiveRecordDoctor.configure do |config|
        config.detector :mismatched_foreign_key_type,
          ignore_tables: ["users"]
      end
    CONFIG

    refute_problems
  end

  def test_global_ignore_tables
    Context.create_table(:companies, id: :bigint)
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :integer # FK is integer
    end

    config_file(<<-CONFIG)
      ActiveRecordDoctor.configure do |config|
        config.global :ignore_tables, ["users"]
      end
    CONFIG

    refute_problems
  end

  def test_config_ignore_columns
    Context.create_table(:companies, id: :bigint)
    Context.create_table(:users) do |t|
      t.references :company, foreign_key: true, type: :integer # FK is integer
    end

    config_file(<<-CONFIG)
      ActiveRecordDoctor.configure do |config|
        config.detector :mismatched_foreign_key_type,
          ignore_columns: ["users.company_id"]
      end
    CONFIG

    refute_problems
  end
end
