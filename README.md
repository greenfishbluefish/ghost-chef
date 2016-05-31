# AWS Idempotency Gem

This is a junkdrawer of idempotent AWS functionality. It needs to be organized and properly API'ed. This code is very much alpha and will break repeatedly.

# require the gem with bundler

```
gem 'aws-idempotency', '0.0.0', :git => 'git@github.com:greenfishbluefish/aws-idempotency.git'
```

# Running the tests

## Using Docker

There is a Dockerfile for running the test suite. This ensures the same 

### Initial steps

* `docker build -t aws-idempotency`

You will also need to do this if the Gemfile ever changes.

### Running

* With defaults:
  * `docker run -v $(pwd):/app -t aws-idempotency`
* With rspec options (like --seed):
  * `docker run -v $(pwd):/app -t aws-idempotency <rspec options>`
* To hop in and see what's going on:
  * `docker run -v $(pwd):/app -t --entrypoint=/bin/bash aws-idempotency`
