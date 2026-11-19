# frozen_string_literal: true

require "test_helper"

class AppTest < Minitest::Test
  include Rack::Test::Methods

  attr_reader :app, :redis, :dynamodb

  def setup
    @redis = Redis.new
    @redis.flushdb
    @dynamodb = Aws::DynamoDB::Client.new(stub_responses: true, region: "us-east-1")
    @app = Reportbooru::App.new(verifier: Reportbooru::MessageVerifier.new("testkey"), redis:, dynamodb:, logger: StringIO.new)
  end

  def today
    Date.today.to_s
  end

  def test_health_check
    get "/up"
    assert_equal 200, last_response.status
  end

  def test_unknown_routes
    get "/hits/day"
    assert_equal 404, last_response.status

    get "/post_searches/other"
    assert_equal 404, last_response.status
  end

  def test_post_searches_are_counted_once_per_session
    post "/post_searches", sig: DANBOORU_SIGNATURES["ps-touhou 1girl,abc123"]
    assert_equal 200, last_response.status
    assert_equal "*", last_response.headers["access-control-allow-origin"]

    post "/post_searches", sig: DANBOORU_SIGNATURES["ps-touhou 1girl,abc123"]
    post "/post_searches", sig: DANBOORU_SIGNATURES["ps-東方　1girl,abc123"]
    post "/post_searches", sig: DANBOORU_SIGNATURES["ps-a,b,abc123"]
    post "/post_searches", sig: DANBOORU_SIGNATURES["ps-solo,"]

    get "/post_searches/rank", date: today
    assert_equal 200, last_response.status
    assert_equal [["1girl touhou", 1.0], ["1girl 東方", 1.0], ["a,b", 1.0], ["solo", 1.0]].sort, JSON.parse(last_response.body).sort
  end

  def test_post_searches_rank_for_a_day_with_no_searches
    get "/post_searches/rank", date: "2020-01-01"
    assert_equal "[]", last_response.body
  end

  def test_post_searches_rejects_bad_requests
    post "/post_searches"
    assert_equal 422, last_response.status

    post "/post_searches", sig: "bogus--abc"
    assert_equal 403, last_response.status
    assert_equal "provided signature is invalid", last_response.body

    post "/post_searches", sig: DANBOORU_SIGNATURES["nonexistent_tag,abc123"]
    assert_equal 422, last_response.status

    get "/post_searches/rank", date: "garbage"
    assert_equal 400, last_response.status

    get "/post_searches/rank"
    assert_equal 400, last_response.status
  end

  def test_prune_keeps_the_top_searches
    counter = Reportbooru::SearchCounter.new(redis:)
    yesterday = Date.today - 1
    150.times { |n| (n + 1).times { |s| counter.count!("tag#{n}", "session#{s}", date: yesterday) } }

    counter.prune!
    ranking = counter.rank(yesterday, 1000)
    assert_equal 99, ranking.size
    assert_equal ["tag149", 150.0], ranking.first
  end

  def test_missed_searches
    post "/missed_searches", sig: DANBOORU_SIGNATURES["nonexistent_tag,abc123"]
    assert_equal 200, last_response.status
    post "/missed_searches", sig: DANBOORU_SIGNATURES["nonexistent_tag,abc123"]

    get "/missed_searches"
    assert_equal 200, last_response.status
    assert_equal "text/plain; charset=utf-8", last_response.content_type
    assert_equal "nonexistent_tag 1.0", last_response.body
  end

  def test_missed_searches_rejects_bad_requests
    post "/missed_searches"
    assert_equal 422, last_response.status

    post "/missed_searches", sig: DANBOORU_SIGNATURE_WITH_PURPOSE
    assert_equal 403, last_response.status
  end

  def test_post_views
    dynamodb.stub_responses(:get_item, { item: { "post_id" => 12345, "count" => 41 } })

    post "/post_views", msg: DANBOORU_SIGNATURES["12345,abc123"]
    assert_equal 200, last_response.status
    assert_equal "42", redis.get("vc-12345")

    post "/post_views", msg: DANBOORU_SIGNATURES["12345,abc123"]
    assert_equal "42", redis.get("vc-12345")

    redis.del("udb-12345")
    post "/post_views", msg: DANBOORU_SIGNATURES["12345,def456"]
    assert_equal "43", redis.get("vc-12345")

    puts_requests = dynamodb.api_requests.select { |r| r[:operation_name] == :put_item }.map { |r| r[:params] }
    assert_includes puts_requests, { table_name: "post_views_production", item: { "post_id" => { n: "12345" }, "count" => { n: "43" } } }
    assert puts_requests.any? { |r| r[:table_name] == "post_view_summaries_production" }

    get "/post_views/rank", date: today
    assert_equal [["12345", 2.0]], JSON.parse(last_response.body)
  end

  def test_post_views_rank_from_dynamodb
    dynamodb.stub_responses(:get_item, { item: { "date" => "2020-01-01", "data" => '[["1",5.0]]' } })

    get "/post_views/rank", date: "2020-01-01"
    assert_equal [["1", 5.0]], JSON.parse(last_response.body)
    assert redis.exists?("vc-rank-json-2020-01-01")
  end

  def test_post_views_rank_with_no_data
    dynamodb.stub_responses(:get_item, { item: nil })

    get "/post_views/rank", date: "2020-01-01"
    assert_equal "null", last_response.body
  end

  def test_post_views_rejects_bad_requests
    post "/post_views"
    assert_equal 422, last_response.status

    post "/post_views", msg: "bogus"
    assert_equal 403, last_response.status
  end

  def test_errors_return_500
    dynamodb.stub_responses(:get_item, "ServiceError")

    get "/post_views/rank", date: "2020-01-01"
    assert_equal 500, last_response.status
  end
end
