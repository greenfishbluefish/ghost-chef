FROM ruby:2.2.2
MAINTAINER rob.kinyon@gmail.com

RUN apt-get update -qq \
  && apt-get install -y build-essential 

COPY Gemfile* ghost-chef.gemspec /tmp/
WORKDIR /tmp
RUN bundle install

ENV app /app
RUN mkdir -p $app
WORKDIR $app

ENTRYPOINT [ "/usr/local/bundle/bin/rspec" ]
