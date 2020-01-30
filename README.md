# Redfish tools

[![Build Status](https://travis-ci.com/xlab-si/redfish_tools.svg?branch=master)](https://travis-ci.com/xlab-si/redfish_tools)


This repository contains source code for redfish_tools gem that contains
helpers for testing application that know how to work with Redfish API.

The main entry point is the `redfish` command that offers a mock Redfish
server, a mock server-side events (SSE) server, and a redfish recorder for
taking a snapshot of an existing Redfish API among other things. Consult the
built-in help for more information about the available commands.


## Installation

Create a new *Gemfile* with the following content:

    source "https://rubygems.org" do
      gem "redfish_tools"
    end

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
      redfish help [COMMAND]              # Describe available commands or one specific command
      redfish listen_sse ADDRESS          # listen to events from ADDRESS
      redfish record SERVICE PATH         # create recording of SERVICE in PATH
      redfish serve [OPTIONS] PATH        # serve mock from PATH
      redfish serve_sse [OPTIONS] SOURCE  # serve events from SOURCE

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
