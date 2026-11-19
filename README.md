Reportbooru tracks post view counts, post search counts, and missed search counts for
[Danbooru](https://danbooru.donmai.us). Counts are kept in Redis, and post view counts are
persisted to DynamoDB.

You can deploy using Capistrano. It's recommended you fork this project and
modify the following files:

* config/deploy/production.rb
* .env

A sample .env file called .env-SAMPLE is included in the project. The .env
file itself is symlinked during deployment so you should create a version on
the server at /var/www/reportbooru/shared/.env.
