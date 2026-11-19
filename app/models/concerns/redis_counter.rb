module Concerns
  module RedisCounter
    def client
      @client ||= Redis.new
    end

    def hash(string)
      Digest::MD5.hexdigest(string)
    end

    def normalize_tags(tags)
      tags.to_s.gsub(/\u3000/, " ").downcase.strip.scan(/\S+/).uniq.sort.join(" ")
    end
  end
end
