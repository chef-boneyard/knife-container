# Knife Container Changelog

## v0.3.0 (unreleased)
* Added 'docker container rebuild' subcommand
* Added `Chef::Config[:knife][:docker_image]` configuration value to allow for the
specification of what the default Docker Image should be. The default value is
`chef/ubuntu-12.04:latest`
* Added `Chef::Config[:knife][:berksfile_source]` configuration value to allow for
specification of which source you'd like to use in a generated Berksfile. The
default value is `https://supermarket.getchef.com`.
* [GH-6] Use supermarket as the default Berkshelf source.
* [FSE-188] Method for stripping secure credentials resulted in intermediate
image with those credentials still present. Stripping out those intermediate
layers is now the responsibility of `chef-init --bootstrap`. Reported by Andrew
Hsu.
* Docker commands are now done directly via Docker API instead of shelling out
to Docker CLI.
* [GH-27] Added `--data-bag-path` option. Copies over data bags.
* [FSE-201] Update knife-container to support ChefDK and Chef 12 libraries
* [FSE-205] Add plugin architecture to manage 3rd party integrations with tools
like Docker and Berkshelf.

## v0.2.3 (2014-09-19)
* [GH-39] Fixed `--dockerfiles-path` parameter which did not properly accept input.
* [GH-38] Fixed issue where cookbooks would appear more than once in the Berksfile.

## v0.2.2 (2014-09-08)
* [GH-34] Update gemspec to support Chef12.

## v0.2.1 (2014-08-15)
* [GH-23] Specify hostname during knife container build

## v0.2.0 (2014-07-16)
* `knife container docker init` - Initialize a Docker context on your local workstation.
* `knife container docker build` - Build a Docker image on your local workstation.
