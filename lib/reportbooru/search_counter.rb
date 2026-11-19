# frozen_string_literal: true

require_relative "redis_counter"

module Reportbooru
  # Counts post searches, once per session per day.
  #
  # Redis keys:
  # - ps-<md5 of tags>-<YYYYMMDD>: HyperLogLog of the sessions that did a search that day. Expires after 2 days.
  # - ps-day-<YYYYMMDD>: sorted set of searches by number of sessions. Never expires; trimmed by #prune!.
  class SearchCounter
    include RedisCounter

    LIMIT = 100

    def count!(tags, session_id, date: Date.today)
      tags = normalize_tags(tags)
      key = "ps-#{tags_hash(tags)}-#{date_key(date)}"
      return unless redis.pfadd(key, session_id)

      redis.pipelined do |pipeline|
        pipeline.expire(key, 2 * DAY)
        pipeline.zincrby("ps-day-#{date_key(date)}", 1, tags)
      end
    end

    # @return [Array<Array<(String, Float)>>] the top searches and their counts
    def rank(date, limit = LIMIT)
      redis.zrevrange("ps-day-#{date_key(date)}", 0, limit, with_scores: true)
    end

    # Drop everything except the top searches for the day.
    def prune!(date = Date.today - 1)
      redis.zremrangebyrank("ps-day-#{date_key(date)}", 0, -LIMIT)
    end
  end
end
