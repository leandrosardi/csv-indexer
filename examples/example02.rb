require 'csv-indexer'

# define the indexation of for `example.csv`
source = BlackStack::CSVIndexer.add_indexation({
    :name => 'ix_example02',
    :description => 'Find the email address and other insights of any LinkedIn user from his/her name.',
    :input => './example.csv',
    :output => './',
    :log => './',
    :mapping => {
        :first_name => 0,
        :last_name => 1,
        :linkedin_url => 2,
        :email => 5,
    },
    :keys => [:first_name, :last_name],
})

BlackStack::CSVIndexer.index('ix_example02')

ret = BlackStack::CSVIndexer.find('ix_example02', ['Alan', 'Armstrong'])
puts "#{ret[:matches].size.to_s} results found."
if ret[:matches].size > 0
    puts "First Name: #{ret[:matches].first[2]}" 
    puts "Last Name: #{ret[:matches].first[3]}" 
    puts "Email: #{ret[:matches].first[5]}" 
end
puts "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"
