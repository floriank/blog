+++
categories = ["development"]
title = "Uploading files using Relay Modern and a GraphQL API made with Absinthe"
date = "2019-05-03T09:30:30+01:00"
+++

Since I've decided to finally give the [TypeScript](https://typescriptlang.org)/[React](https://reactjs.org) combo a spin, I have to admit that it's come quite far since I've last tried it in 2016. 

# Making things overly complex

I had decided to build a prototype for a friend - so naturally I thought of the most complex architecture and implementation and then threw it out immediately.

Taking what I've learned, I decided to move the client application together with the backend and threw out the JSON API entirely. If I learned anything so far about architecture, it's that complexity early on feasts off your tears.

# Relay and GraphQL  

When researching the mode of communication between backend and frontend I made a decision for GraphQL - mostly out of interest, but also because we had good experiences with it during my last bigger project at work. The implementation in Elixir is pretty straight forward using the most excellent [absinthe](https://github.com/absinthe-graphql/absinthe) package, which even has custom helpers for [relay](https://facebook.github.io/relay).

# File uploads

I won't describe how to exactly build a GraphQL powered application frontend and backend-wise. I will add an example project ([just give me the code already!](https://github.com/floriank/react_relay_kitten_uploader)) to this post where you can check out how I did it - and of course remind you that there is always more than one way to skin a ... well, cat.

On thing in particular that I found a bit bumpy to deal with was file uploading in this particular combination of technologies.

The [absinthe docs](https://hexdocs.pm/absinthe/Absinthe.html) have a [whole page](https://hexdocs.pm/absinthe/file-uploads.html#content) of describing what to look out for when dealing with file uploads.

The nice thing is this:

> By treating uploads as regular arguments we get all the usual GraphQL argument benefits (such as validation and documentation)—-which we wouldn’t get if we were merely putting them in the context as in other implementations.

The upload is just another field in the schema of `type Upload`. If you look at a simple type in GraphQL:

```graphql
type Kitten {
  id: ID
  name: String
  image: Upload
}
```

You can see that this is treated indifferent from any other piece of data. Which is great. 

_Quick hint_: to get the `Upload` type:

```elixir
# lib/my_app_web/schema.ex
# [...]
  import_types Absinthe.Plug.Types
```

Unfortunately, this is where the docs kind of stop with a note saying that relay is in need of having some documentation added. We'll get to that.

# FormData vs. POST body

Usually, when communicating with a GraphQL based API, you continuously reuse the same entry point and every request will have the form of 

```
POST /api/graph  
```

When using absinthe, the body for this request should take the following form:

```
{ 
  operation: "<The text of your query>",
  variables: {}
}
```

In our case, uploading an image would be a mutation that we can implement on the schema using the [`Absinthe.Relay.Mutation.Notation.Modern` module that absinthe](https://hexdocs.pm/absinthe_relay/Absinthe.Relay.html) provides, like this:

```elixir
# in ./lib/your_app_web/schema.ex
mutation do 
  @desc "Create a new kitten, awww *_*"
  payload field :new_kitten do
    @desc "Input for a new kitten"
    input do
      @desc "The photo of the kitten"
      field(:card_image, non_null(:upload))

      @desc "The name of the kitten"
      field(:name, non_null(:string))
    end

    output do
      @desc "The newly created kitten"
      field :kitten, :kitten
    end

    resolve(&Resolvers.Kitten.create_kitten/3)
  end
end
```

In this case we have to understand that the [relay specifies input types](https://facebook.github.io/relay/docs/en/mutations.html) for a given mutation, the reason being that the input object can be individually validated apart from the actual data (in this case, `Kitten` is the type and absinthe provides us with `NewKittenInput`) object. The absinthe notation provides a convenient syntax here. 

## What does the request look like?

We cannot use the same request for uploading files - we need to rely on `FormData` to actually construct a request to the server that uses the same mechanism as submitting a regular form. 

In the case of absinthe, the library expects the following form for a FormData request:

```
query: "
  mutation CreateKittenMutation($input: KittenInput!) {
    newKitten(input: $input) {
      kitten {
        id
        name
      }
    }
  }
"
variables: "{\"input\": { \"name\": \"Noodlez\", image: \"kitten\" }}"
kitten: <binary>
```

Note that the field value for `image` is the string `"kitten"`, which matches a field in the form data.

I actually had to read a bit into the library and compare with the [implementation for apollo](https://github.com/jaydenseric/apollo-upload-client) referenced in the docs. 

Credit where Credit is due, I also found a very, very nice implementation to deal with uploadables in react-relay-network-modern - [https://github.com/relay-tools/react-relay-network-modern/issues/41](https://github.com/relay-tools/react-relay-network-modern/issues/41#issuecomment-468646856), however, this only works for the [reference middleware implemenation](https://github.com/jaydenseric/graphql-upload) in node.js.

The trick here is to check the request for attached `uploadables` and then transform the request so that it matches the form absinthe expects.

Using react-relay-network-modern, the middleware for a simple request with one image might look like this:

```typescript
const multipartRequestMiddleware = next => async (req) => {
  let {
    id, operation: { text: query }, variables, uploadables,
  } = req

  if (uploadables) {
    let formData = new FormData();
    formData.append('query', query);

    // this is the hacky version, the version used int he project is a bit more flexible
    let formDataKey = "kitten"
    variables.input.image = formDataKey

    formData.append('variables', JSON.stringify(variables));
    formData.append(formDataKey, uploadables.kitten)

    req.fetchOpts.body = formData
  }
  const res = await next(req)
  return res
}

export default multipartRequestMiddleware
```

The solution is similar if you're relying on just [using custom `fetch` call inside your relay environment](https://facebook.github.io/relay/docs/en/quick-start-guide.html#relay-environment).

## Multiple images?

So what if we had multiple images? After all, one can never have too many kitten pictures uploaded to a backend.

Well, at the moment, I could not find a good way to batch upload images with Absinthe, which is unfortunate, but [this will hopefully change in the future](https://github.com/absinthe-graphql/absinthe_plug/pull/201).

I'll probably try to implement the [GraphQL Multipart request spec](https://github.com/jaydenseric/graphql-multipart-request-spec) if I have the time to do so.

# Provided project

I've prepared [a project where I built a small uploader application](https://github.com/floriank/react_relay_kitten_uploader) for the interested reader to inspect.

After all, since absinthe is thankfully open source, it's time to think about finding a better way to upload multiple images.

I hope this article provided some insights into the mechanics of uploading files through a GraphQL powered API.

If you have any questions, just send me an email, or open an issue on the project provided.