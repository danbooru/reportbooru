# frozen_string_literal: true

require "date"
require "json"

module Reportbooru
  # Counts post views, once per session per day. Redis is used as a cache in front of DynamoDB.
  #
  # Redis keys:
  # - hll-<YYYY-MM-DD>-<post id>: HyperLogLog of the sessions that viewed a post that day. Expires after 1 day.
  # - vc-<post id>: all-time view count for a post. Expires after 1 day; reloaded from DynamoDB.
  # - vc-rank-<YYYY-MM-DD>: sorted set of posts by views that day. Expires after 1 day.
  # - vc-rank-json-<YYYY-MM-DD>: the day's ranking loaded from DynamoDB. Expires after 1 day.
  # - udb-<post id>, udb-rank: set after writing to DynamoDB, to limit how often we write.
  #
  # DynamoDB tables:
  # - post_views_production: { post_id, count }
  # - post_view_summaries_production: { date, data } where data is the day's ranking as JSON.
  class ViewCounter
    DAY = 24 * 60 * 60
    LIMIT = 100
    POST_VIEWS_TABLE = ENV.fetch("POST_VIEWS_TABLE", "post_views_production")
    POST_VIEW_SUMMARIES_TABLE = ENV.fetch("POST_VIEW_SUMMARIES_TABLE", "post_view_summaries_production")

    attr_reader :redis, :dynamodb, :date_key

    def initialize(redis:, dynamodb:, date: Date.today)
      @redis = redis
      @dynamodb = dynamodb
      @date_key = date.to_s
    end

    def count!(post_id, session_id)
      if unique?(post_id, session_id)
        val = increment_redis_count(post_id)
        add_rank(post_id)
        redis.setex("udb-#{post_id}", 10, "1")
        val
      else
        redis.get("vc-#{post_id}").to_i
      end
    end

    # @param date [String] the date (YYYY-MM-DD)
    # @return [Array<Array<(String, Float)>>, nil] the most viewed posts that day and their view counts
    def rank(date, limit = LIMIT)
      if redis.exists?("vc-rank-json-#{date}")
        JSON.parse(redis.get("vc-rank-json-#{date}"))
      elsif redis.exists?("vc-rank-#{date}")
        redis.zrevrange("vc-rank-#{date}", 0, limit, with_scores: true)
      else
        fetch_rank(date)
      end
    end

    private

    def unique?(post_id, session_id)
      key = "hll-#{date_key}-#{post_id}"
      return false unless redis.pfadd(key, session_id)

      redis.expire(key, DAY)
      true
    end

    def increment_redis_count(post_id)
      key = "vc-#{post_id}"
      return fetch_post_view_count(post_id) unless redis.exists?(key)

      val = redis.incr(key)
      redis.expire(key, DAY)
      update_dynamodb_count(post_id, val) if redis.get("udb-#{post_id}").nil?
      val
    end

    def fetch_post_view_count(post_id)
      resp = dynamodb.get_item(table_name: POST_VIEWS_TABLE, key: { "post_id" => post_id.to_i })
      val = resp.item ? resp.item["count"].to_i + 1 : 1
      redis.setex("vc-#{post_id}", DAY, val)
      val
    end

    def update_dynamodb_count(post_id, count)
      dynamodb.put_item(table_name: POST_VIEWS_TABLE, item: { "post_id" => post_id, "count" => count })
    end

    def add_rank(post_id)
      key = "vc-rank-#{date_key}"
      redis.zincrby(key, 1, post_id)
      redis.expire(key, DAY)
      update_dynamodb_rank(date_key, rank(date_key).to_json) if redis.get("udb-rank").nil?
    end

    def update_dynamodb_rank(date, json)
      dynamodb.put_item(table_name: POST_VIEW_SUMMARIES_TABLE, item: { "date" => date, "data" => json })
      redis.setex("udb-rank", 60, "1")
    end

    def fetch_rank(date)
      resp = dynamodb.get_item(table_name: POST_VIEW_SUMMARIES_TABLE, key: { "date" => date })
      return nil unless resp.item

      redis.setex("vc-rank-json-#{date}", DAY, resp.item["data"])
      JSON.parse(resp.item["data"])
    end
  end
end
