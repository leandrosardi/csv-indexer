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

            # search the index.
            # return a hash description with the matches, and a brief performance report.
            def find(key, exact_match=true, write_log=true)
                # if key is an array of values, join them into a string.
                key = key.join('') if key.is_a?(Array)

                # build the response.
                ret = {
                    :matches => [],
                }
            
                # define the logger to use
                l = write_log ? self.logger : BlackStack::DummyLogger.new
                        
                # define the source
                source = "#{File.expand_path(self.output)}/*.#{ext})}"

                # start time
                start_time = Time.now
            
                # totals
                total_matches = 0
            
                # searching in the indexed files
                l.log "Search term: #{search.to_s}"
                files = Dir.glob(source)
                n = 0 
                files.each do |file|
                    # get the name of the file from the full path
                    name = file.split('/').last
                    # get the path of the file from the full path
                    path = file.gsub("/#{name}", '')
                    # opening log line
                    l.logs "Searching into #{name}... "
                    # setting boundaries for the binary search
                    i = 0
                    max = `wc -c #{file}`.split(' ').first.to_i
                    middle = ((i + max) / 2).to_i
                    # totals
                    # open file with random access
                    f = File.open(file, 'r')
                    # remember middle variable from the previous iteration
                    prev = -1
                    # binary search
                    while i<max
                        # get the middle of the file
                        middle = ((i + max) / 2).to_i
                        # break if the middle is the same as the previous iteration
                        break if middle==prev
                        # remember the middle in this iteration
                        prev = middle
                        # opening log line
                        l.logs "#{middle}... "
                        # go to the middle of the file
                        f.seek(middle)
                        # read the line
                        # the cursor is at the middle of a line
                        # so, I have to read a second line to get a full line
                        line = f.readline 
                        # most probably I landed in the midle of a line, so I have to get the size of the line where I landed.
                        a = line.split('","')
                        while a.size < 2 # this saves the situation when the cursor is inside the last field where I place the size of the line
                            middle -= 1
                            f.seek(middle)
                            line = f.readline
                            a = line.split('","')
                        end
                        line_size = a.last.gsub('"', '').to_i
                        middle -= line_size-line.size+1
                        # seek and readline again, to get the line from its begining
                        f.seek(middle)
                        line = f.readline
                        # strip the line
                        line.strip!
                        # get the first field of the CSV line
                        fields = CSV.parse_line(line)
                        row_key = fields[0]
                        # compare the first field with the search term
                        if (exact_match.upcase && key == search[:key].upcase) || (!exact_match && row_key =~ /^#{Regexp.escape(key)}.*/i)
                            # found
                            l.logf "found (#{row_key})"
                            ret[:matches] << fields.dup
                            total_matches += 1
                            break
                        else
                            # not found
                            if key < search[:key]
                                # search in the down half
                                i = middle
                            else
                                # search in the up half
                                max = middle
                            end
                            l.logf "not found (#{row_key})"
                        end
                    end
                    # closing the file
                    f.close
                    # closing the log line
                    l.done
                    # increment file counter
                    n += 1
                end
            
                end_time = Time.now
            
                ret[:enlapsed_seconds] = end_time - start_time
                ret[:lines_matched] = total_matches
            
                l.log "Matches: #{total_matches.to_s}"
                l.log "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"

                ret 
            end # def find
        end
    end # module CSVIndexer
end # module BlackStack