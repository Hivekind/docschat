# frozen_string_literal: true
require 'rails/all'
require "dotenv"
require "langchain"
require "faraday"
require 'ruby-progressbar'

Dotenv.load

ENV["DATABASE_URL"] ||= "postgres://#{ENV['DB_USER']}:#{ENV['DB_PASS']}@#{ENV['DB_HOST']}:#{ENV['DB_PORT']}/#{ENV['DB_NAME']}?schema=public"
ActiveRecord::Base.establish_connection(
  adapter: 'postgresql',
  host: ENV['DB_HOST'], port: ENV['DB_PORT'],
  username: ENV['DB_USER'], password: ENV['DB_PASS']
)
# ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  enable_extension "plpgsql"
  create_table :meetings, if_not_exists: true do |t|
    t.string :topic
    t.text :entry
    t.string :unit
    t.date :date
    t.string :uid

    t.text :ai_summary
    t.text :ai_action_items

    t.timestamps
  end
end

Langchain.logger.level = :warn
class Logger

end

llm = Langchain::LLM::Ollama.new(url: "http://localhost:11434", default_options: {
  chat_completion_model_name: "gemma2",
  completion_model_name: "gemma2",
  embeddings_model_name: "gemma2",
})

def prompt_summary(text)
"
Write an accurate summary of the following TEXT. Do not include the word summary, just provide the summary.

TEXT: #{text}

CONCISE SUMMARY:
"
end

def prompt_action_items(text)
"
Compile a list of action items or concerns, with their owners or speakers, for the following TEXT. For every key point, mention the likely owner. Infer as much as you can. If the transcript does not explicitly list owners, try to infer the likely owners. It is very important to infer the likely owners of each action item. Do not show an action item if you are unable to match it with an owner. I don't want a summary. Try your very best. Please respond in a formal manner.

TEXT: #{text}

ACTION ITEMS WITH THEIR OWNERS:
"
end

class Meeting < ActiveRecord::Base
end

line_count = `wc -l "#{"train.json"}"`.strip.split(' ')[0].to_i

File.open("train.json", "r") do |f|
  puts "Processing #{line_count} entries"
  progressbar = ProgressBar.create(total: line_count, format: '%a <%B> %p%% %t Processed: %c from %C %e')

  f.each_line do |line|
    # topic group date entry
    json = JSON.parse(line)

    topic = json["summary"]
    uid = json["uid"]

    unless (m = Meeting.find_by(uid: uid)).nil?
      puts "skipping #{uid} #{m.id}"
      progressbar.increment
      next
    end

    transcript = json["transcript"]
    unit_date = uid.split("_")

    puts "Generating ai summary"

    ai_summary = ""
    llm.chat(messages: [{role: "user", content: prompt_summary(transcript)}]) do |r|
      resp = r.chat_completion
      ai_summary += resp
      print resp
    end

    puts "Generating ai action items"

    ai_action_items = ""
    llm.chat(messages: [{role: "user", content: prompt_action_items(transcript)}]) do |r|
      resp = r.chat_completion
      ai_action_items += resp
      print resp
    end

    puts

    Meeting.create!(
      topic: topic,
      entry: transcript,
      unit: unit_date[0],
      date: Date.strptime(unit_date[1], "%m%d%Y"),
      uid: uid,
      ai_summary: ai_summary,
      ai_action_items: ai_action_items,
    )

    puts "Processed #{json["uid"]}"
    puts
    progressbar.increment
    puts
  end
end
