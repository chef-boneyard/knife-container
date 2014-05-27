Knife Container
================
[![Gem Version](https://badge.fury.io/rb/knife-container.png)](http://badge.fury.io/rb/knife-container)

This plugin gives knife the ability to initialize and build Docker Containers.

Installation
------------

### Building Locally
```bash
gem build knife-container.gemspec
gem install knife-container-0.0.1.gem
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

1. Fork it ( https://github.com/[my-github-username]/knife-container/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
