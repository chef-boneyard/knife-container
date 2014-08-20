# Knife Container Changelog

## v1.0.0 (unreleased)
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

## v0.2.1 (2014-08-15)
* [GH23] Specify hostname during knife container build

## v0.2.0 (2014-07-16)
* `knife container docker init` - Initialize a Docker context on your local workstation.
* `knife container docker build` - Build a Docker image on your local workstation.
