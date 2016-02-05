+++
date = "2016-02-04T10:33:17+01:00"
draft = false
title = "Working around timing issues in docker compose"
categories = [
    "development"
]
+++

## Containers

I really like the concept of containers. Having been a somewhat avid [vagrant](https://vagrantup.com) user in the past, the speed gain that containers can provide over a virtual machine is a good sell to me. Also, having a very snapshottable environment I can bring up and down with dependencies packed neatly into containers is a plus. If you are reading this article you probably heard the sermon before.

If you did not hear the good word yet - read up on it. There are some good arguments for and against containers and the technology behind is quite interesting.

There are several solutions for containerization out there - most notably [docker](https://docker.io) and [rkt](https://coreos.com/rkt/docs/latest/), both of which are written in Go and can manage containers on Linux, effectively wrapping [LXC](https://www.wikiwand.com/en/LXC).

This post will deal with `docker` and more specifically, `docker compose`.

## Setup

If you're looking at a bigger project you might need multiple containers to run all the software you need. So, you might end up with a sizable list:

- the main platform, e.g. a Rails/Django/<my favourite framework> application
- a database server, e.g. PostgreSQL, Mongo, MySQL, etc.
- some kind of search server, e.g. SOLR, ElasticSearch, ThinkingSphinx
- maybe one or two custom APIs detached from the main application

The situation get's even worse if you decide to go full SOA by having a small fleet of microservices.

Assuming the former setup, you have 4 to 5 docker images that you're now orchestrating to setup your project. How tedious.

Enter [docker compose](https://docs.docker.com/compose/). It's a little tool as part of the `docker` toolkit that enables you to provide a yaml configuration and then starts up all of the containers required for your project with the configuration provided.

And that's great - since you now only need the docker compose config in addition to the actual images (which `docker` will happily pull for you).

To give an example:

```yaml
# the database image
db:
  image: "postgres:9.3"
  ports:
    - "5432:5432"
  environment:
    POSTGRES_USER: florian
    POSTGRES_PASSWORD: 12345
  volumes_from:
    - dbdata

# a second container to be used as a volume for the db
dbdata:
  image: "postgres:9.3"
  volumes:
    - /var/lib/postgres
  command: "true"

# elasticsearch
elasticsearch:
  image: "elasticsearch:2.2"
  ports:
    - "9200"
  volumes_from:
    - elasticsearch_index

# the index has to be persisted somewhere
elasticsearch_index:
  image: "elasticsearch:2.2"
  command: "true"
  volumes:
    - /usr/share/elasticsearch/data

# the main image, this is the application
web:
  image: "company/fancy-rails:2.0"
  command: "bundle exec rails s"
  ports:
    - "3000:3000"
  links:
    - "db:db"
    - "elasticsearch:elasticsearch"
```

This config should not be usable as I made up all of it and `company/fancy-rails:2.0` is not pullable.

Running `docker compose up` should start all of these containers. And if you're lucky, you get a running Rails application with PostgreSQL and ElasticSearch servers at its disposal.

## Timing Problems

Since we're not living in a perfect world, there might be some problems with this approach, most notably timing. 

`docker compose` will resolve your container dependencies for you, but the startup has no mercy for actual dependencies at runtime and will crash if the container you're trying to start crashes itself (to be more precise - if the command you ran crashed).

Let's say that our fancy Rails application requires a connection to the ElasticSearch server to start up. You are likely to end up with a crash of the whole application stack becase ElasticSearch takes longer to boot than the Rails application itself. Your stack will be torn down by `docker compose` before you know what's going on, just because the main container crashed.

There is an ongoing discussion about this problem on [Github](https://github.com/docker/compose/issues/374). So far most solutions revolve around having a custom script wait for the required dependencies to start up and be reachable before actually firing the container command.

## Workaround

I hesitate to call this a solution, but here is my workaround which I used to tackle this problem:

Introduce a shellscript `start.sh` in your application and put the following in there:

```bash
#!/bin/bash
while ! nc -z elasticsearch 9200; do sleep 2; done
bundle exec rails s -b 0.0.0.0
```

You will need to rebuild your image for the file to be part of the container. Also, change the line in the `docker-compose.yml`:

```yaml
web:
  image: "company/fancy-rails:2.0.1"
  command: "sh start.sh"
  ports:
    - "3000:3000"
  links:
    - "db:db"
    - "elasticsearch:elasticsearch"
```

Eseentially, the script uses `netcat` to query the `elasticsearch` host on the required port until it's available. Please note that this workaround is prone to errors as the script might query forever in case the `elasticsearch` container never properly comes up. Afterwards, it's time to boot up the rails server.

**Note**: `docker compose` provides the `elasticsearch` host name conveniently via the `links` attribute so that you do not have to use overly verbose names taken from the environment anymore. In case you were wondering how the web container knows about the ElasticSearch container.

## Conclusion

This is far from a perfect solution. To start off, a counter could be used to abort once the script queried long enough. It's also dependent on `netcat` as part of the container, which might be undesirable if you don't want the extra dependency.

I hope this will help in the future, tackling these issues got me stuck for a little bit on the learning curve.

## Resources

- `docker compose` [Documentation](https://docs.docker.com/compose/)
- [Ongoing discussion on the matter](https://github.com/docker/compose/issues/374)
- [A quick introduction to Linux containers](http://www.smallbusinesscomputing.com/biztools/an-introduction-to-linux-containers.html)
