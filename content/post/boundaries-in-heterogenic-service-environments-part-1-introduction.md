+++
categories = ["development"]
date = "2016-03-08T19:23:23+01:00"
title = "Boundaries in heterogenic service environments, Part 1: Introduction"
draft = true
+++

_This is part 1 of a multipart series on building services with multiple technologies and having them intercommunicate_:

- **Part 1 - Introduction**
- [Part 2 - Sharing a database!]({{<ref "boundaries-in-heterogenic-service-environments-part-2-sharing-a-database.md">}}) 
- [Part 3 - Event driven!](#)
- [Part 4 - APIs, APIs!](#)
- [Part 5 - Grand finale](#)

# Contents
<!-- MarkdownTOC -->

- [On sounding smart](#on-sounding-smart)
- [Beyond academia](#beyond-academia)
    - [Playing a childhood favourite](#playing-a-childhood-favourite)
    - [What approaches are there?](#what-approaches-are-there)

<!-- /MarkdownTOC -->

<a name="on-sounding-smart"></a>
# On sounding smart

The series' title has a nice ring to it - but what it  means is "How in the world would I integrate multiple application platforms under one service structure?".

Using smart words is fun. But lets aggrandize to this post, shall we?

The question bugs me a lot. After all, having to coordinate many developers raises some questions in Teammanagement. And being the completely socially inept person I am, I try to make right by _everyones_ opinion.

> "So, Java is the best language there is. I mean, at least the JVM..."

> "But Scala is much more beatiful! And I did some great PHP projects in the past! It _has_ evolved after all!"

> "Node.js _is_ the future, right? Right? Guys?"

At a certain team size, these questions stop being of a well-natured, purely academic manner and the team goes on to build a monolithic application, maybe with one or two externalized services that handle ElasticSearch. And all that in Haskell.

At larger team sizes, or even multiple teams you might want to argue that using different technologies for different tasks might be a better idea. Data crunching might be better suited to certain languages. Or you just want to play aroung with something new to maybe improve performance.

<a name="beyond-academia"></a>
# Beyond academia

So, microservices, right? All the cool kids do it! And having that kind of a walled garden should allow us to actually use whatever technology we want within our own service.

But what about actually integrating a bunch of languages and technologies? or even complete environments beyond just using ye olde Apache. These services have to communicate and/or consume each other to work. And someone should deploy that 

Reading through Sam Newmans "[Building microservices](http://shop.oreilly.com/product/0636920033158.do000000000000)", my personal first learning is that what matters is - planning. Well, duh.

It's actually planning the boundaries that define services and then overcoming these boundaries by establishing communication points. After all, our services should be able to integrate with one another.

Newman aptly describes building a swarm of services akin to planning a city, wherein defining certain zones yields different outcomes depending on the zone plan. 

A simulated city. SimCity. Ah, the memories - never put an industrial zone next to a living space.

<a name="playing-a-childhood-favourite"></a>
## Playing a childhood favourite

It's been quite some time, but choosing this metaphor allows us to see two things:

- The need for a ruleset for intercommunication between services
- The needed boundary definition for each of the single services

To use less impressive wording:

- What strategy do we choose and implement for letting our services work together?
- What _are_ the responsibilities of each single service?

Keeping this in mind, let's use an example to actually implement the different strategies in question, using different approaches.

<a name="what-approaches-are-there"></a>
## What approaches are there?

There are three approaches I saw/used so far in production for service communication:

1. The shared database
2. The event driven model
3. The communcation via an internal API 

I cannot stress enought that there will be no silver bullet here. If I learned anything so far - there is drawbacks and advantages in each of these approaches.

We will implement a version for each of these and compare the differences, advantages and disadvantages.

For actual service boundaries, it's hard to be very generic with services in a meaningful way, and building another `UserService` basically helps no one really.

But we can build a variation of the ever present URL shorteners. It's a nice, single purpose use case that can be well understood and reasoned about in finite time. The basic use case is that we want a tool where we input a given URL and get out a generated much shorter URL.

Since we can break apart this application into a service group with a simple user frontend. The service group should contain:

- an API handler
- a short url creator service
- a short url redirect service
- a reporting (logging) tool

An since we're ridiculously polyglot, we'll use a different technology each time we're building a component. Including the frontend. Just kidding. The frontend will be some sort of HTML page, since neither the API definition nor the frontend itself will likely change much.

But keep this in mind: We are not limited to webpages in each of these scenarios.

In total, this should yield 3 times 4 components - 12 components total. 

Let's get to it.

_In [the next part]({{<ref "boundaries-in-heterogenic-service-environments-part-2-sharing-a-database.md">}}), we're looking at the shared database approach_.
