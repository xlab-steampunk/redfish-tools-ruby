# Redfish tools

[![Build Status](https://travis-ci.com/xlab-si/redfish_tools.svg?branch=master)](https://travis-ci.com/xlab-si/redfish_tools)


This repository contains source code for redfish_tools gem that contains tools
for testing application that know how to work with Redfish API.

The only tool that is currently available is mock server, but in the near
future, we will also add a mock creator tool and interactive inspector for
Redfish services.


## Installation

Add this line to your application's Gemfile:

    gem "redfish_tools"

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install redfish_tools


## Usage

The simplest way to start using Redfish tools is to simply run the `redfish`
command and read the provided help. At the moment, the output should look like
this:

    $ redfish
    Commands:
      redfish help [COMMAND]        # Describe available commands
      redfish serve [OPTIONS] PATH  # serve mock from PATH

To start serving existing Redfish recording, we run the `serve` command:

    $ redfish serve --ssl --user test --pass demo path/to/recording

To get the description of all available options, use `help` command or add
`-h` flag anywhere in the command.


## Development

After checking out the repo, run `bin/setup` to install dependencies.
Unfortunately, this gem contains no tests at the moment, so if you feel like
contributing, this would be a great place to start.

To create new release, increment the version number, commit the change, tag
the commit and push tag to the GitHub. Travis CI will pick from there on and
create new release, publishing it on https://rubygems.org.


## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/xlab-si/redfish_tools.
