# README

## Setup

```bash
bundle install
rails db:drop db:create db:migrate db:seed
rails s
```

## Credentials and Master Key

Master Key is in my notes. Ask me for it.

To edit credentials:

```
EDITOR="code --wait" bin/rails credentials:edit
```

## Deploy to DigitalOcean App Platform

- Go to DigitalOcean and create a new App
- Select the GitHub repo and the branch to deploy (usually main)
- Add a PostgeSQL database
- Add the Rails RAILS_MASTER_KEY environment variable with the content from config/master.key
- Deploy and wait for the build to finish (everytime you push to main, it will deploy automatically)

If you start the app for the first time you need to create a user. Go to the app in DigitalOcean
and click on the console. Then run:

```bash
bin/rails c
password = SecureRandom.hex(10)
AdminUser.create(email: 'admin@example.com', password: password, password_confirmation: password)
AdminUser.create(email: 'schneikai@gmail.com', password: password, password_confirmation: password)
puts "User created with password: #{password}"
```
