class RemoteTable
  class File
    attr_accessor :filename, :format, :delimiter, :skip, :cut, :crop, :sheet, :headers, :schema, :schema_name, :trap
    attr_accessor :encoding
    attr_accessor :path
    attr_accessor :keep_blank_rows
    attr_accessor :row_xpath
    attr_accessor :column_xpath
    
    def initialize(bus)
      @filename = bus[:filename]
      @format = bus[:format] || format_from_filename
      @delimiter = bus[:delimiter]
      @sheet = bus[:sheet] || 0
      @skip = bus[:skip] # rows
      @keep_blank_rows = bus[:keep_blank_rows] || false
      @crop = bus[:crop] # rows
      @cut = bus[:cut]   # columns
      @headers = bus[:headers]
      @schema = bus[:schema]
      @schema_name = bus[:schema_name]
      @trap = bus[:trap]
      @encoding = bus[:encoding] || 'UTF-8'
      @row_xpath = bus[:row_xpath]
      @column_xpath = bus[:column_xpath]
      extend "RemoteTable::#{format.to_s.camelcase}".constantize
    end
    
    def tabulate(path)
      define_fixed_width_schema! if format == :fixed_width and schema.is_a?(Array) # TODO move to generic subclass callback
      self.path = path
      self
    end
    
    private
    
    # doesn't support trap
    def define_fixed_width_schema!
      raise "can't define both schema_name and schema" if !schema_name.blank?
      self.schema_name = "autogenerated_#{filename.gsub(/[^a-z0-9_]/i, '')}".to_sym
      self.trap ||= lambda { true }
      Slither.define schema_name do |d|
        d.rows do |row|
          row.trap(&trap)
          schema.each do |name, width, options|
            if name == 'spacer'
              row.spacer width
            else
              row.column name, width, options
            end
          end
        end
      end
    end
    
    def backup_file!
      FileUtils.cp path, "#{path}.backup"
    end
    
    def skip_rows!
      return unless skip
      RemoteTable.backtick_with_reporting "cat #{path} | tail -n +#{skip + 1} > #{path}.tmp"
      FileUtils.mv "#{path}.tmp", path
    end
    
    def convert_file_to_utf8!
      return if encoding == 'UTF-8' or encoding == 'UTF8'
      RemoteTable.backtick_with_reporting "iconv -c -f #{encoding} -t UTF-8 #{path} > #{path}.tmp", false
      FileUtils.mv "#{path}.tmp", path
    end
    
    def restore_file!
      FileUtils.mv "#{path}.backup", path if ::File.readable? "#{path}.backup"
    end
    
    def cut_columns!
      return unless cut
      RemoteTable.backtick_with_reporting "cat #{path} | cut -c #{cut} > #{path}.tmp"
      FileUtils.mv "#{path}.tmp", path
    end
    
    def crop_rows!
      return unless crop
      RemoteTable.backtick_with_reporting "cat #{path} | tail -n +#{crop.first} | head -n #{crop.last - crop.first + 1} > #{path}.tmp"
      FileUtils.mv "#{path}.tmp", path
    end
    
    def format_from_filename
      extname = ::File.extname(filename).gsub('.', '')
      return :csv if extname.blank?
      format = [ :xls, :ods ].detect { |i| i == extname.to_sym }
      format = :html if extname =~ /\Ahtm/
      format = :csv if format.blank?
      format
    end
  end
end
