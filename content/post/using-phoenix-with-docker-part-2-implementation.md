+++
date = "2016-02-05T15:32:22+01:00"
draft = true
title = "Using Phoenix with docker, Part 2: Implementation"
categories = [
    "development"
]
+++

_This is part two of a three part series_: [Part 1]({{< ref "using-phoenix-with-docker-part-1-introduction.md" >}}) - **Part 2** - [Part 3]({{< ref "using-phoenix-with-docker-part-3-containerization.md">}})

## Installation

Before we start, please make sure you install Elixir and Phoenix. If you do not care or have already installed both, you can skipt this part.

### Elixir

Installing Elixir is hopefully straight forward to you - it's **not** as convenient as just typing

```bash
sudo apt-get install elixir
```

as it equires the installation of Erlang and the **O**pen **T**elephony **P**latform (OTP). A more detailed guide on how to do the installation of Elixir (including the installation of Erlang/OTP [can be found on the homepage](http://elixir-lang.org/install.html) - regardless of your preferred OS-choice. 

### Phoenix

Once you have installed Elixir, it's time to setup Phoenix. This can be done via `hex`, which in turn can be installed via `mix`:

```bash
mix local.hex
```

and then installing Phoenix via:

```bash
mix archive.install https://github.com/phoenixframework/archives/raw/master/phoenix_new.ez
```

If you need more detail, [consider visiting the Phoenix docs](http://www.phoenixframework.org/docs/installation).

## Let's go

```bash
mix phoenix.new kitteh
```

should create a new Phoenix project for you in the folder `./kitteh`. When asked to install dependencies, you should probably say yes, altough it's irrelevant, since we're not going to build a frontend.

You should end up with something like this:

```bash
.
├── brunch-config.js
├── _build
├── config
├── deps
├── lib
├── mix.exs
├── mix.lock
├── node_modules
├── package.json
├── priv
├── README.md
├── test
└── web
```

I will not go through the meaning of each folder, as this would probably way too much for this article.

If you do not wish to do anything yourself, I prepared a [repository here](https://github.com/floriank/kitteh-uploader). You may use the tag `01-lets-go` [to get this initial codebase](https://github.com/floriank/kitteh-phoenix/tree/01-lets-go). 

## Scaffolding

Scaffolding is a pretty fast and reliable way in Phoenix to get off the ground. We're not going to use it to its full potential here.

But let's generate a controller:

```bash
mix phoenix.gen.html --no-model Image images
```

This might be a bit counter-intuitive (it is to me) - but generating just a controller and its views requires the all-including `gen.html` task, which normally generates a complete resource with views associated.

looking at our newly generated controller, we notice that it has been filled with all kind of good stuff:

```elixir
defmodule Kitteh.ImageController do
  use Kitteh.Web, :controller

  alias Kitteh.Image

  plug :scrub_params, "image" when action in [:create, :update]

  def index(conn, _params) do
    images = Repo.all(Image)
    render(conn, "index.html", images: images)
  end

  def new(conn, _params) do
    changeset = Image.changeset(%Image{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"image" => image_params}) do
    changeset = Image.changeset(%Image{}, image_params)

    case Repo.insert(changes
# [...]
```

Woah.

Hold your horses. All I wanted was a simple controller with an action or maybe two.

So, let's rollback the changes. Except we cannot. At least not conveniently, as Phoenix does not provide a reverse-option for its generators. Yet. I just guessed this right now without actually looking that up. 

```bash
git clean -f && rm -rf web/templates/images
```

to the rescue. Phew.

## Simpler times

Let's fall back to the already generated `PageController`. It already has an action `index` ready to use. At the moment it renders a file called `index.html.eex` ([link for the lazy](https://github.com/floriank/kitteh-phoenix/blob/lets-go/web/templates/page/index.html.eex)) - it's also generated for us. It constitutes a demo partial that together with the `app.html.eex` ([this one here](https://github.com/floriank/kitteh-phoenix/blob/lets-go/web/templates/layout/app.html.eex)) forms a complete overview if we go and visit the locally running instance at [localhost](http://localhost:4000).

That is after running 

```bash
iex -S mix phoenix.server
```

of course.

Neat.

## Providing a frontend

This should be rather straightfoward. Phoenix includes [Bootstrap](https://getbootstrap.com) by default. I could disagree with that, but then again, using Bootstrap is relatively straight forward. Discussing the frontend choices made by Phoenix is futile at the moment. 

The team apparently decided to just extract that decision and delegate it to the user, as the frontend options in the year 2016 are many and there are no decisions to be made by a framework for you that would fit you use case perfectly.

That being said, replacing everything in `index.html.eex` with

```html
<div class="row">
  <div class="col-xs-12">
    <div class="panel panel-default">
      <div class="panel-heading">
        <h1 class="panel-title">Kitteh uploader</h1>
      </div>
      <div class="panel-body">
        <p>Upload a cat picture. Doggies are welcome, too.</p>
        <form action="/upload" method="post" enctype="multipart/form-data" class="form">
          <div class="form-group">
            <label for="image" class="control-label">Image</label>
            <input type="file" required id="image" name="image" class="form-control">
          </div>
        </form>
      </div>
    </div>
  </div>
</div>
```

should do the trick. No, we are not using the [form builders that Phoenix provides](http://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html), but feel free to read up on them. They're very changeset-centric in my opinion at the moment and I do miss the equivalents for just building tags. Then again, this might be overkill, as we can just use plain HTML instead.

I also changed the `app.html.eex` a bit. If that is all too much frontend stuff for you, i suggest you look at the `02-simple-frontend` [tag here](https://github.com/floriank/kitteh-phoenix/tree/02-simple-frontend).

## New routes

We defined a `/upload` path that the form uses, but this routes is nowhere to be found. Let's add it:

```elixir
# see web/router.ex
# [...]
  scope "/", Kitteh do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index

    # the new route
    get "/upload", PageController, :upload
  end
# [...]
```

**Note** I also sneakily added a `required` attribute to the file-`input`, to avoid any validation concerns.

If we try to send the form n... we notice that we're missing a way to submit the form and add a button first.

If we try to send the form now, it will crash, since no action will take care of the request. 

But wait, how do I upload stuff anyway? [Should the framework not provide me with some way to make this easier?](http://www.phoenixframework.org/docs/file-uploads).

Kids, read your documentation before heading into battle.

## Reading the documentation

Turns out, the Phoenix people do provide something to do file uploads. The utilize a module called `Plug.Upload`, which is part of the underlying `Plug` module. 

That mean s we have to actually use the form builders after all. And guess what, we also use the form builders because now we're dealing with changesets. 

I feel silly.

Create a new model:

```bash
mix phoenix.gen.model Image original_name:string url:string size:integer 
```

and migrate the database:

```
mix ecto.create && mix ecto.migrate
```

If this fails for you, make sure you have a valid configuration for you database. To configure your database, see you local `config/dev.exs` (see [here](https://github.com/floriank/kitteh-phoenix/blob/02-simple-frontend/config/dev.exs)).

So, finally, we can create a changeset in the controller and use it in the template:

```erb
<!-- index.html.eex, replacing the <form> -->
<%= form_for @changeset, "/upload", [multipart: true], fn f ->  %>
  <div class="form-group">
    <label for="image_file" class="control-label">Image</label>
    <%= file_input f, :file, required: true %>
  </div>
  <div class="form-group">
    <%= submit "Upload", class: "btn btn-primary" %>
  </div>
<% end %>
```

The `@changeset` is introduced and passed to the view in the controller:

```elixir
# web/controllers/page_controller.ex
# [...]
  alias Kitteh.Repo
  alias Kitteh.Image

  def index(conn, _params) do
    changeset = Image.changeset(%Image{})
    render conn, "index.html", changeset: changeset
  end
# [...]
```

If all goes well, this should render our frontend again with what we previously had. I also snuck in the missing Button for submitting the form. Please note that in order to actually use the line

```erb
<%= file_input f, :file, required: true %>
```

a virtual `file` attribute has to exist in the `Image` model. 

If this was all just ramblings of a mad developer for you, you can also check out the tag `03-actually-read-the-docs` [here](https://github.com/floriank/kitteh-phoenix/tree/03-actually-read-the-docs).

## Handle the file

It's time for some action in the controller, because at the moment our application will crash, if we try to submit the form with an image.

The controller action has to do the following:

1. <s>Validate the file given</s>
2. Move the uploaded file under a new name into a folder we can access
3. Save the model with some information on the file uploaded to the DB.
4. if that was successful, redirect to the `show` action for the new image
5. (alt) if not, redirect to the `index` with a message

I will skip the validation on the file - there could be some useful stuff there, like validating the filesize and the actual mime type. Also, the validations would fit more naturally into the `Image` module.

We'll skip this here and assume that the file given is something we want.

Phoenix will give us the file as a `Plug.Upload` in our `params` to the newly created `upload` function in `PageController`:

```elixir
# web/controllers/page_controller.ex
# [...]

  def upload(conn, params) do
    # now what?
  end

# [...]
```

Thinking like a Rails developer, the fat model approach comes to mind. Let's put all the logic for this into a model and let the controller action pass in the params. 

This is not viable here, since Elixir ultimately does not care where your function lives. In the end it's just different names for modules your functions and and structs live in.

I decided in favour of a more controller based approach. The controller will do the the copying and transform the file input into a usable `params` map:

```elixir
# web/controllers/page_controller.ex
# [...]
  def upload(conn, %{ "image" => %{ "file" => file } }) do
    # transform the uploaded file into a changeset
    params = file
      |> copy_file(unique_name)
    changeset = Image.changeset(%Image{}, params)

    # try to insert the newly generated changeset
  end
# [...]
```

The copy file function acutally does the more "heavy lifting":

```elixir
defp copy_file(file) do
  extension = Path.extname(file.filename)
  target = target_path <> name <> extension
  case File.copy(file.path, target) do
    {:ok, size} ->
      %{
        generated_name: name,
        token: String.downcase(name),
        path: target,
        original_name: file.filename,
        content_type: file.content_type,
        size: size
      }
    {:error, _} ->
      %{}
  end
end
```

Depending on whether the copying was successful, we either get a proper `params` map with all the necessary information filled in or we are left with an empty map that will never pass our validations.

Note that `target_path` actually behaves differently from what you would expect. In Phoenix, you do not find the same behaviour as with Rails' `Rails.root`. 

For now, we need a target path that lives within our application and we can access. But our codebase will be compiled (in contrast to a Ruby codebase), so we're cannot be sure where our bytecode ends up. 

Phonix does provide this though:

```elixir
  Application.app_dir(:kitteh, "priv") <> "/static/uploads/"
```

See [this StackOverflow answer](http://stackoverflow.com/questions/33931176/finding-a-file-in-a-phoenix-app-script-rails-root#) for more information. The actual implementation used is found [here](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/controllers/page_controller.ex#L81).

After having generated a `params` map, the rest is pretty easy and is just the same as in any Phoenix tutorial you might find:

- generate a changeset based on `Image`
- insert that changeset
- redirect to the show action or abort and rerender the index template

In case you were wondering: 

The shorthand generated for the kitty is generated via `Image.generate_unique_name`, which [uses collected seed data](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/models/image.ex#L41) to generate a different combination of these attributes. We have to try again if we actually used the name before in the database. Since Elixir does not have any loops, we [resort to recursion](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/controllers/page_controller.ex#L56) until we find a name that we can use.

**Note**: This has no safety measures - if all combinations of the attributes are used up, our database is "full" and we are screwed.

After the image is persisted we redirect to `show`. Additionally, an `ImageController` is introduced with a `show` action [here](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/controllers/image_controller.ex#L6) to actually serve up the image for now. This is intermediary - ultimately, we'll not use Phoenix to serve assets in production.

If all goes well, the upload should work and the original image should be served under a memorable shorthand.

### Shortcuts

If this is all to much coding and you would like the easy way out, check out the tag `04-enable-uploading` [here](https://github.com/floriank/kitteh-phoenix/tree/04-enable-uploading).

## Resizing images

Remember the image modifiers? Like "Tiny", "Large" and "Monstrous"? We forgot about those.

It would be nice if we had all the images for the different sized images pre-generated. We could use the same mechanisms we already have implemented to serve them.

### GenServer

In a (newer) Rails environment, we could utilize anything that fulfills the interface of [`ActiveJob`](http://edgeguides.rubyonrails.org/active_job_basics.html, like an adapter to [Sidekiq](http://sidekiq.org/) or the `delayed_job`(https://github.com/collectiveidea/delayed_job) gem. We spin up a second OS process to generate the image,

Not an option here though. There are some solutions to queues and background jobs, but we are on the Erlang VM anyway, so wht not just utilize the technology available to us? After all, BEAM processes are cheap and lightweight.

[GenServer](http://elixir-lang.org/getting-started/mix-otp/genserver.html) might be the answer here. Besides reading the documentation, Daniel Berkompas has done a very excellent job of explaining it in [his LearnElixir.tv episodes](https://www.learnelixir.tv/episodes). It's paid content but worth every dollar and it's still expanded. While you're at it, check out [his blog](http://blog.danielberkompas.com/).

If this is all the same to you and you could not care less how the images are generated exactly, check out the tag `05-resizing-cats` [here](https://github.com/floriank/kitteh-phoenix/tree/05-resizing-cats).

## Problems of the demo app

This demo application has quite a few problems, some of them already discussed, some of them a little less obvious:

@TODO: List of problems and bugs

However, it should make a good demo app as it has almost everything - a web app, some need for a database, static data taht has to be stored and served from somewhere. All the good stuff.

## Conclusion

[In the next part]({{< ref "using-phoenix-with-docker-part-3-containerization.md" >}}), we'll look into finally using `docker` to gain containers for our project and use `docker compose` to orchestrate our system.

If you already forgot what this was all about, [check out part 1 to get a re-introduction]({{< ref "using-phoenix-with-docker-part-1-introduction.md">}}).


