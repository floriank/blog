+++
date = "2016-02-15T15:32:22+01:00"
title = "Using Phoenix with docker, Part 2: Implementation"
categories = [
    "development"
]
+++

_This is part two of a three part series_: [Part 1]({{< ref "using-phoenix-with-docker-part-1-introduction.md" >}}) - **Part 2** - [Part 3]({{< ref "using-phoenix-with-docker-part-3-containerization.md">}})

# Contents

<!-- MarkdownTOC -->

- [Installation](#installation)
  - [Elixir](#elixir)
  - [Phoenix](#phoenix)
- [Let's go](#lets-go)
- [Scaffolding](#scaffolding)
- [Simpler times](#simpler-times)
- [Providing a "frontend"](#providing-a-frontend)
- [New routes](#new-routes)
- [Reading the documentation](#reading-the-documentation)
- [Handle the file](#handle-the-file)
  - [Shortcuts](#shortcuts)
- [Resizing images](#resizing-images)
  - [GenServer](#genserver)
- [Resizing](#resizing)
- [Problems of the demo app](#problems-of-the-demo-app)
- [Conclusion](#conclusion)

<!-- /MarkdownTOC -->

<a name="installation"></a>
## Installation

Before we start, please make sure you install Elixir and Phoenix. If you do not care or have already installed both, you can skip the next section.

<a name="elixir"></a>
### Elixir

Installing Elixir is actually not too difficult - it's **not** as convenient as just typing

```bash
sudo apt-get install elixir
```

as it equires the installation of Erlang and the **O**pen **T**elephony **P**rotocol (OTP). A more detailed guide on how to do the installation of Elixir (including the installation of Erlang/OTP [can be found on the homepage](http://elixir-lang.org/install.html) - regardless of your preferred OS-choice. 

<a name="phoenix"></a>
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

<a name="lets-go"></a>
## Let's go

```bash
mix phoenix.new kitteh
```

should create a new Phoenix project for you in the folder `./kitteh`. When asked to install dependencies, you should probably say yes, although it's irrelevant since we're not going to build a complex frontend (but there is additional css, [I promise](https://github.com/floriank/kitteh-phoenix/blob/05-resizing-cats/web/static/css/style.css)).

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

If you do not wish to do anything yourself, I prepared a [repository here](https://github.com/floriank/kitteh-phoenix). You may use the tag `01-lets-go` [to get the initial codebase](https://github.com/floriank/kitteh-phoenix/tree/01-lets-go). 

<a name="scaffolding"></a>
## Scaffolding

Scaffolding is a pretty fast and reliable way in Phoenix to get off the ground. We're not going to use it to its full potential here.

Consider generating a controller:

```bash
mix phoenix.gen.html --no-model Image images
```

This might be a bit counter-intuitive (it is to me) - but generating just a controller and its views requires the all-including `gen.html` task, which normally generates a complete resource with views associated, complete with model files included.

Looking at our newly generated controller, we notice that it has been filled with all kind of good stuff:

```ruby
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

Hold your horses. All I wanted was a simple controller with an action or two.

So, let's rollback the changes. There is no convenient way (i.e. reverse generators) to do this yet, so

```bash
git clean -f && rm -rf web/templates/images
```

to the rescue. Phew.

<a name="simpler-times"></a>
## Simpler times

Let's fall back to the already generated `PageController`. It already has an action `index` ready to use. 

At the moment it renders a file called `index.html.eex` ([link for the lazy](https://github.com/floriank/kitteh-phoenix/blob/01-lets-go/web/templates/page/index.html.eex)). It constitutes a demo partial that together with the `app.html.eex` ([this one here](https://github.com/floriank/kitteh-phoenix/blob/01-lets-go/web/templates/layout/app.html.eex)) forms a complete webpage at the `/` route. 

We can look at it on the locally running instance at [localhost](http://localhost:4000) by executing

```bash
iex -S mix phoenix.server
```

Neat.

<a name="providing-a-frontend"></a>
## Providing a "frontend"

This should be easy. 

Phoenix includes [Bootstrap](https://getbootstrap.com) by default. I could disagree with that, but then again, using Bootstrap is not to inconvenient.

The Phoenix team apparently decided to delegate the frontend choices to the userbase. A wise choice in the short term, as the whole frontend sector is quite fragmented at the moment (early 2016).

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

should do the trick. 

No, we are not using the [form builders that Phoenix provides](http://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html), but feel free to read up on them.  We can just use plain HTML instead.

If that is all too much frontend stuff for you, i suggest you look at the `02-simple-frontend` [tag here](https://github.com/floriank/kitteh-phoenix/tree/02-simple-frontend).

<a name="new-routes"></a>
## New routes

We defined an `/upload` path that the form uses, but this route is nowhere to be found. Let's add it:

```ruby
# see web/router.ex
# [...]
  scope "/", Kitteh do
    pipe_through :browser # Use the default browser stack

    get "/", PageController, :index

    # the new route
    post "/upload", PageController, :upload
  end
# [...]
```

**Note** I also sneakily added a `required` attribute to the file-`input`, to avoid [any validation concerns](http://i.imgur.com/GluNcro.jpg).

If we try to send the form n... we notice that we're missing a way to submit the form and add a button first.

If we try to send the form now, it will crash, since no action will take care of the request. 

But wait, how do I upload stuff anyway? [Should the framework not provide me with some way to make this easier?](http://www.phoenixframework.org/docs/file-uploads).

Kids, **read your documentation** before heading into battle.

<a name="reading-the-documentation"></a>
## Reading the documentation

Turns out, the Phoenix people do provide something to do file uploads. 

That means we can actually use the form builders after all since we're going the changeset route.

I feel silly.

Create a new model:

```bash
# note that this is just my initial try, have a look at the migrations for the actual fields used
mix phoenix.gen.model Image original_name:string url:string size:integer 
```

and migrate the database:

```bash
mix ecto.create && mix ecto.migrate
```

If this fails for you, make sure you have a valid configuration for you database. To configure your database, see your local `config/dev.exs` (see [here](https://github.com/floriank/kitteh-phoenix/blob/02-simple-frontend/config/dev.exs)).

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

```ruby
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

If all goes well, this should render our frontend again. I also snuck in the missing Button for submitting the form. Please note that in order to actually use the line

```erb
<%= file_input f, :file, required: true %>
```

a [virtual](https://github.com/floriank/kitteh-phoenix/blob/03-actually-read-the-docs/web/models/image.ex#L8) `file` attribute has to exist in the `Image` model. 

If this was all just ramblings of a mad developer for you, you can also check out the tag `03-actually-read-the-docs` [here](https://github.com/floriank/kitteh-phoenix/tree/03-actually-read-the-docs).

<a name="handle-the-file"></a>
## Handle the file

It's time for some action in the controller, because at the moment our application will crash if we try to submit the form with an image.

The controller action has to do the following:

1. <s>Validate the file given</s>
2. Move the uploaded file under a new name into a folder we can access
3. Save the model with some information on the file uploaded to the DB.
4. if that was successful, redirect to the `show` action for the new image
5. (alt) if not, redirect to the `index` with a message

I will skip the validation on the file - one could do this by validating the `size` field of the changeset before inserting.

We'll skip this here and assume that the file given is something we want.

Phoenix will give us the file as a `Plug.Upload` struct in our `params` to the newly created `upload` function in `PageController`:

```ruby
# web/controllers/page_controller.ex
# [...]

  def upload(conn, params) do
    # now what?
  end

# [...]
```

Thinking like a Rails developer, the fat model approach comes to mind. Let's put all the logic for this into a model and let the controller action pass in the params. Be done with it, move on. Have a beer maybe.

This is not viable here, since Elixir ultimately does not care where your functions live. _There are no models, just functions and structs_.

I decided in favour of a more controller based approach. The controller will do the the copying and transform the file input into a usable `params` map:

```ruby
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

```ruby
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

For now, we need a target path that lives within our application and we can access. But our codebase will be compiled (in contrast to a Ruby codebase), so we cannot be sure where our bytecode ends up (_Hint_: It's in the `./_build` folder). 

We can do this though:

```ruby
Application.app_dir(:kitteh, "priv")
```

See [this StackOverflow answer](http://stackoverflow.com/questions/33931176/finding-a-file-in-a-phoenix-app-script-rails-root#) for more information. The actual implementation used is found [here](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/controllers/page_controller.ex#L81).

After having generated a `params` map, the rest is just the same as in any Phoenix tutorial you might find:

- generate a changeset based on `Image`
- insert that changeset
- redirect to the show action or abort and rerender the index template

In case you were wondering: 

The shorthand generated for the kitty is generated via `Image.generate_unique_name`, which [uses collected seed data](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/models/image.ex#L41) to generate a different combination of these attributes. We have to try again if we actually used the name before in the database. Since Elixir does not have any loops, we [resort to recursion](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/controllers/page_controller.ex#L56) until we find a name that we can use.

**Note**: This has no safety measures - if all combinations of the attributes are used up, our database is "full" and we are screwed.

After the image is persisted we redirect to `show`. Additionally, an `ImageController` is introduced with a `show` action [here](https://github.com/floriank/kitteh-phoenix/blob/04-enable-uploading/web/controllers/image_controller.ex#L6) to actually serve up the image for now. This is intermediary - ultimately, we'll not use Phoenix to serve assets in "production".

If all goes well, the upload should work and the original image should be served under a memorable shorthand.

<a name="shortcuts"></a>
### Shortcuts

If this is all to much coding and you would like the easy way out, check out the tag `04-enable-uploading` [here](https://github.com/floriank/kitteh-phoenix/tree/04-enable-uploading).

<a name="resizing-images"></a>
## Resizing images

Remember the image modifiers? Like "Tiny", "Large" and "Monstrous"? We forgot about those.

It would be nice if we had all the images for the different sized images pre-generated. We could use the same mechanisms we already have implemented to serve them.

<a name="genserver"></a>
### GenServer

In a (newer) Rails environment, we could utilize anything that fulfills the interface of [ActiveJob](http://edgeguides.rubyonrails.org/active_job_basics.html), like an adapter to [Sidekiq](http://sidekiq.org/) or the `delayed_job` [gem](https://github.com/collectiveidea/delayed_job) gem. We basically spin up a second OS process to generate the image, regardless of the solution.

Not an option here though. There are some solutions to queues and background jobs, but we are on the Erlang VM anyway, so we can utilize the technology available to us. After all, BEAM processes are cheap and lightweight.

[GenServer](http://elixir-lang.org/getting-started/mix-otp/genserver.html) might be the answer. But actually having a long running process in the background that we can use as a service might be overkill here.

Let's use `Task` instead. `Task` is a wrapper around Elixirs `spawn` function and can be used for a [multitude of things](http://elixir-lang.org/docs/v1.1/elixir/Task.html) that are actually more advanced than we do right here, right now.

Looking into [the code](https://github.com/floriank/kitteh-phoenix/commit/3652cbc3287e7fd832e7ad37a0acd5550ea0b36d#diff-3f35d230596bca22de76cff4dd188e4cR82):

```ruby
defp create_sizes(image) do
  sizes = %{ "Tiny" => "90", "Large" => "300", "Monstrous" => "600" }
  original_file = image.path
  Enum.each sizes, fn({ label, size }) ->
    Task.start fn ->
      name = label <> image.generated_name
      file_params = resize(image)
        |> copy_file name
      changeset = Image.changeset(%Image{}, file_params)
        |> Repo.insert
    end
  end
end
```

Using `Task.start` creates a subprocess that is *not linked* to the current process. Process linking here is not strictly necessary, as this is implemented as a fire-and-forget strategy. In contrast to `Task.start_link`, we're not linking our main process (`kitteh`) to the new process. In case it crashes, we do not want to tear down our application (process) as well.

**Note**: I had some problems finding out on how to match function call in using `Enum.each` against the result of the map. The resulting argument is matched against a tuple. Might be trivial, but just in case you were wondering.

This has the _notable_ disadvantage every fire-and-forget strategy has - we do not know if we actually create the images. Good enough for this application, but for something production-ready, one should look for some bidirectional communication. Just in case, you know, you maybe want to connect these images to one another.

<a name="resizing"></a>
## Resizing

Resizing images is something one should probably be too lazy to implement oneself. Enter `mogrify` - it is [a wrapper library](https://github.com/route/mogrify) for ImageMagick, providing us with functions for handling image-resizing.

We should make a mental note here as we introduce a hard dependency for our docker containers later on. Any container that we want to create for this application now has to provide this dependency.

With [another commit](https://github.com/floriank/kitteh-phoenix/commit/b7724faae9725e127f33734bcfaf2eb0ed79a101), the resize function is introduced:

```ruby
defp resize(image, name, size) do
  new_path = target_path <> name <> Path.extname(image.path)
  new_image = open(image.path) |> copy |> resize(size) |> save(new_path)
  %{
    generated_name: name,
    token: String.downcase(name),
    path: new_path,
    original_name: image.original_name,
    content_type: image.content_type,
    size: image.size
  }
end
```

This should create all the resized versions. We can also utilize the builtin `Mogrify.copy` function to skip manual copying as we did for the initial image. We end up with returning params we can use to create another changeset and insert everything. The rest of the system should now work for the resized images as well.

**Note**: Somewhere around this point I noticed [a screw up in the router](https://github.com/floriank/kitteh-phoenix/commit/b7724faae9725e127f33734bcfaf2eb0ed79a101#diff-8c237d3166e777cbb3d401efc40b1c62R19) as matching order was off. This lead to a redirect to `/` after the initial image had been created.

At this point, our image uploader should be feature complete. Altough being the duct-tape ghetto version it now is, it should provide a good basis to play around with in the next part.
 
If this is all the same to you and you could not care less about how the images are generated and stored exactly, check out the tag `05-resizing-cats` [here](https://github.com/floriank/kitteh-phoenix/tree/05-resizing-cats).

<a name="problems-of-the-demo-app"></a>
## Problems of the demo app

This demo application has quite a few problems, some of them already discussed, some of them a little less obvious:

- **no tests** - this is a biggie and nothing to sweep under the rug. Since this is not intended for production purposes, we sweep it under the rug
- the amount of images uploaded is limited to the combination limit of the seed data
- Naming is somewhat bad
- no validations on `Image` changesets besides the required fields
- `[...]`

The list is not complete, but one can always find things to improve. For example, by just supporting another `type`, e.g. "Doggy" in addition to "Kitty", we could double the image capacity. We could also make sure that all images have been created using `Task.await`.

Nevertheless, it should make a good demo app as it has almost everything - a web app, some need for a database, static data that has to be stored and served from somewhere. All the good stuff.

there is one major problem when it comes to Live reload. I personally am not a fan of such a feature, but it is included in Phoenix by default. I had to [disable it in dev](https://github.com/floriank/kitteh-phoenix/commit/9224dcf92a42a26685ac7fc3e9f019095c0d99e0), since it interfered with the upload feature. the uploaded into a folder that is live reloaded apparently wasn't the best of my ideas.

<a name="conclusion"></a>
## Conclusion

[In the next part]({{< ref "using-phoenix-with-docker-part-3-containerization.md" >}}), we'll finally look into using `docker` to gain containers for our project and use `docker compose` to orchestrate our system.

If you already forgot what this was all about, [check out part 1 to get a re-introduction]({{< ref "using-phoenix-with-docker-part-1-introduction.md">}}).


