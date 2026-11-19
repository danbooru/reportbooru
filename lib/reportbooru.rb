# frozen_string_literal: true

require "aws-sdk-dynamodb"
require "redis"

require_relative "reportbooru/app"

# Reportbooru tracks post view counts, post search counts, and missed search counts for Danbooru.
#
# Configured with environment variables:
# - DANBOORU_SHARED_REMOTE_KEY: the key Danbooru signs requests with (DANBOORU_REPORTBOORU_KEY in Danbooru).
# - REDIS_URL: defaults to redis://localhost:6379.
# - AWS_REGION, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY: for DynamoDB.
# - TZ: the time zone used for daily counts.
module Reportbooru
  def self.redis
    @redis ||= Redis.new
  end

  def self.dynamodb
    @dynamodb ||= Aws::DynamoDB::Client.new
  end

  def self.app
    verifier = MessageVerifier.new(ENV.fetch("DANBOORU_SHARED_REMOTE_KEY"))
    App.new(verifier:, redis:, dynamodb:)
  end
end
