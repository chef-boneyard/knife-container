FROM chef/ubuntu_12.04
ADD chef/ /etc/chef/
RUN chef-client -c /etc/chef/client.rb -j /etc/chef/first-boot.json
ENTRYPOINT ["chef-init"]
CMD ["--onboot"]