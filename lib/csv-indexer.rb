require 'csv'
require 'simple_cloud_logging'

module BlackStack
    module CSVIndexer
        @indexes = []

        def self.indexes
            @indexes
        end

        def self.add_indexation(h)
            @indexes << BlackStack::CSVIndexer::Index.new(h)
        end

        def self.index(name, write_log=true)
            i = @indexes.select { |i| i.name = name }.first
            raise 'Index not found.' if i.nil?
            i.index(write_log)
        end

        # define Index class
        class Index
            attr_accessor :name, :description, :input, :output, :log, :mapping, :keys, :logger
            
            def initialize(h)
                errors = []

                # validate: h is a hash
                raise "The parameter must be a hash." unless h.is_a?(Hash)

                # validate: :name is present
                errors << "The parameter :name is mandatory." unless h.has_key?(:name)

                # validate: :name is a string
                errors << "The parameter :name must be a string." unless h[:name].is_a?(String)

                # validate: if :description is present, it is a string
                errors << "The parameter :description must be a string." if h.has_key?(:description) && !h[:description].is_a?(String)

                # validate: if :input is present, it is a string
                errors << "The parameter :input must be a string." if h.has_key?(:input) && !h[:input].is_a?(String)

                # validate: if :output is present, it is a string
                errors << "The parameter :output must be a string." if h.has_key?(:output) && !h[:output].is_a?(String)

                # validate: if :log is present, it is a string
                errors << "The parameter :log must be a string." if h.has_key?(:log) && !h[:log].is_a?(String)

                # validate: :mapping is present
                errors << "The parameter :mapping is mandatory." unless h.has_key?(:mapping)

                # validate: :mapping is a hash
                errors << "The parameter :mapping must be a hash." unless h[:mapping].is_a?(Hash)

                # validate: :keys is present
                errors << "The parameter :keys is mandatory." unless h.has_key?(:keys)

                # validate: :keys is an array
                errors << "The parameter :keys must be an array." unless h[:keys].is_a?(Array)

                # validate: :name is unique
                errors << "The parameter :name must be unique." if BlackStack::CSVIndexer.indexes.map{|i| i.name}.include?(h[:name])

                # if errors happened, raise an exception
                raise "The following errors happened while creating the index: #{errors.join(', ')}" unless errors.empty?

                # default value for :input
                h[:input] = './*.csv' unless h.has_key?(:input)

                # default value for :output
                h[:output] = './' unless h.has_key?(:output)

                # default value for :log
                h[:log] = './' unless h.has_key?(:log)

                # create the logger
                self.logger = BlackStack::LocalLogger.new("#{h[:log]}/#{h[:name]}.log")

                # set the attributes
                self.name = h[:name]
                self.description = h[:description]
                self.input = h[:input]
                self.output = h[:output]
                self.log = h[:log]
                self.mapping = h[:mapping]
                self.keys = h[:keys]
            end

            # create the index file
            def index(write_log=true)
                # define the logger to use
                l = write_log ? self.logger : BlackStack::DummyLogger.new
                # output file extension
                ext = ".#{self.name}"
                # index the bites
                Dir.glob(input).each do |file|
                    # get the name of the file from the full path
                    name = file.split('/').last
                    # get the path of the file from the full path
                    path = file.gsub("/#{name}", '')
                    # opening log line
                    l.logs "Indexing #{name}... "
                    # get the output filename
                    output_filename = "#{File.expand_path(self.output)}/#{name.gsub(/\.csv$/, ext)}"
                    # if output file exists, skip
                    if File.exists?(output_filename)
                        l.logf "skip"
                    else
                        # open the input file
                        input_file = File.open(file, 'r')
                        # import the bite to the database
                        i = 0
                        a = []
                        # iterate lines if input_file
                        input_file.each_line do |line|
                            i += 1
                            fields = []
                            key = ''
                            # get the array of fields
                            row = CSV.parse_line(line)
                            # build the key
                            self.keys.each do |k|
                                colnum = self.mapping[k]
                                key += row[colnum].gsub('"', '')
                            end
                            key = "\"#{key}\""
                            # add the key as the first field of the index line
                            fields << key
                            # add the row number as the second field of the index line
                            fields << "\"#{i.to_s}\""
                            # iterate the mapping
                            self.mapping.each do |k, v|
                                # get the data from the row
                                # format the field values for the CSV
                                fields << "\"#{row[v].gsub('"', '')}\""
                            end
                            # add fields to the array
                            a << fields
                        end
                        # sort the array
                        a.sort!
                        # get the output file
                        output_file = File.open(output_filename, 'w')
                        size = nil
                        new_size = nil
                        # write the array to the output file
                        a.each do |row|
                            # add the size of the line, in order to be able to do a binary search
                            line = row.join(',')
                            # add the size of the line as a last field of the row.
                            # this value is necessary to run the search.
                            size = line.size
                            new_size = size + 1 + 2 + size.to_s.size # 1 comma, 2 double-quotes, and size of the size
                            new_size += 1 if size.to_s.size < new_size.to_s.size # sum 1 if new_size had 1 more digit than size (e.g. 104 vs 99)
                            size = new_size
                            line += ",\"#{size.to_s}\""
                            output_file.puts line
                        end
                        # close the output file
                        output_file.close
                        # close log
                        l.done
                    end
                end
            end # def index

            # search the index
            def find(key, write_log=true)
            end # def find
        end
    end # module CSVIndexer
end # module BlackStack