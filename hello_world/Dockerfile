FROM ruby:2.7.4-slim

RUN mkdir -p /app
WORKDIR /app

COPY . .
RUN bundle install

CMD ["bundle", "exec", "ruby", "app.rb", "-o", "0.0.0.0"]
