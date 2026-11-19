env "MAILTO", "webmaster@danbooru.donmai.us"

every 1.day do
  runner "SearchCounter.new.prune!"
end
