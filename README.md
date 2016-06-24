# Ghost-Chef

This is a subset of AWS functionality which has idempotent wrappers over it. It
intends to provide a way of treating this limited subset of AWS capabilities in
the same way as we would treat Chef-managed resources.

# require the gem with bundler

```
gem 'ghost-chef', '0.0.0', :git => 'git@github.com:greenfishbluefish/ghost-chef.git'
```

# Running the tests

## Using Docker

There is a Dockerfile for running the test suite. This ensures the same 

### Initial steps

* `docker build -t ghost-chef`

You will also need to do this if the Gemfile ever changes.

### Running

* With defaults:
  * `docker run -v $(pwd):/app -t ghost-chef`
* With rspec options (like --seed):
  * `docker run -v $(pwd):/app -t ghost-chef <rspec options>`
* To hop in and see what's going on:
  * `docker run -v $(pwd):/app -t --entrypoint=/bin/bash ghost-chef`

### Useful Docker commands

* Remove all stopped containers:
  * `docker rm $(docker ps --no-trunc -aq)`
  * Useful after running the test suite multiple times.
* Remove all untagged images:
  * `docker rmi $(docker images | grep "^<none>" | awk '{print $3}')`
  * Useful if you built without tagging

# TODO

- General
  - [ ] Ensure in the test suite that additional calls to the AWS SDK are flagged as an error
- IAM
  - [ ] Provide a way of setting the assume role policy document.
