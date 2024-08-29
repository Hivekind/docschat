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
    Rails.logger.info("User subscribed to MessagesChannel")
  end
  def unsubscribed
    Rails.logger.info("User unsubscribed from MessagesChannel")
  end
  def message(data)
    Rails.logger.info("User sent a message #{params} #{data}")
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
        <body class="prose">
          <div id="root"></div>

          <script type="text/babel" data-presets="react" data-type="module">
            import React, { useState, useEffect } from "react";
            import { createConsumer } from "@rails/actioncable";
            import {
              useQuery,
              QueryClient,
              QueryClientProvider,
            } from "@tanstack/react-query";
            import { marked } from "marked";
            import {
              List,
              ListItemButton,
              ListItemAvatar,
              Avatar,
              ListItemText,
              Icon,
              Tooltip,
            } from "@mui/material";
            import { FixedSizeList } from "react-window";
            import AutoSizer from "react-virtualized-auto-sizer";

            const queryClient = new QueryClient();
            const consumer = createConsumer("ws://localhost:3000/cable");


            function MeetingItem(props) {
              const { currentMeetingId } = props;

              const { isPending, error, data } = useQuery({
                queryKey: ["meetings", currentMeetingId],
                queryFn: () => fetch("/meetings/" + currentMeetingId).then((res) => res.json()),
              });

              if (isPending) return "Loading...";
              if (error) return "An error has occurred: " + error.message;

              const { aiSummary, aiActionItems, entry, date, unit, id } = data;
              return (
                <div dangerouslySetInnerHTML={{ __html: marked.parse(aiSummary + `\n\n---\n\n` + aiActionItems) }}></div>
              );
            }

            function MeetingList({ currentMeetingId, setCurrentMeetingId }) {
              const { isPending, error, data } = useQuery({
                queryKey: ["meetings"],
                queryFn: () => fetch("/meetings").then((res) => res.json()),
              });

              if (isPending) return "Loading...";
              if (error) return "An error has occurred: " + error.message;

              const renderRow = ({ index, data, style }) => {
                const meeting = data[index];
                const { id, date, unit, topic } = meeting;

                return (
                  <Tooltip
                    title={topic}
                    placement="right-end"
                    arrow
                    slotProps={{
                      popper: {
                        modifiers: [
                          {
                            name: "offset",
                            options: {
                              offset: [0, 16],
                            },
                          },
                        ],
                      },
                    }}
                  >
                    <ListItemButton
                      style={style}
                      component="div"
                      disablePadding
                      selected={currentMeetingId == meeting.id}
                      onClick={() => setCurrentMeetingId(id)}
                    >
                      <ListItemText primary={"" + unit + " - " + id} secondary={date} />
                    </ListItemButton>
                  </Tooltip>
                );
              };

              return (
                <AutoSizer>
                  {({ height, width }) => (
                    <FixedSizeList
                      height={height}
                      width={width}
                      itemCount={data.length}
                      itemSize={64}
                      itemData={data}
                      overscanCount={5}
                    >
                      {renderRow}
                    </FixedSizeList>
                  )}
                </AutoSizer>
              );
            }

            function App() {
              const [currentMeetingId, setCurrentMeetingId] = useState(461);

              useEffect(() => {
                const subscription = consumer.subscriptions.create("MessagesChannel", {
                  received: (recv) => {
                    console.log(recv);
                  },
                });
              }, []);

              return (
                <QueryClientProvider client={queryClient}>
                  <section class="w-screen h-screen m-0 p-0 ">
                    <div class="flex h-full">
                      <div class="w-80 overflow-y-auto bg-gray-100">
                        <MeetingList
                          currentMeetingId={currentMeetingId}
                          setCurrentMeetingId={setCurrentMeetingId}
                        />
                      </div>
                      <div class="flex-1 bg-white p-4 overflow-y-auto h-3/5 border-b-2">
                        <MeetingItem currentMeetingId={currentMeetingId} />
                      </div>
                    </div>
                  </section>
                </QueryClientProvider>
              );
            }

            // Mount and bind the React app to the DOM
            import { createRoot } from "react-dom";
            const domNode = document.getElementById("root");
            const root = createRoot(domNode);
            root.render(<App />);

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

Rails.logger =
  ActionCable.server.config.logger =
    ActiveRecord::Base.logger = Logger.new(STDOUT)

Rails::Server.new(app: DocsApp, Host: "0.0.0.0", Port: 3000).start
