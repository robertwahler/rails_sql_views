module RailsSqlViews
  module ConnectionAdapters
    module Mysql2Adapter
      REQUIRED_METHODS = [:supports_views?]

      def self.included(base)
        base.class_eval do
          alias_method :structure_dump_without_views, :structure_dump
          alias_method :structure_dump, :structure_dump_with_views

          def self.method_added(method)
            public(method) if REQUIRED_METHODS.include?(method) && !self.public_method_defined?(method)
          end
        end
      end

      # Returns true as this adapter supports views.
      def supports_views?
        true
      end
      
      def base_tables(name = nil) #:nodoc:
        tables = []
        execute("SHOW FULL TABLES WHERE TABLE_TYPE='BASE TABLE'").each{|row| tables << row[0]}
        tables
      end
      alias nonview_tables base_tables
      
      def views(name = nil) #:nodoc:
        views = []
        execute("SHOW FULL TABLES WHERE TABLE_TYPE='VIEW'").each{|row| views << row[0]}
        views
      end

      def tables_with_views_included(name = nil)
        nonview_tables(name) + views(name)
      end
      
      def structure_dump_with_views
        structure = ""
        base_tables.each do |table|
          structure += select_one("SHOW CREATE TABLE #{quote_table_name(table)}")["Create Table"] + ";\n\n"
        end

        views.each do |view|
          _statement = convert_statement(select_one("SHOW CREATE VIEW #{quote_table_name(view)}")["Create View"])
          structure += "CREATE VIEW #{quote_table_name(view)} AS #{_statement};\n\n"
        end

        return structure
      end

      # Get the view select statement for the specified table.
      def view_select_statement(view, name=nil)
        begin
          row = execute("SHOW CREATE VIEW #{view}", name).each do |row|
            return convert_statement(row[1]) if row[0] == view
          end
        rescue ActiveRecord::StatementInvalid => e
          raise "No view called #{view} found"
        end
      end
      
      private
      def convert_statement(s)
        s.gsub!(/.* AS ([(]?select .*)/, '\1')
      end
    end
  end
end
