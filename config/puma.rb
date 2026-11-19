# frozen_string_literal: true

# Puma config. See https://puma.io/puma/Puma/DSL.html.

threads_count = Integer(ENV.fetch("PUMA_THREADS", 5))
threads threads_count, threads_count
workers Integer(ENV.fetch("WEB_CONCURRENCY", 0))
port Integer(ENV.fetch("PORT", 3000))
preload_app!
