Reportbooru tracks post view counts, post search counts, and missed search counts for
[Danbooru](https://danbooru.donmai.us). Counts are kept in Redis, and post view counts are
persisted to DynamoDB.

It's a plain Rack app run by Puma. See `lib/reportbooru/app.rb` for the endpoints and
`lib/reportbooru.rb` for the environment variables it uses (`.env-SAMPLE` has an example).

## Development

```bash
bundle install
DANBOORU_SHARED_REMOTE_KEY=x bundle exec puma -C config/puma.rb
```

The tests need a Redis server. They use database 15 and flush it.

```bash
REDIS_URL=redis://localhost:6379/15 bundle exec rake test
```

`bin/prune-search-rankings` trims yesterday's post search ranking and should run once a day.
