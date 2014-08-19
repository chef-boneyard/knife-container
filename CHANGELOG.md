# Knife Container Changelog

## Unreleased
* [FSE-188] Method for stripping secure credentials resulted in intermediate
image with those credentials still present. Stripping out those intermediate
layers is now the responsibility of `chef-init --bootstrap`. Reported by Andrew
Hsu.

## v0.2.1 (2014-08-15)
* [GH23] Specify hostname during knife container build

## v0.2.0 (2014-07-16)
* `knife container docker init` - Initialize a Docker context on your local workstation.
* `knife container docker build` - Build a Docker image on your local workstation.
