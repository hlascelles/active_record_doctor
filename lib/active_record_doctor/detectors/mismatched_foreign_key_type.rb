# frozen_string_literal: true

require "active_record_doctor/detectors/base"

module ActiveRecordDoctor
  module Detectors
    class MismatchedForeignKeyType < Base # :nodoc:
      @description = "detect foreign key type mismatches"
      @config = {
        ignore_tables: {
          description: "tables whose foreign keys should not be checked",
          global: true
        },
        ignore_columns: {
          description: "foreign keys, written as table.column, that should not be checked"
        }
      }

      private

      def message(from_table:, from_column:, from_type:, to_table:, to_column:, to_type:)
        # rubocop:disable Layout/LineLength
        if from_type == "integer" && to_type == "integer"
          "#{from_table}.#{from_column} is an integer foreign key referencing #{to_table}.#{to_column} (integer). It should be bigint for future compatibility."
        elsif from_type == "integer" && to_type == "bigint"
          "#{from_table}.#{from_column} is an integer foreign key referencing #{to_table}.#{to_column} (bigint). It must be bigint."
        else
          # This case should ideally not be hit if the logic in detect is correct
          "#{from_table}.#{from_column} (type #{from_type}) references #{to_table}.#{to_column} (type #{to_type}). Foreign key should be bigint."
        end
        # rubocop:enable Layout/LineLength
      end

      def detect
        each_table(except: config(:ignore_tables)) do |table|
          each_foreign_key(table) do |foreign_key|
            from_column = column(table, foreign_key.column)

            next if ignored?("#{table}.#{from_column.name}", config(:ignore_columns))

            to_table = foreign_key.to_table
            to_column = column(to_table, foreign_key.primary_key)

            # The desired state is that all FKs are bigint.
            # If from_column (FK) is already bigint, it's fine.
            next if from_column.sql_type == "bigint"

            # If from_column (FK) is integer, it's a problem.
            # The PK type (to_column.sql_type) is included in the message for context.
            if from_column.sql_type == "integer"
              problem!(
                from_table: table,
                from_column: from_column.name,
                from_type: from_column.sql_type,
                to_table: to_table,
                to_column: to_column.name,
                to_type: to_column.sql_type
              )
            end
            # Cases where from_column.sql_type is neither 'bigint' nor 'integer' (e.g. uuid)
            # are not considered a problem by this specific detector's new logic.
            # Also, if PK is `integer` and FK is `bigint` this is fine.
            # If PK is `bigint` and FK is `bigint` this is fine.
          end
        end
      end
    end
  end
end
