env "MAILTO", "webmaster@danbooru.donmai.us"

every 1.day do
  runner "HitCounter.new.prune!"
end
