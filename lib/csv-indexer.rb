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

        def self.find(name, key, exact_match=true, write_log=false)
            i = @indexes.select { |i| i.name = name }.first
            raise 'Index not found.' if i.nil?
            i.find(key, exact_match, write_log)
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
                            begin
                                i += 1
                                fields = []
                                key = []
                                # get the array of fields
                                row = CSV.parse_line(line)
                                # build the key
                                self.keys.each do |k|
                                    colnum = self.mapping[k]
                                    # replace '"' by empty string, and '|' with ','  
                                    key << row[colnum].gsub('"', '').gsub('|', ',')
                                end
                                key = "\"#{key.join('|')}\""
                                # add the key as the first field of the index line
                                fields << key
                                # add the row number as the second field of the index line
                                fields << "\"#{i.to_s}\""
                                # iterate the mapping
                                self.mapping.each do |k, v|
                                    # get the data from the row
                                    # format the field values for the CSV
                                    fields << "\"#{row[v].to_s.gsub('"', '')}\""
                                end
                                # add fields to the array
                                a << fields
                            rescue => e
                                # what to do with this?
                            end
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

            # this method is for internal use only.
            # it is used to search the index file.
            # the end user should not call this method.
            # the end user should use the find method.
            #
            # compare 2 keys.
            # if !exact_match and if each value in key1 is included in the key2, return 0 
            # otherwise, return 0 if equal, -1 if key1 < key2, 1 if key1 > key2
            # this method is used by the binary search.
            # this method should not be used by the user.
            #
            # Example:
            # compare_keys('Century 21', 'Century 21 LLC', false)
            #  => 0
            #
            # Example:
            # compare_keys('Century 21', 'Century 21 LLC', true)
            #  => -1
            # 
            def compare_keys(key1, key2, exact_match=true)
                match = true
                # get the keys as arrays
                a1 = key1 #.split('|')
                a2 = key2 #.split('|')
                # validation: a2.size > a1.size
                raise 'The key2 must has more elements than key1.' if a2.size < a1.size
                # iterate the arrays
                a2.each_with_index do |k, i|
                    match = false if k !~ /^#{Regexp.escape(a1[i].to_s)}/i
                end
                return 0 if match && !exact_match
                # return the result
                # iterate the arrays
                a1.each_with_index do |k, i|
                    # if the keys are different, return the result
                    if k.upcase < a2[i].upcase
                        return 1
                    elsif k.upcase > a2[i].upcase
                        return -1
                    end
                end
                # if the keys are equal, return 0
                return 0
            end

            # search the index.
            # return a hash description with the matches, and a brief performance report.
            def find(key, exact_match=true, write_log=false)
                # if key is an string, convert it into an array of 1 element
                key = [key] if key.is_a?(String)
                # build the response.
                ret = { :matches => [] }
                # define the logger to use
                l = write_log ? self.logger : BlackStack::DummyLogger.new       
                # define the source
                source = "#{File.expand_path(self.output)}/*.#{self.name}"
                # start time
                start_time = Time.now
                # totals
                total_matches = 0
                # searching in the indexed files
                l.log "Search term: #{key.to_s}"
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
                    max = `wc -c '#{file}'`.split(' ').first.to_i
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
                        # processing the line
                        line = ''
                        line_size = 0
                        begin
                            # go to the middle of the file
                            f.seek(middle)
                            # read the line
                            # the cursor is at the middle of a line
                            # so, I have to read a second line to get a full line
                            line = f.readline.encode('UTF-8', :undef => :replace, :invalid => :replace, :replace => " ")
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
                            line = f.readline.encode('UTF-8', :undef => :replace, :invalid => :replace, :replace => " ")
                            # BAD PRACTIVCE PATCH: sometimes the new value of middle (`middle -= line_size-line.size+1`) doesn't hit the starting of the line.
                            while line[0] != '"' 
                                middle -= 1
                                f.seek(middle)
                                line = f.readline.encode('UTF-8', :undef => :replace, :invalid => :replace, :replace => " ")
                            end
                            # strip the line
                            line.strip!
                            # get the first field of the CSV line
                            fields = CSV.parse_line(line)
                            row_key = fields[0].split('|')
                            # compare keys
                            x = compare_keys(key, row_key, exact_match)
                            # compare the first field with the search term
                            if x == 0
                                # found
                                l.logf "found (#{row_key})"
                                ret[:matches] << fields.dup
                                total_matches += 1
                                break
                            else
                                # not found
                                if x == 1
                                    # search in the down half
                                    max = middle
                                else #if x == -1
                                    # search in the up half
                                    i = middle + line.size+1
                                end
                                l.logf "not found (#{row_key})"
                            end
                        rescue => e
                            l.logf "error in line `#{line}`: #{e.to_console}"
                            # change the max, in order to don't repeat the same iteration and exit the loop in the line `break if middle==prev`
                            #i+=1
                            #max+=1
                        end # begin
                    end
                    # closing the file
                    f.close
                    # closing the log line
                    l.done
                    # increment file counter
                    n += 1
                    # tracing log
                    l.log "i: #{i.to_s}"
                    l.log "max: #{max.to_s}"                    
                end
                # end time
                end_time = Time.now
            
                ret[:enlapsed_seconds] = end_time - start_time
                ret[:lines_matched] = total_matches
                ret[:files_processed] = n
            
                l.log "Matches: #{total_matches.to_s}"
                l.log "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"

                ret 
            end # def find

            # basd on the `:mapping` descriptor of the index, decide which position of a `row` is the `key`.
            # return `nil` if the `key` not exists
            def position_of(key)
                ret = self.mapping.to_a.map { |m| m[0].to_s }.index(key.to_s)
                ret.to_s.size > 0 ? ret : nil
            end
        end
    end # module CSVIndexer
end # module BlackStack