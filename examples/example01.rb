require_relative '../lib/csv-indexer'

# define a new source
source = BlackStack::CSVIndexer.add_indexation({
    # Assign a unique name for this indexation.
    #
    # This parameter is mandatory.
    #
    # Each `.csv` file indexed will be stored in a file with the same name but replaciing `.csv` with the name of this index.
    # For example, if you use `:name => 'my_index'` and you index a file called `my_file.csv`, the index will be stored in a file called `my_file.my_index`.
    #
    # This name must have filename safe characters only. No spaces, no special characters.
    # 
    :name => 'index01',
    # Write a brief description of what you are indexing and why.
    # This parameter is optional.
    # Default: nil.
    :description => 'Find the email address and other insights of any LinkedIn user from his/her LinkedIn URL.',
    # The path to the `.csv` file(s) to be indexed.
    # This parameter is optional.
    # Default: './*.csv'
    :input => './example01.csv',
    # The path to the directory where the index will be stored.
    # This parameter is optional.
    # Default: './'
    :output => './',
    # The path to the directory where the log files will be stored.
    # This parameter is optional.
    # Default: './'
    :log => './',
    # The mapping of the columns in the `.csv` file to be index.
    # This parameter is mandatory.
    :mapping => {
        :first_name => 0,
        :last_name => 1,
        :linkedin_url => 2,
        :email => 5,
    },
    # List column mapped to the index who are used to build the key of the index.
    # This parameter is mandatory.
    :keys => [:linkedin_url, :email],
})

BlackStack::CSVIndexer.index('index01')