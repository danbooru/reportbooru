# frozen_string_literal: true

require_relative "redis_counter"

module Reportbooru
  # Counts searches that returned no results, once per session per day.
  #
  # Redis keys:
  # - msc-<md5 of tags>-<YYYYMMDD>: HyperLogLog of the sessions that did a search that day. Expires after 1 day.
  # - msc-<YYYYMMDD>: sorted set of missed searches by number of sessions. Expires after 7 days.
  # - msc-all: the union of the last 7 days, rebuilt by #rank.
  class MissedSearchCounter
    include RedisCounter

    LIMIT = 100

    def count!(tags, session_id, date: Date.today)
      tags = normalize_tags(tags)
      key = "msc-#{tags_hash(tags)}-#{date_key(date)}"
      return unless redis.pfadd(key, session_id)

      redis.pipelined do |pipeline|
        pipeline.expire(key, DAY)
        pipeline.zincrby("msc-#{date_key(date)}", 1, tags)
        pipeline.expire("msc-#{date_key(date)}", 7 * DAY)
      end
    end

    # @return [Array<Array<(String, Float)>>] the top missed searches over the last 7 days and their counts
    def rank(date: Date.today)
      keys = 7.times.map { |n| "msc-#{date_key(date.prev_day(n))}" }
      redis.zunionstore("msc-all", keys)
      redis.zrevrange("msc-all", 0, LIMIT, with_scores: true)
    end
  end
end
