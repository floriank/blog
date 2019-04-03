+++
categories = ["development"]
title = "Moving on from postgres_fdw"
draft = true
date = "2019-04-03T09:30:30+01:00"
+++

# Revising the things you have done

I sometimes go back and look at old code - it's a mostly cathartic, as it brings one back down to earth. As software developers we have a certain aptitude for documenting our code in tests (or actual self-documenting API specifications, e.g. using GraphQL), but we omit the power of documenting the decision making behind it.

I am no exception to this - which is why I look at old code like an interesting puzzle and try to reason with my past self about what he has been thinking during that time. It sure makes for a lot of WTF-moments, but it also shows that one has (hopefully) grown a bit.

# Listening to others

I wrote the post "[The steel industry, file_fdw and the synchronisation of data]({{<ref "the-steel-industry-file_fdw-and-postgres.md">}})" in the full self-belief that I had an absolute solution to a very hard problem.

And at the time, it was good.

I wrote the post accompanying a talk I gave at a meet up of the [most excellent Elixir Berlin group](https://www.meetup.com/Elixir-Berlin/). I think I might have even apologized for focusing more on databases than on Elixir in this one.

As is customary, I gave the word to the crowd to ask questions - and I had a developer (with magnificently flowing, long hair) stand up amidst the group, pointing out the following:

  * I should absolutely partake in the meetings of the local PostgreSQL user group
  * Why could I not just execute `COPY` directly instead of keeping `file_fdw` around for creating the foreign tables?

My reaction to the first one: Yes.

My reaction to the second one: Ye...but, erm. Drowning in the rush of endorphines after entertaining a group of people for forty minutes, I think, in retrospect, I might have been dismissive.

I should not have been.

# The more experience you have ...

As I grow as a developer, I accumulate more knowledge about my work and about relationships to others. I also grow more ignorant in certain aspects. Thankfully, I also become more aware of what little I know about stuff. [Impostor syndrome](https://www.wikiwand.com/en/Impostor_syndrome) is something I see a lot in myself and I see in a ton of candidates when interviewing, but this post is not about the impostor I might feel like (as there are a plethora of blog posts you can read about that).

I consider myself a technology leader - this post therefore needs to aim at what it means reflecting from a higher position, specifically dismissing points by people you might perceive as less smart or experienced. How you see errors in your own behavior before throwing out potential solutions might save you money some day. This is a common error I also see in some old school managers that straight up refuse feedback or a view too different from their own, but ranting about them might need a post of its own.

# .. the harder you fall.

What did I miss completely in just flat out dismissing the opinion of the developer?

Well, for one thing - that they were __just straight up right about everything__. The argument was for less complexity in a complex system. Consider the things you need do to make my initial setup work:

  * setup a database (container)
    - that needs access to the CSV files
    - that need to run PostgreSQL with the `postgres_fdw` extension
  * setup an application (container)
    - that needs access to the timestamp lock file, next to the CSVs

Consider what you need to do it with PostgreSQLs `COPY` statement:

  * a PostgreSQL database
  * an application
    - that needs access to the file system hosting the CSV and the timestamp file

Can you see the difference?

The main error I made was that I only considered my own position. Had I acted with empathy (and common sense), I might have realized that almost no one in the world hosts their own databases. Since Heroku has been around for a while now and with companies such as Google offering cloud-based versions of PostgreSQL, not even my own team hosts their own database anymore!

Also, less dependencies should be viewed as "less liabilities", instead of "more freedom" to manage!

Fudge.

# The problem

Cloud-based PostgreSQL comes with a ton of goodies, namely that you can skip all the configuration and scaling issues.

It also does not provide any extensions. Extensions you might want, like, let's say `postgres_fdw`. In short, if you want to go with the `postgres_fdw` based solution, you cannot make the original solution work on a cloud provider, as you have no option to enable the extension - and you also have no way to make the database aware of the files.

And you better think fast of a solution, as your company wants to make a run for the cloud, as it's the future<sup>tm</sup>!

# What to do now?

Well, let's revisit the suggestion with the [`COPY`](https://www.postgresql.org/docs/11/sql-copy.html) statement:

> COPY moves data between PostgreSQL tables and standard file-system files. COPY TO copies the contents of a table to a file, while COPY FROM copies data from a file to a table (appending the data to whatever is in the table already). COPY TO can also copy the results of a SELECT query.

Awesome, but we used that strategy with `file_fdw` as well. Consider this migration:

```elixir
defmodule SynchronizeApp.Repo.Migrations.AddForeignCompaniesTable do
  use Ecto.Migration
  @up ~s"""
    CREATE FOREIGN TABLE external_companies (
      company_id text,
      -- ...
    ) SERVER file_server
    OPTIONS ( filename '/files/Company.csv', format 'csv', delimiter '|', header 'on', quote E'\x01');
  """
# [...]
```

We used the foreign table specification to tell PostgreSQL how to form a table based off of a CSV file. That meant that the database itself needed to know about the file and it's structure, making migrations hard and causing other fun headaches at runtime when another process touches the files.

But we can use all of the magic with PostgreSQLs `COPY` statement.

# The magic of STDIN

`COPY` supports a `... FROM STDIN` syntax that is documented as follows:

> Specifies that input comes from the client application.

Cool, so what would that look like?

```
COPY animals (
  species,
  name,
  chip_id
) FROM STDIN (FORMAT csv, HEADER TRUE, DELIMITER '|', NULL '', quote E'\x01')
```

Of course, we imagine a data source that is similarly shaped as the example from the original post:

```sql
species|name|chip_id
dog|Snuffles|4553-1338
cat|Archibald "The Paw"|999-9993
guinea|Porkchop|1337-9112
```
As you might now, encountering RFC-compliant CSV in the wild is rare, so we go with a nonstandard example.

Things to look out for:

  * `COPY` is very strict when it comes to order: the column definition in the statement needs to match the columns in the file
  * Your statement will blow up in your face when it encounters an error
  * The statement `HEADER TRUE` will literally just skip the first row
  * `STDIN` can be fed from your application code directly

# Feeding data into STDIN

So far, this is not really existing as it will not help us sitting on a [big ol' Elixir application](https://github.com/floriank/postgres_sync_file_fdw), as we have no way of actually feeding the `STDIN` here efficiently. And rewriting everything from scratch might not be the thing you feel like doing (unless you find yourself with unlimited resources and time).

The way we can make this work is by combing the SQL statement from above with something called "streams" in Elixir. If you have never heard about streams, it's time [to read up on them](https://elixir-lang.org/getting-started/enumerables-and-streams.html). For now, if you don't have the time, think of `Stream` as a lazily operating `Enum`.

there is a really nice article over at [poeticoding](https://www.poeticoding.com/processing-large-csv-files-with-elixir-streams/) about how one can use streams to process larger CSV files, which is a good read of its own.

Anyway, let's consider a simple CSV reading module:

```elixir
defmodule CSVStreamer do
  def stream(path) do
    path |> File.stream!()
  end
end
```

All this will do is just read a path and open up a stream with the data. We'll not doing anything with that stream yet, so it has just a small cost attached - and we're far away from loading a potentially large CSV into memory.

Now, it turns out, Elixirs `Ecto` library [also supports streaming](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.html#stream/4). It allow us to use a Repo and a statement parametrized  statement to be lazily evaluated:

```elixir
defmodule SQLStreamer do
  alias Ecto.Adapters.SQL
  alias MainApplication.Repo

  def stream(statement) do
    Repo |> SQL.stream(statement)
  end
end
```

Nice, but useless for the moment. We now have a lazy file read and a lazy sql statement executor. What is missing is a good combination of the two. Thankfully, there is [`Enum.into`](https://hexdocs.pm/elixir/Enum.html#into/2), which can combine the two. As the docs say:

> Inserts the given enumerable into a collectable.

That means, if we have two streams, we can effectively combine the out of one into the input of the other:

```elixir
defmodule Combiner do
  @path "/files/animals.csv"
  @copy_sql """
    COPY animals (
      species,
      name,
      chip_id
    ) FROM STDIN (FORMAT csv, HEADER TRUE, DELIMITER '|', NULL '', quote E'\x01')
  """
  def combine do
    file_stream = CSVStreamer.stream(@path)
    sql_stream = SQLStreamer.stream(@copy_sql)

    file_stream |> Enum.into(sql_stream)
  end
end
```

And that's it! It will spectacularly fail: Ecto wants a transaction for things like this in order to work, so we will oblige here:

```elixir
defmodule Combiner do
  alias MainApplication.Repo
  @path "/files/animals.csv"
  @copy_sql """
    COPY animals (
      species,
      name,
      chip_id
    ) FROM STDIN (FORMAT csv, HEADER TRUE, DELIMITER '|', NULL '', quote E'\x01')
  """
  def combine do
    file_stream = CSVStreamer.stream(@path)
    sql_stream = SQLStreamer.stream(@copy_sql)

    Repo.transaction(fn ->
      file_stream |> Enum.into(sql_stream)
    end)
  end
end
```

If you check out the `animals table` after executing `Combiner.combine/0` you will find the data from the CSV in the table!

__Success__!

Now, you will also find that the data will be appended each time you execute the function, which is probably what you don't want. the original functionality was designed to actually synchronize the table with the data from the CSV. We can achieve that by adding a truncate before running our copy statement:

```elixir
  # [...]
  def combine do
    file_stream = CSVStreamer.stream(@path)
    sql_stream = SQLStreamer.stream(@copy_sql)

    Repo.transaction(fn ->
      Repo.query("TRUNCATE animals;")
      file_stream |> Enum.into(sql_stream)
    end)
  end
```

We can now bind the new function to the original file trigger and it should replace the `file_fdw` based approach completely - we have a full table copy of the data in the CSV.

# What to take from this example

Well, I am glad somebody pointed out my overcomplicated thinking. However, it took a while to see what the benefits could have been. Thankfully, there was a technical solution to this particular problem, which came at the cost of additional time invested.

I compiled a [full repository](https://github.com/floriank/postgres_sync_copy) to see the thing work. I really hope this example demonstrates both an interesting technical detail as well as some insights on what to do as a tech lead in todays software development world.

Lastly, thanks to the unknown developer who called me out.

You da real MVP.
