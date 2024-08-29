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
