require 'chef/container'

chef_server_url         'https://api.example.com/organizations/docker'
validation_client_name  'docker-validator'
ssl_verify_mode         :verify_peer