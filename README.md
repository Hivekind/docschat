# README
This is a repository accompanying the [blogpost](https://hivekind.com/blog/building-a-meeting-ai-assistant-with-ruby-cost-effective-strategies-using-ollama-langchain?utm_campaign=brand&utm_medium=post&utm_source=github&utm_content=readme)

It ingests a set of meeting notes called [meetingbank](https://huggingface.co/datasets/huuuyeah/meetingbank) creates summaries for each of the entries via a local Ollama instance. The Rails application then displays the meeting notes, along with the pre-generated summaries, and a chat window where you can queryan LLM about the specific meeting selected. The LLM uses the currently selected meeting as well as the chat history as context for its replies.

This application also highlights the importance of cleaning your sources, as shown below where the LLM tries to confidently assert that there's some tension tension in the meeting when in fact there was a mistranscription in the notes.

![docschat screenshot](http://images.ctfassets.net/wopbg9d9upg6/7eHo7723VXAaoLTVwkOOaR/d32fb4df1b4521ed270a07dcc0d1c8d5/docsChat.png)

## Setup

1. Install Ollama https://ollama.com/download/linux
1. `ollama run gemma2:2b` to download the model
1. `docker compose up` to run postgres with pgvector
1. `ruby seeds.rb` to seed the database (optional if not using the pre-generated seeds)
1. `bin/setup` to setup dependencies

## Resources, Inspirations, and References

1. https://github.com/patterns-ai-core/langchainrb/blob/main/lib/langchain/llm/ollama.rb
1. https://github.com/rails/rails/tree/main/guides/bug_report_templates
1. https://greg.molnar.io/blog/a-single-file-rails-application/
1. https://github.com/hopsoft/sr_mini
1. https://thoughtbot.com/blog/talking-to-actioncable-without-rails
1. https://www.mintbit.com/blog/subscribing-sending-and-receiving-actioncable-messages-with-js
1. https://github.com/sonyarianto/react-without-buildsteps
