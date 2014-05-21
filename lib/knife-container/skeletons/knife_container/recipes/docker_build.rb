
# Create tarball
#execute "tar -czvf #{::File.join(dockerfile_dir, 'chef.tar.gz')} ./*" do
#  cwd temp_chef_repo
#end

## Build Docker image
#execute "docker build -t #{context.dockerfile_name} #{dockerfile_dir}"
#
## Remove temp chef-repo
#directory temp_chef_repo do
#  action :delete
#end
