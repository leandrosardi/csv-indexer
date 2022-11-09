# CSV Indexer

CSV Indexer makes it simple the indexation and searching in large CSV files. 

CSV Indexer is not as robust as Lucence, but it is simple and cost-effective. May index files with millions of rows and find specific rows in matter of seconds.

## Installation

```bash
gem install csv-indexer
```

## Quick Start

- wget
- require
- setup index
- run indexation
- searchng results

```
leandro@dev2:~/code/csv-indexer/examples$ ruby example01.rb

2022-11-09 15:37:46: Indexing example01.csv... done
1 results found.
Enlapsed seconds: 0.001595287
```

## Indexing Many Files

```
:input=>'./*.csv'
```

## Indexing by Many Columns

## Searching Parameters

- key sensitive
- matching method

