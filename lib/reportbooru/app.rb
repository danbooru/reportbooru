# frozen_string_literal: true

require "date"
require "json"
require "rack"

require_relative "message_verifier"
require_relative "search_counter"
require_relative "missed_search_counter"
require_relative "view_counter"

module Reportbooru
  # The Rack app.
  #
  # Danbooru's post pages and search pages send counts here with navigator.sendBeacon, signed with the shared key.
  # Danbooru reads the rankings back for the explore pages and the popular searches sidebar (see
  # ReportbooruService in Danbooru).
  #
  #   POST /post_searches      sig=<signed "ps-<tags>,<session id>">
  #   POST /missed_searches    sig=<signed "<tags>,<session id>">
  #   POST /post_views         msg=<signed "<post id>,<session id>">
  #   GET  /post_searches/rank?date=YYYY-MM-DD   JSON [[tags, count], ...]
  #   GET  /post_views/rank?date=YYYY-MM-DD      JSON [[post id, count], ...] or null
  #   GET  /post_views/<post id>                 text all-time view count (used by userscripts)
  #   GET  /missed_searches                      text "<tags> <count>" lines, last 7 days
  #   GET  /up                                   health check
  class App
    def initialize(verifier:, redis:, dynamodb:, logger: $stderr)
      @verifier = verifier
      @redis = redis
      @dynamodb = dynamodb
      @logger = logger
      @search_counter = SearchCounter.new(redis:)
      @missed_search_counter = MissedSearchCounter.new(redis:)
    end

    def call(env)
      request = Rack::Request.new(env)
      route(request)
    rescue MessageVerifier::InvalidSignature
      text(403, "provided signature is invalid")
    rescue Date::Error, Rack::BadRequest
      text(400, "bad request")
    rescue StandardError => e
      @logger.puts("#{e.class}: #{e.message}\n  #{e.backtrace&.first(10)&.join("\n  ")}")
      text(500, "internal server error")
    end

    private

    def route(request)
      case [request.request_method, request.path_info]
      in ["GET", "/up"]
        text(200, "ok")

      in ["POST", "/post_searches"]
        return empty(422) unless request.params["sig"]

        key, session_id = verify(request.params["sig"])
        return empty(422) unless key.start_with?("ps-")

        @search_counter.count!(key.delete_prefix("ps-"), session_id)
        empty(200)

      in ["POST", "/missed_searches"]
        return empty(422) unless request.params["sig"]

        tags, session_id = verify(request.params["sig"])
        @missed_search_counter.count!(tags, session_id)
        empty(200)

      in ["POST", "/post_views"]
        return empty(422) unless request.params["msg"]

        post_id, session_id = verify(request.params["msg"])
        view_counter.count!(post_id.to_i, session_id)
        empty(200)

      in ["GET", "/post_searches/rank"]
        json(@search_counter.rank(date_param(request)))

      in ["GET", "/post_views/rank"]
        json(view_counter.rank(date_param(request).to_s))

      in ["GET", %r{\A/post_views/\d+\z}]
        text(200, view_counter.count(request.path_info.delete_prefix("/post_views/").to_i).to_s)

      in ["GET", "/missed_searches"]
        text(200, @missed_search_counter.rank.map { |tags, count| "#{tags} #{count}" }.join("\n"))

      else
        empty(404)
      end
    end

    # Verify a signed "<value>,<session id>" message. Split at the last comma, since searches can contain commas.
    # @return [Array<(String, String)>] the value and the session id
    def verify(signed_message)
      message = @verifier.verify(signed_message)
      value, separator, session_id = message.rpartition(",")
      separator.empty? ? [message, ""] : [value, session_id]
    end

    def date_param(request)
      Date.iso8601(request.params["date"].to_s)
    end

    def view_counter
      ViewCounter.new(redis: @redis, dynamodb: @dynamodb)
    end

    def empty(status)
      [status, cors_headers, []]
    end

    def text(status, body)
      [status, cors_headers.merge("content-type" => "text/plain; charset=utf-8"), [body]]
    end

    def json(data)
      [200, cors_headers.merge("content-type" => "application/json"), [data.to_json]]
    end

    def cors_headers
      { "access-control-allow-origin" => "*" }
    end
  end
end
