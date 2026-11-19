# frozen_string_literal: true

require "date"
require "digest/md5"

module Reportbooru
  # Helpers shared by the search counters.
  module RedisCounter
    DAY = 24 * 60 * 60

    attr_reader :redis

    def initialize(redis:)
      @redis = redis
    end

    private

    # Normalize a search so that "Touhou  1girl" and "1girl touhou" are counted as the same search.
    def normalize_tags(tags)
      tags.to_s.gsub(/　/, " ").downcase.strip.scan(/\S+/).uniq.sort.join(" ")
    end

    def tags_hash(tags)
      Digest::MD5.hexdigest(tags)
    end

    def date_key(date)
      date.strftime("%Y%m%d")
    end
  end
end
