# frozen_string_literal: true
require 'rails/all'
require "dotenv"
require "langchain"
require "faraday"
require 'json'

Dotenv.load

ENV["DATABASE_URL"] ||= "postgres://#{ENV['DB_USER']}:#{ENV['DB_PASS']}@#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_NAME']}?schema=public"
ActiveRecord::Base.establish_connection
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
    random_meeting_id = Meeting.pluck(:id).sample
    texts = [
      Meeting.find(random_meeting_id).ai_summary,
      Meeting.find(random_meeting_id).ai_action_items,
    ].join("\n\n---\n\n")
    render inline: wrapper(texts)
  end
end

App.initialize!

run App
