env "MAILTO", "r888888888@gmail.com"

every 1.day do
  runner "HitCounter.new.prune!"
end

every 1.day do
	runner "Archive::PostVersion.export_missing(48.hours.ago)"
end

every :sunday, :at => "1:00 am" do
  runner "BigQuery::Tag.new.export!"
end

every :sunday, :at => "2:00 am" do
  runner "BigQuery::User.new.export!"
end

every :sunday, :at => "3:00 am" do
  runner "Reports.generate_all"
end

every '0 6 1,15 * *' do
	runner "MessagedReports::MissingTags.new.send_messages"
end
