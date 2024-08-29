# frozen_string_literal: true
require "action_controller/railtie"
require "rails/command"
require "rails/commands/server/server_command"
require "rails/all"
require "dotenv"
require "langchain"
require "faraday"
require "json"

Dotenv.load

ENV[
  "DATABASE_URL"
] ||= "postgres://#{ENV["DB_USER"]}:#{ENV["DB_PASS"]}@#{ENV["DB_HOST"]}:#{ENV["DB_PORT"]}/#{ENV["DB_NAME"]}?schema=public"
ActiveRecord::Base.establish_connection
ActiveRecord::Base.logger = Logger.new(STDOUT)

class Meeting < ActiveRecord::Base
end

class ApplicationController < ActionController::Base
end
class MeetingsController < ApplicationController
  def wrapper(text)
    <<~HTML.strip
      <!doctype html>
      <html>
      <head>
        <meta charset="utf-8"/>
        <title>DocsChat</title>
        <script
          src="https://cdn.tailwindcss.com?plugins=forms,typography,aspect-ratio,line-clamp,container-queries">
        </script>
      </head>
      <body>
        <div id="content" class="prose"></div>
        <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
        <script>
          document.getElementById('content').innerHTML = marked.parse(`#{text}`);
        </script>
      </body>
      </html>
    HTML
  end

  def index
    render inline:
             wrapper(
               "Welcome to DocsChat! Click [here](/meetings/#{Meeting.pluck(:id).sample}) to view a random meeting."
             )
  end

  def show
    random_meeting_id = Meeting.pluck(:id).sample
    texts = [
      Meeting.find(params[:id]).ai_summary,
      Meeting.find(params[:id]).ai_action_items,
      "Click [here](/meetings/#{random_meeting_id}) to view a random meeting."
    ].join("\n\n---\n\n")
    render inline: wrapper(texts)
  end
end

class DocsApp < Rails::Application
  config.root = __dir__
  config.action_controller.perform_caching = true
  config.consider_all_requests_local = true
  config.public_file_server.enabled = true
  config.secret_key_base = "i_am_a_secret"
  config.eager_load = false

  Rails.logger = Logger.new($stdout)

  routes.draw do
    resources :meetings, only: [:show]
    root "meetings#index"
  end
end

Rails::Server.new(app: DocsApp, Host: "0.0.0.0", Port: 3000).start
