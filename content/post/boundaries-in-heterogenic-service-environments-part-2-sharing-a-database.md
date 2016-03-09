+++
categories = ["misc"]
date = "2016-03-08T20:36:36+01:00"
title = "Boundaries in heterogenic service environments, Part 2: Sharing a database"
draft = true
+++

_This is part 2 of a multipart series on building services with multiple technologies and having them intercommunicate_:

- [Part 1 - Introduction]({{<ref "boundaries-in-heterogenic-service-environments-part-1-introduction.md">}}) 
- **Part 2 - Sharing a database!**
- [Part 3 - Event driven!](#)
- [Part 4 - APIs, APIs!](#)
- [Part 5 - Grand finale](#)

# Content

<!-- MarkdownTOC -->

- [Using the database](#using-the-database)

<!-- /MarkdownTOC -->

<a name="using-the-database"></a>
# Using the database

![Shared database architecture](/shared_db.svg)

The most basic of all solutions, sharing a database might be the first idea one has when trying to distribute their systems. It sure was my first idea to split up a monolithic Rails applciation in 2014.
