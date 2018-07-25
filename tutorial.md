# Create a Ruby on Rails backend with Auth0 Authentication

In this tutorial we will walk you through the a setup of an Ruby on Rails 5.2 API Application combined with Auth0. After this you will have an API with private and public routes than you can use for our tutorial on "How to add Auth0 to Vue.js in 7 Steps" which allows you to make authenticated calls on this API. During this tutorial you will learn how to setup a custom Concern, a Json Web Token verification, a Private and a Public route that return JSON. 

## Requirements

- Ruby installed -> 2.5.0p0
- Rails installed -> 5.2.0
- [Auth0 Account](https://auth0.com/)

### What is Rails

Rails is a web application development framework written in the Ruby programming language. It is designed to make programming web applications easier by making assumptions about what every developer needs to get started. It allows you to write less code while accomplishing more than many other languages and frameworks. Experienced Rails developers also report that it makes web application development more fun. [You can read more on their website](https://guides.rubyonrails.org/getting_started.html)

### What is Auth0 

Auth0 provides authentication and authorization as a service. They are here to give developers and companies the building blocks they need in order to secure their applications, without having to become security experts. You can connect any application (written in any language or on any stack) to Auth0 and define the identity providers you want to use (how you want your users to log in). Based on your app's technology, choose one of our SDKs (or call our API) and hook it up to your app. Now each time a user tries to authenticate, Auth0 will verify their identity and send the required information back to your app. [You can read more on their website](https://auth0.com/docs/getting-started/overview#why-use-auth0-)

## Auth0 Setup

Before we start our dig into Rails 5.2 and the setup, we will access the Auth0 application to add an API so we can configure our application accordingly. To do so access the [API Menu in the Management App (manage.auth0.com/#/apis)](https://manage.auth0.com/#/apis).

![Auth0 API Management Dashboard](//a.storyblok.com/f/39898/1488x926/3b9d8fa1f4/auth0-api-dashboard.jpg)

Press the orange **+ Create API** button on the top right corner to open the creation modal.

![Auth0 API Creation button](//a.storyblok.com/f/39898/1452x912/a71f854229/auth0-create-api-button.jpg)

Enter your informations as I did in the screenshot below. In audience you do ** not** have to add `http://localhost:4000` - note: this identifier (which do not need to be an URL) can not be modified, but you can, of course, create a new API if needed.

![Auth0 create API modal](//a.storyblok.com/f/39898/1442x904/c76c7d2ddf/auth0-create-api-modal.jpg)

Well done! You're ready to start your authentication journey. Sadly the Quickstart of Auth0s API section do not include a Rails Copy&Past example right away but you can find all you need later in this tutorial. The big benefit of the already available Quickstarts are that you have all the information you need to configure in one place (the node.js example). All those information can also be found in the Settings Tab.

![Auth0 quickstart](//a.storyblok.com/f/39898/1444x896/3b3f9efad3/auth0-quickstart.jpg)

## Enviroment Setup

This tutorial will use a freshly created Rails project. You can also add Auth0 to an existing project using the same/similar approach as presented here.

~~~bash
## PostgreSQL
rails new my_api --api --database=postgresql

## SQLite3
rails new my_api --api
~~~

If you already have your own project have a look at their guide on [how to change an existing application](https://guides.rubyonrails.org/api_app.html#changing-an-existing-application).

## Install dependencies

We will use the `jwt` gem for validation within our own `JsonWebToken` class and a custom Concern to mark endpoints which should require authentication through an incoming AccessToken from your client application. You can check our [tutorial for a Vue.js Client](https://www.storyblok.com/tp/how-to-auth0-vuejs-authentication) that already handles the authentication process.

~~~bash
# add to your Gemfile
gem 'jwt'

# execute on command line
bundle install
~~~

## Creating our JsonWebToken Class

The code we're going to use is directly from the [official Auth0 Ruby on Rails](https://auth0.com/docs/quickstart/backend/rails/01-authorization) getting started which I highly recommend you to open as well since it ships with your project configuration out of the box.

Before we will create a `JsonWebToken` class, which we will use to verify the incoming AccessToken of the Request `Authorization` Header, we have to make some adjustments: Rails 5.2 has some changes that will require you to either change your understanding of the `/app` and `/lib` folder or to add one line to allow the "old" behavior. Since with 5.2 you will not be able to directly use the `/lib` directory for non domain specific classes. There are two way to approach this:

~~~bash
# 1: Move /lib in to /app/lib
# As recommended by a member: https://github.com/rails/rails/issues/13142#issuecomment-275549669

# 2: Add a line to your config/environment.rb
Dir[Rails.root.join('lib/**/*.rb')].each { |f| require f }
# As recommended by another contributor: https://github.com/rails/rails/issues/13142#issuecomment-330628038
~~~

I will go ahead and follow the `/app/lib` approach for now, feel free to also use the other. Thanks to an [awesome group of contributors](https://github.com/jwt/ruby-jwt#contributors) we can use a pure ruby implementation of the [RFC 7519 OAuth JSON Web Token (JWT)](https://tools.ietf.org/html/rfc7519) standard as shown below.

~~~ruby
# app/lib/json_web_token.rb

# frozen_string_literal: true
require 'net/http'
require 'uri'

class JsonWebToken
  def self.verify(token)
    JWT.decode(token, nil,
        true, # Verify the signature of this token
        algorithm: 'RS256',                          # RS256 or HS256
        iss: 'https://YOUR_AUTH0_TENANT_DOMAIN/',    # something like 000.eu.auth0.com
        verify_iss: true,
        aud: Rails.application.secrets.auth0_api_audience,
        verify_aud: true) do |header|
      jwks_hash[header['kid']]
    end
  end

  def self.jwks_hash
    jwks_raw = Net::HTTP.get URI("https://YOUR_AUTH0_TENANT_DOMAIN/.well-known/jwks.json")
    jwks_keys = Array(JSON.parse(jwks_raw)['keys'])
    Hash[
      jwks_keys
      .map do |k|
        [
          k['kid'],
          OpenSSL::X509::Certificate.new(
            Base64.decode64(k['x5c'].first)
          ).public_key
        ]
      end
    ]
  end
end
~~~

## Adding your Auth0 API Audience

With Rails 5.2 is out with a brand new credentials API that will replace the current `config/secrets.yml`. The idea behind the change is mainly to remove some of the confusion introduced by the combinations of `config/secrets.yml`, `config/secrets.yml.enc` and `SECRET_BASE_KEY` used in earlier versions of Rails, and attempt to unify everything using a more straightforward approach. You can read more about this Change in their [Pull Request on Github](https://github.com/rails/rails/pull/30067).

Your Rails application should already have those two files available instead:

- `config/credentials.yml.enc`
- `config/master.key`

As it’s extension `.enc` suggests, this file is going to be encrypted using the `master.key` - nobody be able to read what’s inside - unless they have the proper master key to decrypt it. So **you can add** the `config/credentials.yml.enc` to your version control. On the other hand the `config/master.key` **should not** be in your version control eg. git repository. New Rails 5.2 apps already have it in the `.gitignore` to make sure you won't commit it. Everybody that has that `config/master.key` file will be able to decrypt your `credentials.yml.enc` file and therefore has access to your credentials. 

### Editing your encrypted Rails credentials file

Rails 5.2 comes with a way to edit the `config/credentials.yml.enc` so you won't have to decrypt and encrypt your file each time on your own. For this to work with your favorite editor you will have to have `$EDITOR` defined, to do so in one command you can use the list below, let me know in the comments or on Twitter which editor you use and how you edited it.

~~~bash
# Visual Studio Code
EDITOR="code --wait" bin/rails credentials:edit

# Visual Studio Code Insiders
EDITOR="code-insiders --wait" bin/rails credentials:edit

# Atom 
EDITOR="atom --wait" bin/rails credentials:edit

# Sublime Text 3
EDITOR="subl --wait" bin/rails credentials:edit

# Vim
EDITOR=vim bin/rails credentials:edit
~~~

You should now be able to see a demo `.yml` structure where we can now add our own configuration/credentials. We will go ahead and add the namespace `auth0` and attribute `api_audience` with your audience as shown below, you can also introduce staging namespaces as you would in a normal `.yml` file. It is a good idea to have the credentials for environments protected by different master keys, so that all of your development machines don’t have access to the production credentials, however if you want to use one key to encrypt them and use namespaces you can find an example right here as well:

~~~
# aws:
#   access_key_id: 123
#   secret_access_key: 345

# without staging namespaces
auth0:
  api_audience: 'my_audience'

# With staging namespaces
# development:
#   auth0:
#     api_audience: 'my_audience'
# test:
#   auth0:
#     api_audience: 'my_audience'

# Used as the base secret for all MessageVerifiers in Rails, including the one protecting cookies.
secret_key_base: XXXXXXXXXXXXXXXXXX
~~~

The audience you're using here must be the same as you added in your clients setup. You can read more about audience and [what an audience acutally is in the Auth0 docs](https://auth0.com/docs/tokens/access-token#access-token-format). If you have an issue with audiences check the [auth0 logs](https://manage.auth0.com/#/logs) and [if you have an API with that audience in place](https://manage.auth0.com/#/apis).

### Updating the JsonWebToken file

You may noticed the line `Rails.application.secrets.auth0_api_audience` which still uses the old `secrets` and that would actually still work but since we don't even have it (if you have created a new project as we did and not upgraded) we exchange that with our credentials: `Rails.application.credentials[:auth0][:api_audience]`.

~~~ruby
# app/lib/json_web_token.rb

...
  def self.verify(token)
    JWT.decode(token, nil,
        true, # Verify the signature of this token
        algorithm: 'RS256',                          
        iss: 'https://YOUR_AUTH0_TENANT_DOMAIN/',
        verify_iss: true,
        # aud: Rails.application.secrets.auth0_api_audience, ## <----- Notice me!
        # aud: Rails.application.credentials[Rails.env.to_sym][:auth0][:api_audience] ## With staging namespace
        aud: Rails.application.credentials[:auth0][:api_audience], ## No staging namespace
        verify_aud: true) do |header|
      jwks_hash[header['kid']]
    end
  end
...
~~~

## Define your Secured concern

Next we will create a custom `Concern` called `Secured` which checks for the `AccessToken` in the `Authorization` request header. If the token is present, it should be passed to `JsonWebToken.verify`. If you experience an issue at this point that `JsonWebToken` is not defined or can not be loaded, make sure to have the `/lib` folder moved to `app/lib` or add `Dir[Rails.root.join('lib/**/*.rb')].each { |f| require f }` to your `config/environment.rb`

~~~ruby
# app/controllers/concerns/secured.rb

# frozen_string_literal: true
module Secured
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_request!
  end

  private

  def authenticate_request!
    auth_token
  rescue JWT::VerificationError, JWT::DecodeError
    render json: { errors: ['Not Authenticated'] }, status: :unauthorized
  end

  def http_token
    if request.headers['Authorization'].present?
      request.headers['Authorization'].split(' ').last
    end
  end

  def auth_token
    JsonWebToken.verify(http_token)
  end
end
~~~

## Public and Private route

To test our application we will add two new controller (a public and private) to our application. 

~~~
# Generate the Public Controller with a hello route
bin/rails generate controller Public hello
~~~

~~~ruby
class PublicController < ApplicationController
  def hello
    render json: { message: 'Hello from a public endpoint! You don\'t need to be authenticated to see this.' }
  end
end
~~~

The public controller should now already be accessible via `/public/hello` after you've started your server `rails s -p {your_port}`.

~~~
# Generate the Private Controller with a hello route
bin/rails generate controller Private hello
~~~

~~~ruby
class PrivateController < ApplicationController
  def hello
    render json: { message: 'Hello from a private endpoint! You need to be authenticated to see this.' }
  end
end
~~~

The private controller should now also be accessible via `/private/hello`, to tell Rails that this controller should use our `Secured` Concern all we have to add is one line:

~~~ruby
class PrivateController < ApplicationController
  include Secured ## <- our Secured Concern

  def hello
    render json: { message: 'Hello from a private endpoint! You need to be authenticated to see this.' }
  end
end 
~~~

If you now access the `/private/hello` route you will receive an error that should look like:

~~~
{
  "errors": [
    "Not Authenticated"
  ]
}
~~~

Nice! We now have a check for the `Authorization` Header and not let our request through! Well done!

## Test/Accessing your Authenticated endpoint

To test your authenticated endpoints you can navigate to the Auth0 Test Panel of your API in the Auth0 app, where you can find, not only a CURL that is preconfigured and looks like the one below, but also many more code examples in various technologies. You can also use our Vue.js example by exchanging the audience with the one of your newly created API in Auth0. The Test suite can be found as the last Tab in the API Configuration in the Auth0 Dashboard.

![Auth0 Test Tab](//a.storyblok.com/f/39898/1440x902/a9fb6e9dbf/auth0-test-tab.jpg)

### 1. Get your JWT from Auth0

The basic request your client can perform by posting to the Auth0 `/oauth/token` endpoint should look like:

~~~
curl --request POST \
  --url https://YOUR_AUTH0_URL/oauth/token \
  --header 'content-type: application/json' \
  --data '{"client_id":"YOUR_CLIENT_ID","client_secret":"YOUR_CLIENT_SECRET","audience":"YOUR_AUDIENCE","grant_type":"client_credentials"}'
~~~

The response you expect from that endpoint should have the following body:

~~~
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciO...h61Ad5VIsCM8m9AD3sHda83Q",
  "token_type": "Bearer"
}
~~~

### 2. Use that token against your API

In your client application we now send that token as `Authorization` header to our API

~~~
curl --request GET \
  --url http://path_to_your_api/ \
  --header 'authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciO...h61Ad5VIsCM8m9AD3sHda83Q'
~~~

and expect the following result:

~~~
{
  "message":"Hello from a private endpoint! You need to be authenticated to see this."
}
~~~

## Wrapping it up

Adding Auth0 to an Rails application is unbelievable easy by following the offical guide. However, since it currently does not cover the differences in Rails 5.2 I felt the need to update and document that part for you so you won't fall into the above changes. The benefits from not writing your own Authentication in every application and instead use an Identify Service like Auth0 are such boost for your productivity and increase in security that I would highly recommend you to check it out yourself. 

With the changes in Rails 5.2 that enables you to actually use encrypted credentials out of the box are great, even tho some will miss the old, now deprecated, secrets.yml. The issue with the lib folder was intresting to read on Github and took me longer to find the "best" way as I wished for. As many of you requested this is now the first API part of the Auth0 tutorials we created at Storyblok, since we do use Ruby and Auth0 ourselves. Feel free to leave your comments down below or write your tweet your feedback on twitter.