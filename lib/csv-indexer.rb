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
                
            end # def index
        end



    end # module CSVIndexer
end # module BlackStack