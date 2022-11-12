![GitHub issues](https://img.shields.io/github/issues/leandrosardi/csv-indexer) ![GitHub](https://img.shields.io/github/license/leandrosardi/csv-indexer) ![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/leandrosardi/csv-indexer) ![GitHub last commit](https://img.shields.io/github/last-commit/leandrosardi/csv-indexer)

# CSV-Indexer

CSV-Indexer makes it simple the indexation and searching in large CSV files. 

CSV-Indexer is not as robust as Lucence, but it is simple and cost-effective. May index files with millions of rows and find specific rows in matter of seconds.

## 1. Installation

```bash
gem install csv-indexer
```

## 2. Quick Start

**Step 1.** Download a sample CSV file in the same directory where you are running your Ruby script:

```bash
wget https://raw.githubusercontent.com/leandrosardi/csv-indexer/main/examples/example.csv
```

**Step 2.** In your Ruby script, require the `csv-indexer` gem.

```ruby
require 'csv-indexer'
```

**Step 3.** Setup the index for that CSV file.

```ruby
# define the indexation of for `example.csv`
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
    :name => 'ix_example01',
    # Write a brief description of what you are indexing and why.
    # This parameter is optional.
    # Default: nil.
    :description => 'Find the email address and other insights of any LinkedIn user from his/her LinkedIn URL.',
    # The path to the `.csv` file(s) to be indexed.
    # This parameter is optional.
    # Default: './*.csv'
    :input => './example.csv',
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
    :keys => [:linkedin_url],
})
```

**Step 4.** Run the indexation

Add this line to build the index.

```ruby
BlackStack::CSVIndexer.index('ix_example01')
# => 2022-11-09 15:37:46: Indexing example.csv... done
```

**Note:**

For better performance, the `index` method loads the whole file to memory.
So, if you have `csv` files higher than 500MB, it is advisable you split then in chunks using the `split` command.

E.g.:

```bash
split -C 500m --numeric-suffixes input_filename
```

**Step 5.** Searching for a specific LinkedIn URL in your index.

```ruby
ret = BlackStack::CSVIndexer.find('ix_example01', 'linkedin.com/in/almu-dan-9808753a')
puts "#{ret[:matches].size.to_s} results found."
puts "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"
# => 1 results found.
# => Enlapsed seconds: 0.001595287
```

## 3. Indexing Many Files

You can define the indexation of many files. 

E.g.: Replacing `'./example.csv'` by `'./*.csv'`.

```ruby
source = BlackStack::CSVIndexer.add_indexation({
    :name => 'ix_example01',
    :input => './*.csv',
    :mapping => {
        :first_name => 0,
        :last_name => 1,
        :linkedin_url => 2,
        :email => 5,
    },
    :keys => [:linkedin_url],
})
```

## 4. Indexing by Many Columns

You can index by many columns.

E.g.: Replacing `[:linkedin_url]` by `[:first_name, :last_name]`. 

```ruby
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
# => 2022-11-09 16:43:52: Indexing example.csv... done
```

## 5. Searching by Many Columns

If you indexed by more than one column, you can choose one or more of those columns for search.

E.g.: Replacing `'linkedin.com/in/almu-dan-9808753a'` by `['alan', 'armstrong']`.

```ruby
ret = BlackStack::CSVIndexer.find('ix_example02', ['alan', 'armstrong'])
puts "#{ret[:matches].size.to_s} results found."
if ret[:matches].size > 0
    puts "First Name: #{ret[:matches].first[2]}" 
    puts "Last Name: #{ret[:matches].first[3]}" 
    puts "Email: #{ret[:matches].first[5]}" 
end
puts "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"
# => 1 results found.
# => First Name: alan
# => Last Name: armstrong
# => Email: razorback1@plansandmorellp.com
# => Enlapsed seconds: 0.001613454
```

## 6. Key Must Be Unique

At this moment, CSV-Indexer returns no more than 1 result.

If there are two or more rows in your index who match with the criteria, CSV-Indexer will return the first that it founds. 

E.g.: If you remove the `'armstrong'`, you get another Alan.

```ruby
ret = BlackStack::CSVIndexer.find('ix_example02', ['alan'])
puts "#{ret[:matches].size.to_s} results found."
if ret[:matches].size > 0
    puts "First Name: #{ret[:matches].first[2]}" 
    puts "Last Name: #{ret[:matches].first[3]}" 
    puts "Email: #{ret[:matches].first[5]}" 
end
puts "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"
# => 1 results found.
# => First Name: alan
# => Last Name: kane
# => Email: akane@myalexandertoyota.com
# => Enlapsed seconds: 0.001480246
```

## 7. Case Insensitive

CSV-Indexer is case-insensitive.

E.g.: `['alan', 'armstrong']` is the same than `['Alan', 'Armstrong']`.

```ruby
ret = BlackStack::CSVIndexer.find('ix_example02', ['Alan', 'Armstrong'])
puts "#{ret[:matches].size.to_s} results found."
if ret[:matches].size > 0
    puts "First Name: #{ret[:matches].first[2]}" 
    puts "Last Name: #{ret[:matches].first[3]}" 
    puts "Email: #{ret[:matches].first[5]}" 
end
puts "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"
# => 1 results found.
# => First Name: alan
# => Last Name: armstrong
# => Email: razorback1@plansandmorellp.com
# => Enlapsed seconds: 0.001613454
```

## 8. Matching Criteria

You can find values who match partially with the key.  

E.g: `['Ala', 'Armstrong']` works the same than `['Alan', 'Armstrong']` if you add a thirth parameter `exact_match=false`

```ruby
ret = BlackStack::CSVIndexer.find('ix_example02', ['Ala', 'Armstrong'], exact_match=false)
puts "#{ret[:matches].size.to_s} results found."
if ret[:matches].size > 0
    puts "First Name: #{ret[:matches].first[2]}" 
    puts "Last Name: #{ret[:matches].first[3]}" 
    puts "Email: #{ret[:matches].first[5]}" 
end
puts "Enlapsed seconds: #{ret[:enlapsed_seconds].to_s}"
# => 1 results found.
# => First Name: alan
# => Last Name: armstrong
# => Email: razorback1@plansandmorellp.com
# => Enlapsed seconds: 0.001595377
```


