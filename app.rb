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

class Meeting < ActiveRecord::Base
end

model = "gemma2:2b"
LLM =
  Langchain::LLM::Ollama.new(
    url: "http://localhost:11434",
    default_options: {
      chat_completion_model_name: model,
      completion_model_name: model,
      embeddings_model_name: model
    }
  )

CHAT_HISTORY = Hash.new { |h, k| h[k] = [] }

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :uuid

    def connect
      self.uuid = SecureRandom.urlsafe_base64
    end
  end
  class Channel < ActionCable::Channel::Base
  end
end

class MessagesChannel < ApplicationCable::Channel
  def subscribed
    Rails.logger.info("User subscribed to MessagesChannel #{params}")
    stream_from "#{params[:room]}"
  end
  def unsubscribed
    Rails.logger.info("User unsubscribed from MessagesChannel")
  end
  def chat_message(data)
    Rails.logger.info("User sent a message #{params} #{data}")

    meeting = Meeting.find(data["meeting_id"])
    history = CHAT_HISTORY[data["meeting_id"]]

    # prime the AI with the meeting entry
    history << { role: "user", content: meeting.entry } if history.length == 0

    message = data["message"]
    history << { role: "user", content: message } if message.present?

    Rails.logger.info("Chat history #{history}")

    ai_response = ""
    LLM.chat(messages: history) do |r|
      resp = r.chat_completion
      ai_response += "#{resp}"
      print resp
    end
    history << { role: "assistant", content: ai_response }
    ActionCable.server.broadcast("meeting", ai_response)
  end
end

class ApplicationController < ActionController::Base
end

class RootController < ApplicationController
  def index
    render inline: <<~HTML.strip
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8" />
          <title>DocsChat</title>
          <script type="importmap">
            {
              "imports": {
                "react": "https://esm.sh/react",
                "react-dom": "https://esm.sh/react-dom",
                "react/jsx-runtime": "https://esm.sh/react/jsx-runtime",
                "@mui/material": "https://esm.sh/@mui/material",
                "@mui/icons-material": "https://esm.sh/@mui/icons-material",
                "@rails/actioncable": "https://esm.sh/@rails/actioncable",
                "@tanstack/react-query": "https://esm.sh/@tanstack/react-query",
                "react-window": "https://esm.sh/react-window",
                "react-virtualized-auto-sizer": "https://esm.sh/react-virtualized-auto-sizer",
                "marked": "https://esm.sh/marked"
              }
            }
          </script>
          <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
          <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
          <script src="https://cdn.tailwindcss.com?plugins=forms,typography,aspect-ratio,container-queries"></script>
          <link rel="stylesheet" href="https://fonts.googleapis.com/icon?family=Material+Icons">
        </head>
        <body>
          <div id="root"></div>

          <script type="text/babel" data-presets="react" data-type="module" src="/index.js">
          </script>

        </body>
      </html>
    HTML
  end
end

class MeetingsController < ApplicationController
  def index
    meetings =
      Meeting
        .all
        .order(date: :asc)
        .pluck(:id, :date, :unit, :topic)
        .map do |id, date, unit, topic|
          { id: id, date: date, unit: unit, topic: topic }
        end
    render json: meetings
  end

  def show
    meeting = Meeting.find(params[:id])
    render json: {
             aiSummary: meeting.ai_summary,
             aiActionItems: meeting.ai_action_items,
             entry: meeting.entry,
             date: meeting.date,
             unit: meeting.unit,
             id: meeting.id
           }
  end
end

class DocsApp < Rails::Application
  config.root = __dir__
  config.action_controller.perform_caching = true
  config.consider_all_requests_local = true
  config.public_file_server.enabled = true
  config.secret_key_base = "change_me"
  config.eager_load = false

  routes.draw do
    mount ActionCable.server => "/cable"
    resources :meetings, only: %i[index show]
    root "root#index"
  end
end

ActionCable.server.config.cable = {
  "adapter" => "redis",
  "url" => "redis://localhost:6379/1"
}

Rails.logger =
  ActionCable.server.config.logger =
    ActiveRecord::Base.logger = Logger.new(STDOUT)

Rails::Server.new(app: DocsApp, Host: "0.0.0.0", Port: 3000).start
