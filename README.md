# Knife Container
[![Gem Version](https://badge.fury.io/rb/knife-container.png)](http://badge.fury.io/rb/knife-container)
[![Build Status](https://travis-ci.org/opscode/knife-container.svg?branch=master)](https://travis-ci.org/opscode/knife-container)

This is the official Chef plugin for Linux Containers. This plugin gives knife
the ability to initialize and build Linux Containers.

For full documentation, including examples, please check out [the docs site](http://docs.opscode.com/plugin_knife_container.html).

## Installation

### Build Locally
If you would like to build the gem from source locally, please clone this
repository on to your local machine and build the gem locally.
    $ bundle install
    $ bundle exec rake install

## Subcommands
This plugin provides the following Knife subcommands. Specific command options
can be found by invoking the subcommand with a `--help` flag.

#### `knife container docker init`
Initializes a new folder that will hold all the files and folders necessary to
 build a Docker image called a “Docker context.” This files and folders that can
 make up your Docker context include a Dockerfile, Berksfile, cookbooks and
 chef-client configuration files.

#### `knife container docker build`
Builds a Docker image based on the Docker context specified. If the image was
initialized using the `-z` flag and a Berksfile exists, it will run `berks vendor`
and vendor the required cookbooks into the required directory. If the image was
initialized without the `-z` flag and a Berksfile exists, it will run
`berks upload` and upload the required cookbooks to you Chef Server.

## Contributing
Please read [CONTRIBUTING.md](CONTRIBUTING.md)

## License
Full License: [here](LICENSE)

Knife-Container - a Knife plugin for chef-container

Author:: Tom Duffield (<tom@getchef.com>)  
Author:: Michael Goetz (<mpgoetz@getchef.com>)

Copyright:: Copyright (c) 2012-2014 Chef Software, Inc.  
License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
