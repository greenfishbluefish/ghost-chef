FROM ruby:2.2.2
MAINTAINER rob.kinyon@gmail.com

RUN apt-get update -qq \
  && apt-get install -y build-essential 

RUN mkdir -p /tmp/lib/ghost-chef
COPY Gemfile* ghost-chef.gemspec /tmp/
COPY lib/ghost-chef/version.rb /tmp/lib/ghost-chef
WORKDIR /tmp
RUN bundle install

ENV app /app
RUN mkdir -p $app
WORKDIR $app
#ADD . $app

ENTRYPOINT [ "/usr/local/bundle/bin/rspec" ]
