# frozen_string_literal: true
require 'rails/all'
require "dotenv"
require "langchain"
require "faraday"
require 'json'

Dotenv.load

ENV["DATABASE_URL"] ||= "postgres://#{ENV['DB_USER']}:#{ENV['DB_PASS']}@#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_NAME']}?schema=public"
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'], port: ENV['DB_PORT'],
  username: ENV['DB_USER'], password: ENV['DB_PASS']
)
ActiveRecord::Base.logger = Logger.new(STDOUT)

class App < Rails::Application
  config.root = __dir__
  config.consider_all_requests_local = true
  config.secret_key_base = 'i_am_a_secret'
  config.eager_load = false

  routes.append do
    root to: 'welcome#index'
  end
end

class Meeting < ActiveRecord::Base
end

class WelcomeController < ActionController::Base
  def wrapper(text)
    <<~HTML.strip
      <!doctype html>
      <html>
      <head>
        <meta charset="utf-8"/>
        <title>DocsChat</title>
      </head>
      <body>
        <div id="content"></div>
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        <script>
          document.getElementById('content').innerHTML = marked.parse(`#{text}`);
        </script>
      </body>
      </html>
    HTML
  end

  def index
    render inline: wrapper(Meeting.find(Meeting.pluck(:id).sample).ai_action_items)
  end
end

App.initialize!

run App
