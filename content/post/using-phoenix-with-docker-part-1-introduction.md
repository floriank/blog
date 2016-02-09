+++
date = "2016-02-05T12:21:24+01:00"
draft = true
title = "Using phoenix with docker, Part 1: Introduction"
categories = [
    "development"
]
+++

_This is part one of a three part series_: **Part 1** - [Part 2]({{< ref "using-phoenix-with-docker-part-2-implementation.md">}}) - [Part 3]({{< ref "using-phoenix-with-docker-part-3-containerization.md" >}})

A [colleague of mine](https://kholbekj.surge.sh) will not shut up about [this](https://elixir-lang.org).

Working at a company using Ruby for day to day work, Elixir seems pretty appealing. And since I tried out [Haskell](http://learnyouahaskell.com/) some years ago it seems kind of familiar. Especially since I didn't really grasp the advantage of function pipelines and data structures back then. Also, working with PHP was so convenient at the time. I do recommend checking out Haskell at least once in your life, even though it's (visible) presence in modern web development is slim.

Waking up from that hellish nightmare of Magento-based shop systems, I found myself working with Ruby (and Rails) a lot. Ruby is nice enough, but like every nice language it has some major problems of its own, like a missing language specification. Rails on top of it does make rapid development a joy, but its conventions are debatable and I'd argue that for everything good it brought us, it kicked us in the groin somewhere else (Looking at you, Turbolinks).

Rails introduced a lot of structure to web projects (seeing that web frameworks in other languages adopt to the same and or similiar structure), but, as most people I work with tell me these days, _"it's time to move on"_.

So - Elixir will make everything magically better, right? 

Probably not. 

Show me a new "advanced" technology everyone praises, I'll show you at least one developer who is able to screw things up in your project with it. 

A good measure of a new language - to me - therefore would be how strongly you have to stick to the idioms that the language provides to solve your problems. Granted, this requires reflection on one's own side to determine which kind of problems are to be solved. Also, if the technology at hand is the right one to solve them, but that is just me rambling on what programming actually is, beside writing the code.

## Using Phoenix & Elixir

Introduce Elixir. Elixir runs on the [Erlang](https://www.wikiwand.com/en/Erlang_(programming_language)) VM called BEAM. Being almost as old as myself (the first version of it was released in 1986), it's one of the pieces of software that have been around so long it's practically optimized to a degree that no recently created project is able to attain.

The fans usually pull out the [WhatsApp example here](http://www.wired.com/2015/09/whatsapp-serves-900-million-users-50-engineers/). On one hand this has to do with the Erlang VM being extremly well optimized and well maintained. On the other hand the [network stack of FreeBSD](https://www.quora.com/How-is-FreeBSDs-network-stack-superior-to-that-of-Linux) is a beast by itself. I confess I never looked into it, but I hear the praise from over the hills.

Using Erlang is a good idea apparently and Elixir makes it easier, because it packages it all in a more Ruby-esque, more "friendly" syntax. We can relate and do the same thing we always do - building our applications. Can't be that different from the JVM, can it now? We got used to [jRuby](https://jruby.org) and I think that one guy in the basement is still using and maintaining his own fork of [IronRuby](https://ironruby.net). He also doesn't shave anymore.

Except we cannot - since Elixirs concepts are vastly different from what Ruby can provide you with. And you should keep that in mind - especially when starting out. I highly recommend [Dave Thomas' book here](https://pragprog.com/book/elixir12/programming-elixir-1-2) to start learning Elixir.

But since we're doing web development, let's take a look at [Phoenix](http://phoenixframework.org) - the "Rails of the Elixir" world. It promises to bring the joy Rails development (and the useful conventions that come with it) and eliminating some of the more inconvient Rails-isms.

## Using docker

Before diving into preparing a demo project let me quickly express that I find deployment of Phoenix/Elixir somewhat inconvenient. With Rails, you just use [Heroku](https://heroku.com). That can be hard on your budget though (or on your mental health, as the Asset pipeline made your slug size explode again). So you might go on and deploy on your own machines, deciding to hire a DevOps guy in the process and then silently weep how hard actual scalable deployment is and that it shouldn't come as an afterthought.

At the time of writing, Elixir has less convenient options (from what I can tell), so a containerization might be a solution to this problem. After all, this approach will shift responsibility for having the dependencies installed to you instead of relying on your administrator to do so.

**Note**: I am aware that Heroku supports Elixir these days. I have not tried it yet, but my assumption is that not everyone chooses the expensive and convenient lock-in that Heroku provides.

So, I think it would be reasonable to try out some containers for the time being.

## Project Kitteh Uploader

So, let us prepare something cat related to containerize and deply somewhere.

**Note**: If you have not worked with Phoenix before, there are [some excellent tutorials](https://blog.codecentric.de/en/2016/01/elixir-phoenix-couchdb-introduction/), as [well as documentation](http://hexdocs.pm/phoenix/Phoenix.html). Naming can be a bit confusing, but when you're used to the gem names in the Ruby ecosystem, my best bet is that you can take it.

Let's do it:

```bash
mix phonix.new kitteh && cd kitteh
```

The project will do the following:

1. Let the user upload a picture of a cat
2. Present the user with a short, descriptive URL that they can share and that stays fixed forever(tm)
3. Provide modifiers to the url to scale the image (`Tiny`, `Large`, `Monstrous`), being scaled to (`90x90`, `300x300`, `600x600`) - yes, quadratic.

So, in practise, this should look as follows:

1. User comes to url, uploads an image and get's redirected to `/CuteDomesticSavannahKitteh`
2. User can now use `/TinyCuteDomesticSavannahKitteh`, `/LargeCuteDomesticSavannahKitteh` and `/MonstrousCuteDomesticSavannahKitteh` to get the resized versions as well.

**Please note** that I am intentionally - and shamelessly - stealing the URL naming strategy from [gfycat](https://gfycat.com/).

The project should work as a tech demo to provide and explain the following components:

- the user frontend (web application)
- data storage for images and their properties
- serving images in a somewhat efficient way
- a queue solution with job workers

The project can be grabbed from [its repository](https://github.com/floriank/kitteh-phoenix) if you are interested.

Long story short: We're going to use these containers:

- PostgreSQL for database
- PostgreSQL for database persistance
- Web Container running our Phoenix application
- Queue container running our Phoenix application to process the thumbnails

This is a minimal setup and one could toy around using `nginx` for serving the images, but let's keep it simpler for now.

## Continuing

[In the next part]({{< ref "using-phoenix-with-docker-part-2-implementation.md" >}}), we'll look into the application stack and discuss Phoenix a bit more in depth. If you are more impatient, consider [skipping directly to part 3]({{< ref "using-phoenix-with-docker-part-3-containerization.md" >}}) to see how the `Dockerfile`s of our components look like and what the `docker compose` process will be. Or if it even works.
