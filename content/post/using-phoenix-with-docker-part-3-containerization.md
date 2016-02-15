+++
date = "2016-02-15T15:47:39+01:00"
draft = true
title = "Using Phoenix with docker, Part 3: Containerization"
categories = [
  "development"
]
+++

_This is the final part of a three part series_: [Part 1]({{< ref "using-phoenix-with-docker-part-1-introduction.md" >}}) - [Part 2]({{< ref "using-phoenix-with-docker-part-2-implementation.md" >}}) - **Part 3**

__Note__: I am using the latest `docker-compose` and the latest `docker-engine` later on in this post.

# Contents

<!-- MarkdownTOC -->

- [Composition](#composition)
- [Kitteh Dockerfile](#kitteh-dockerfile)
- [Database connections](#database-connections)
- [Tearing it all down](#tearing-it-all-down)
  - [Container structure](#container-structure)
  - [Creating the volume container](#creating-the-volume-container)
  - [Docker 1.10](#docker-110)
  - [Configuring nginx](#configuring-nginx)
  - [Running the containers](#running-the-containers)
  - [Assets and images](#assets-and-images)
- [Looking back](#looking-back)
  - [Cleaning up](#cleaning-up)
- [Conclusion](#conclusion)

<!-- /MarkdownTOC -->

So far, so good. We now have a working application that we want to containerize. At the moment, [the application is feature complete](https://github.com/floriank/kitteh-phoenix/tree/05-resizing-cats), but nothing interesting related to `docker` happened yet.

<a name="composition"></a>
## Composition

Before actually starting with the Dockerfile of our own codebase, let's introduce a [docker compose](https://docs.docker.com/compose/overview/) configuration, which is a YAML file called `docker-compose.yml`:

```yaml
# the database image
db:
  image: "postgres:9.4"
  ports:
    - "5432:5432"
  environment:
    POSTGRES_USER: kitteh
    POSTGRES_PASSWORD: kitteh
  volumes_from:
    - dbdata

# for persistance of database data
dbdata:
  image: "postgres:9.4"
  volumes:
    - /var/lib/postgres
  command: "true"

# the main image, this is the application
web:
  build: "."
  environment:
    MIX_ENV: "prod"
  ports:
    - "4000:4000"
  links:
    - "db:db"
```

This is the naive route to take, we provide a container for the database, using the official postgres image, then use the same image for a db layer to achieve actual persistance by mounting the volumes from it into the first database image.

The application image by itself will not be buildable at the moment since it has no `Dockerfile` yet, so running 

```bash
docker-compose up
```

should pull the database related image, but then crash as the build commend fails. Or it fails as the port cannot be bound to, since you may have a local PostgreSQL instance running:

```bash
Starting kitteh_dbdata_1...
Recreating kitteh_db_1...
Building web...
Cannot locate specified Dockerfile: Dockerfile
```

No matter what, we should think about our applications `Dockerfile`.

<a name="kitteh-dockerfile"></a>
## Kitteh Dockerfile

Remmembering the [section about resizing in part 2](#todo) earlier, we know that we have at least the dependency of ImageMagick besides the actual Erlang VM and OTP to provide. 

What do we have to ensure that our whole system works? Here is a checklist:

- all dependencies must be available as/in containers somehow
- database must be migratable and migrated to a point where it is usable
- ideally, assets are built and served via a separate process

Looking at the checklist, here are the dependencies we have:

- Erlang and OTP
- Elixir, `hex` and `mix`
- ImageMagick
- PostgreSQL
- nginx

For the moment, docker image sizes should not be our concern. My personal preference would be to have the most minimal footprint possible when it comes to the images, but we should focus on getting things working now: 

```bash
FROM ubuntu:14.04.3
# [...]
```

Should be simple enough. Yes, we are using the [Ubuntu image](https://hub.docker.com/_/ubuntu/). I know it's huge (~200MB) and it will become even larger with dependencies - but that should not stop us from using it locally.

Installing the Elixir, OTP and ImageMagick dependencies should be easy, thanks to `apt-get`:

```bash
FROM ubuntu:14.04.3

# Set the locale, otherwise elixir will complain later on
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# wget for convenience, use curl if you want to
RUN apt-get -y -q install wget

# add erlang otp
RUN wget https://packages.erlang-solutions.com/erlang-solutions_1.0_all.deb
RUN dpkg -i erlang-solutions_1.0_all.deb
RUN apt-get update
RUN apt-get install -y -q imagemagick esl-erlang elixir
ADD . /app
WORKDIR /app
RUN mix local.hex --force
RUN mix deps.get --only-prod
RUN mix compile
CMD ["mix", "phoenix.server"]
```

Okay, not _straight_ forward, but at least simple - it's quite a lot of stuff to pack into the image. In the end it will be around ~500MB in size. It's not too bad, considering a lot of layers can be reused later on, but it's quite much, especially if you want to upload it to a hub.

Well, running it in combination with `docker-compose` should now yield results:

```bash
docker-compose up
Starting d239c7b138_kitteh_dbdata_1...
kitteh_db_1 is up-to-date
Recreating kitteh_web_1...
Attaching to d239c7b138_kitteh_dbdata_1, kitteh_db_1, kitteh_web_1
db_1     | LOG:  database system was shut down at 2016-02-13 18:34:32 UTC
db_1     | LOG:  MultiXact member wraparound protections are now enabled
db_1     | LOG:  database system is ready to accept connections
db_1     | LOG:  autovacuum launcher started
db_1     | LOG:  received smart shutdown request
db_1     | LOG:  autovacuum launcher shutting down
db_1     | LOG:  shutting down
db_1     | LOG:  database system is shut down
db_1     | LOG:  database system was shut down at 2016-02-13 18:43:57 UTC
db_1     | LOG:  MultiXact member wraparound protections are now enabled
db_1     | LOG:  autovacuum launcher started
db_1     | LOG:  database system is ready to accept connections
db_1     | LOG:  received smart shutdown request
db_1     | LOG:  autovacuum launcher shutting down
db_1     | LOG:  shutting down
db_1     | LOG:  database system is shut down
db_1     | LOG:  database system was shut down at 2016-02-13 18:50:18 UTC
db_1     | LOG:  MultiXact member wraparound protections are now enabled
db_1     | LOG:  autovacuum launcher started
db_1     | LOG:  database system is ready to accept connections
web_1    | [info] Running Kitteh.Endpoint with Cowboy on http://localhost:4000
web_1    | [error] Could not start watcher because "node" is not available. Your Phoenix application is still running, however assets...
```

We forgot assets. We'll deal with it down the road. For now, visisting your [localhost](http://localhost:4000) should yield the original web application we created earlier - at least it's first page.

Uploading shouldn't work - there is no migrated database yet and you should get a connection error when trying to upload a picture.

If you are to lazy to create your own `Dockerfile`, please see the tag `06-dockerizing-kitties` [here](https://github.com/floriank/kitteh-phoenix/tree/06-dockerizing-kitties).

<a name="database-connections"></a>
## Database connections

We should see if we can make the database work.

The database images used at the moment utilize [the official postgres image](https://hub.docker.com/_/postgres/). The `docker-compose.yml` file will set environment variables that should correspond to the values in your local `prod.secret.exs` file. 

__Tip__: Read environment variables into that configuration like this:

```elixir
# ./config/prod.secret.exs
# [...]
# Configure your database
config :kitteh, Kitteh.Repo,
  adapter: Ecto.Adapters.Postgres,
  hostname: "db", # see the links section in docker-compose.yml for the name
  username: System.get_env("DB_USER")
  password: System.get_env("DB_PASSWORD"),
  database: "kitteh_prod",
  pool_size: 20
```

For our use case this can stay hard coded as this file is [not checked into git anyway](https://github.com/floriank/kitteh-phoenix/blob/06-dockerizing-kitties/.gitignore#L28). It might be different if one would choose to utilize a CI.

However, making sure that the database is reachable is key, since we need to migrate it (the database image actually already contains a database named after the environment [variable set here](https://github.com/floriank/kitteh-phoenix/blob/06-dockerizing-kitties/docker-compose.yml#L7) - come to think of it, it should probably [be the same as in the configuration](https://github.com/floriank/kitteh-phoenix/commit/07146c2b2c0a141d98ca821856802dacf7a7b075))

__Note__: I encountered some problems when trying to use the `$POSTGRES_DB` variable. for some reason it always fell back to the `$POSTGRES_USER`. I have not yet figured out why. These problems _only_ occured while using the version 1 of the compose configuration.

Long story short, if we run 

```bash
# use -d for detached mode
docker-compose up
```

we can attach to the running docker container using `exec` like this:

```bash
# container name may vary
docker exec -it kitteh_web_1 /bin/bash
```

or 

```bash
docker-compose run web /bin/bash
```

and then run

```bash
# add MIX_ENV=prod if you did not change the docker-compos.yml entry
mix ecto.migrate
```

inside the container to finally migrate the database. If this fails, try to make sure that `$MIX_ENV` is set to `prod` in the environment.

If we now try to upload a picture again, it _should_ work. You can of course always run migrations using

```
docker-compose run web mix ecto.migrate
```

directly.

<a name="tearing-it-all-down"></a>
## Tearing it all down

If we restart our composition, we should take note that our database data should have been persisted. But if we reload the image url we just generated, the image will be gone, as the actual images are not persisted in the container.

Since we ignored assets completely so far, it's now time to give this a more serious thought.

First, we add an `nginx` entry to our `docker-compose.yml` (I chose the [official image](https://hub.docker.com/_/nginx/)):

```yaml
# [...]
nginx:
  image: "nginx:1.9.11"
  # [...]
  # now what?
```

<a name="container-structure"></a>
### Container structure

Let's talk about the basic idea first:

We'll use a data volume container that can be used by both the not-yet-existing `nginx` container, as well as the existing `web` container. The `web`container will write to the data volume container, the `nginx` container will read the data and serve it appropiately. With this, we can individually backup the data container if we wanted to and the data is persisted.

Here is the checklist:

1. Create a data container with volumes for both `web` and `nginx` containers.
2. Mount volumes into both containers
3. Create an `nginx` container that has a site config for serving the contents of the volume mounted

<a name="creating-the-volume-container"></a>
### Creating the volume container

Before we add our container, we should reevaluate where exactly we want to store our images. 

Inside the container, the current `uploads` folder resides within `_build/prod/lib/kitteh/priv/static/uploads`. That's quite a handful to type.

So let's change that first. Luckily, we only have to change the `target_path` function in the `page_controller.ex`:

```elixir
# ./web/controllers/page_controller.ex
# [...]
  defp target_path do
    if Mix.env == :prod do
      "/var/uploads/"
    else
      Application.app_dir(:kitteh, "priv") <> "/static/uploads/"
    end
  end
```

We'll create another container in our `docker-compose.yml` that is built from scratch:

```yaml
# [...]
assets:
  image: "busybox"
  volumes:
    - /var/uploads
  command: "true"
```

If everything went well, the images should be preserved between container restarts.

We can now create an nginx docker image. We're going to use a custom Dockerfile to do so - we can store it alongside the codebase.

<a name="docker-110"></a>
### Docker 1.10

This is where things get interesting - Docker [was recently updated to v1.10.0](https://blog.docker.com/2016/02/docker-1-10/) - and along with it came an update to `docker-compose` with a new version of the syntax, allowing for custom dockerfile directives in the `build` object of the configuration.

I decided to give it a spin. At this point you'll have to upgrade as well, otherwise you cannot use the version 2 of the configuration syntax.

__Note__: If you do not want to upgrade, you can always build yourself a local image using the `Dockerfile.nginx` and update the version 1 `docker-compose.yml` accordingly.

The updated configuration can be found [in this commit](https://github.com/floriank/kitteh-phoenix/commit/f8188c8130a61f2131dc843982d23e1f30e1eb6f).

<a name="configuring-nginx"></a>
### Configuring nginx

I went with a super simple [nginx configuration file](https://github.com/floriank/kitteh-phoenix/commit/080baab1abe78f2d3f508c0b3eede7c6182a0d09), which is bogus, but should work nonetheless.

<a name="running-the-containers"></a>
### Running the containers

A simple 

```
docker-compose up
```

should bring up our creation. I also tagged [this point of development for your convenience if you do not wish to code along](https://github.com/floriank/kitteh-phoenix/tree/07-composing-kittehs).

<a name="assets-and-images"></a>
### Assets and images

Wait, what about assets? We still get something along the lines of

```bash
[error] Could not find static manifest at "/app/_build/prod/lib/kitteh/priv/static/manifest.json". Run "mix phoenix.digest" after building your static files or remove the configuration from "config/prod.exs."
```

in the logs.

And what about actually serving the images? With out current setup, the `nginx` will use the mounted volume under its own `/var/uploads` to serve the content of this volume. Running

```bash
docker-compose run nginx ls -l /var/uploads
```

should yield a list of images. The `nginx` container itself is exposed at port `4001` - thanks to the [configuration yaml](https://github.com/floriank/kitteh-phoenix/blob/080baab1abe78f2d3f508c0b3eede7c6182a0d09/docker-compose.yml#L24). 

So, assuming a file named `LargeSuperbYellowTurkishAngora.jpeg` actually exists in the data container a simple 

```
http get http://localhost:4001/LargeSuperbYellowTurkishAngora.jpeg
```

should give the image back to you. If you are not using [httpie](https://github.com/jkbrzt/httpie) yet, I do recommend it!

So, for now, we can use this and modify our code, specifically the view that renders the image url (called `asset_url`):

```elixir
# /web/views/page_view.ex
  def asset_url(image) do
    "/img/" <> image.token
  end
```

One of the drawbacks of not having an asset pipeline similar to Rails is that we cannot specify an integrated asset host (that is **not** completely true, as we can easily just reuse an `Application` or environment variable for that). However, it's not as simple as just changeing `config.host` in your `production.rb`, as the pipeline is not entangled with the framework.

But that will not stop us, even if it means hardcoding values:

```elixir
# /web/views/page_view.ex
  def asset_url(image)
    "http://localhost:4001/" <> Path.basename(image.path)
  end
```

In a production environment, I would probably assign a real subdomain name, like "images.kitt.eh" or something along these lines.

Rebuilding and restarting the containers should now present the very same image, but served from the nginx container.

__Note__: At this point I noticed a flaw in the `Dockerfile` for the main application - Compilation was not done properly, so I had to reintroduce an env variable to [mark production compilation](https://github.com/floriank/kitteh-phoenix/commit/362cb0eae4553c418b4729822429a3d324959cc7).

#### Assets
  
Phoenix purposefully does not integrate an asset pipeline and instead delegates to a library called `brunch` (see [brunch.io](https://brunch.io)) to handle static assets like JavaScript and CSS.

I personally disagree with the choice of brunch - I'd have used webpack myself, but one cannot be too picky when others provide work that is essentially free.

Anyway, we have different options for solving the assets problem domain:

1. Reusing the nginx container (and having the assets land on "image.kitt.eh")
2. Introducing a second nginx container (and introducing "assets.kitt.eh" in proudction)
3. <s>Serve everything via the web stack.</s>
4. Serve everything via a CDN.

I am not really going to talk about option number 4. Using a CDN (like Cloudfront) is usually the way to go with bigger production setups as you just cannot match the server infrastructure that is provided to you via these services.

I am inclined to use option number 2. Assets and images should be different in my opinion and - and that is even more crucial to me - updating the assets should not affect the data within the uploads container. Depending on your requirements, option 3 should also be a very possible solution.

However, let's introduce a third `Dockerfile`, called `Dockerfile.assets` (we also rename the existing `Dockerfile.nginx` to `Dockerfile.uploads`):

```Dockerfile
FROM nginx:1.9.11
# override the default nginx config with our own
ADD nginx.assets.conf /etc/nginx/nginx.conf
RUN mkdir /logs
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

It's essentially the same one as for uploads. The `nginx.conf` looks similar as well, but defines proper mimetypes for all the sublocations (css & js).

I [also updated](https://github.com/floriank/kitteh-phoenix/commit/fa45cac9807a841911bd3d691cdf031fbe50042b) the `docker-compose.yml` accordingly to include the second nginx to serve assets later on.

We run into a problem here: so far we just assumend that all the assets are there, ready to go - however, we cannot run `brunch build --production`, as this is an `npm` dependency. Up until now, we just assumed it was there, as we had it installed anyway. However, a fresh clone of the repo cannot assume that. To keep it a bit shorter, I will omit the steps necessary to make this work, but to give you an idea, here are the options you'd have:

1. Install `nodejs` in the web container (bloating it even more) and then run `npm install` in it (bloating it even more). This might be an option if you want everything self-contained and ready to go after cloning the repo
2. Live with it and require the user (or a CI for that matter) to have node installed on their system when building the image

I chose option 2 for this exercise and [documented it in the README](https://github.com/floriank/kitteh-phoenix/commit/12c83f235321ae172259072cab8f85012c2cb3a1).

Unfortunately, I found digesting all the assets and then putting them into `/var/assets` at buildtime impossible, as this requires all the containers to be up.

Thereby running

```bash
docker-compose run web mix phoenix.digest -o /var/assets
```

is crucical for this to work and can only be done when the containers are running. 

__Note__: A solution to this is to invert the dependency and build the separate nginx container with the digested assets in it, mounting its volumes into the web container later on. 

However, asset digestion can be done on demand this way - the volume container will just keep the last version of the digested assets.

Running the containers now should ideally provide the static assets already:

```bash
# the hash may vary
http get http://localhost:4002/js/app-<hash>.js
```

should yield our JavaScript. Same goes for our css.

We also need to update our `prod.exs` environment to make the manifest file known:

```elixir
# /config/prod.exs
  config :kitteh, Kitteh.Endpoint,
    http: [port: {:system, "PORT"}],
    url: [host: "example.com", port: 80],
    cache_static_manifest: "/var/assets/manifest.json"
```

The asset paths in `app.html.eex` have to be updated to make this work with the nginx serving our assets (remember, this would be "assets.kitt.eh" in production):

```html
<!-- /web/templates/layout/app.html.eex -->

<!-- [...] -->
<link rel="stylesheet" href="<%= static_url(@conn, "/css/app.css") %>">
<!-- [...] -->
<script src="<%= static_url(@conn, "/js/app.js") %>"></script>
```

This requires a small addition to `prod.exs` (`static_url`):

```elixir
# /config/prod.exs
config :kitteh, Kitteh.Endpoint,
  http: [port: {:system, "PORT"}],
  url: [host: "example.com", port: 80],
  static_url: [host: "localhost", port: 4002],
  cache_static_manifest: "var/assets/manifest.json"
```

Rebuilding and running our containers again should now yield results - all the uploaded images are served from an nginx and all of the assets are served from another. also, everything is persisted independently.

Neat.

For your convenience, I [added a tag here](https://github.com/floriank/kitteh-phoenix/tree/08-serving-static-content) so that you can compare progress yourselves.

<a name="looking-back"></a>
## Looking back

We have done a lot so far. We [coded a small uploader application]({{< ref "using-phoenix-with-docker-part-2-implementation.md">}}) and put most of the dependencies into containers. 

Here is the list of containers used:

1. A PostgreSQL for persistance
2. An nginx for serving uploaded images
3. A second nginx for serving static assets like JavaScript and CSS
4. A web application container that holds the application

There are also 3 volume containers that are used to share data between the containers and provide persistance.

<a name="cleaning-up"></a>
### Cleaning up

We do have some prolems with the setup as well:

- This might be overkill for such a small application and you should consider bare metal for this setup (or Heroku if you feel so inclined)
- The web application container is *huge*
- Two nginx are not necessarily better than one
- There is no proper configuration management yet - most of the stuff we need is hardcoded either in our application or the docker files.

In fact, let's clean up some problems right here, right now. Introduce a `.dockerignore` file and add the following list of patterns:

```bash
# Generate on crash by the VM
erl_crash.dump

# Static artifacts
node_modules/
```

That reduces the `web` images size **by about 4MB**, as the `node_modules` are not needed in the image. Woah.

The problem here is that we are using a full [Ubuntu image](https://github.com/floriank/kitteh-phoenix/blob/08-serving-static-content/Dockerfile#L1) (which I chose for convenience reasons like installing via `apt-get`). For procatical purposes we should probably use an [alpine](http://www.alpinelinux.org/)-based image to build our application container.

There is also SSL yet, we're purely on relying on HTTP - which is not a production setup I would endorse in 2016.

Finally, our main attention should probably also focus on removing items from the codebase in the web container that we do not need - mainly the actual codebase, as Elixir compiles to BEAM code and we would only need that. Just for comparison, we are talking about 18MB in the case of kitteh.

It depends on how much convenience you want - ultimately, reducing tha base image size should be the **first** goal in my opinion.

<a name="conclusion"></a>
## Conclusion

If you read this far - thanks! I hope you found the material I provided interesting and you can take something away for your own projects.

If there are questions for this particular series, you can either write me an email or use [the issues for the project on Github](https://github.com/floriank/kitteh-phoenix/issues). Being not a very skillful Elixir developer, I am always thankful for [Pull Requests](https://github.com/floriank/kitteh-phoenix/pulls) and comments.

You have reached the end of this series. You might be interested in [how everything started]({{< ref "using-phoenix-with-docker-part-1-introduction.md" >}}) and how it [turned out to be implemented after all]({{< ref "using-phoenix-with-docker-part-2-implementation.md" >}}).




