# The Reportbooru image. Built and pushed to ghcr.io by .github/workflows/image.yaml.
#
#   docker build -t reportbooru .
#   docker run -e DANBOORU_SHARED_REMOTE_KEY=x -e REDIS_URL=redis://host:6379 -p 3000:3000 reportbooru

ARG RUBY_VERSION=4.0.10

FROM ruby:${RUBY_VERSION}-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*
ENV BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT=development:test BUNDLE_PATH=/usr/local/bundle
WORKDIR /app
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && rm -rf /usr/local/bundle/cache /usr/local/bundle/ruby/*/cache

FROM ruby:${RUBY_VERSION}-slim
# HOME is /tmp so Bundler has somewhere writable when the root filesystem is read-only.
ENV BUNDLE_DEPLOYMENT=1 BUNDLE_WITHOUT=development:test BUNDLE_PATH=/usr/local/bundle HOME=/tmp
WORKDIR /app
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY Gemfile Gemfile.lock .ruby-version config.ru ./
COPY bin bin
COPY config config
COPY lib lib

USER 65534:65534
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
