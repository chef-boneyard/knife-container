Knife Container
================
[![Gem Version](https://badge.fury.io/rb/knife-container.png)](http://badge.fury.io/rb/knife-container) [![Build Status](https://travis-ci.org/opscode/knife-container.svg?branch=master)](https://travis-ci.org/opscode/knife-container)

This plugin gives knife the ability to initialize and build Docker Containers.

Installation
------------

### Building Locally
```bash
rake install
```

Subcommands
-----------

#### `knife docker init`
Initializes a new docker image configuration. This command creates the underlying content use during the build process and can include a Dockerfile, Berksfile, cookbooks and chef-client configuration files.

  # Initializing a bare image repository using chef/ubuntu_12.04 as the base image
  `knife docker init your_username/image_name -f chef/ubuntu_12.04`

  # Passing a run_list during initialization
  `knife docker init your_username/nginx -f chef/ubuntu_12.04 -r 'recipe[apt],recipe[nginx]'`

  # Using chef-zero to bundle cookbooks into an image
  `knife docker init your_username/nginx -f chef/ubuntu_12.04 -r 'recipe[apt],recipe[nginx]' -z`

### `knife docker build REPO/NAME (options)`


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

