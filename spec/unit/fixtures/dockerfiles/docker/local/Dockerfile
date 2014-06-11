FROM chef/ubuntu_12.04
ADD chef/ /chef/
RUN chef-client -c /chef/zero.rb -j /chef/first-boot.json -z
ENTRYPOINT ["chef-init"]
CMD ["--onboot"]