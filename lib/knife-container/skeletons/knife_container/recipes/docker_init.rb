context = KnifeContainer::Generator.context
dockerfile_dir = File.join(context.dockerfiles_path, context.dockerfile_name)
temp_chef_repo = File.join(dockerfile_dir, 'chef')
user_chef_repo = File.join(context.dockerfiles_path, '..')

##
# Initial Setup
#

# Create Dockerfile directory (REPO/NAME)
directory dockerfile_dir do
  recursive true
end

# Dockerfile
template File.join(dockerfile_dir, 'Dockerfile') do
  source 'dockerfile.erb'
  helpers(KnifeContainer::Generator::TemplateHelper)
end

# .dockerfile
template File.join(dockerfile_dir, '.dockerignore') do
  source 'dockerignore.erb'
  helpers(KnifeContainer::Generator::TemplateHelper)
end

# .gitignore
template File.join(dockerfile_dir, '.gitignore') do
  source 'gitignore.erb'
  helpers(KnifeContainer::Generator::TemplateHelper)
end


##
# Initial Chef Setup
#

# create temp chef-repo
directory temp_chef_repo do
  recursive true
end

# Client Config
template File.join(temp_chef_repo, "#{context.chef_client_mode}.rb") do
  source 'config.rb.erb'
  helpers(KnifeContainer::Generator::TemplateHelper)
end

# First Boot JSON
file File.join(temp_chef_repo, 'first-boot.json') do
  content context.first_boot
end

# Node Name
template File.join(temp_chef_repo, '.node_name') do
  source 'node_name.erb'
  helpers(KnifeContainer::Generator::TemplateHelper)
end

##
# Resolve run list
#
require 'chef/run_list/run_list_item'
run_list_items = context.run_list.map { |i| Chef::RunList::RunListItem.new(i) }
cookbooks = []

run_list_items.each do |item|
  # Extract cookbook name from recipe
  if item.recipe?
    rmatch = item.name.match(/(.+?)::(.+)/)
    if rmatch
      cookbooks << rmatch[1]
    else
      cookbooks << item.name
    end
  end
end

# Generate Berksfile from runlist
template File.join(dockerfile_dir, 'Berksfile') do
  source 'berksfile.erb'
  variables({:cookbooks => cookbooks.uniq, :berksfile_source => context.berksfile_source})
  helpers(KnifeContainer::Generator::TemplateHelper)
  only_if { context.generate_berksfile }
end

# Copy over the necessary directories into the temp chef-repo (if local-mode)
if context.chef_client_mode == 'zero'

  # generate a cookbooks directory unless we are building from a Berksfile
  unless context.generate_berksfile
    directory "#{temp_chef_repo}/cookbooks"
  end

  # Copy over cookbooks that are mentioned in the runlist. There is a gap here
  # that dependent cookbooks are not copied. This is a result of not having a
  # depsolver in the chef-client. The solution here is to use the Berkshelf integration.
  if context.cookbook_path.kind_of?(Array)
    context.cookbook_path.each do |dir|
      if File.exists?(File.expand_path(dir))
        cookbooks.each do |cookbook|
          if File.exists?("#{File.expand_path(dir)}/#{cookbook}")
            execute "cp -rf #{File.expand_path(dir)}/#{cookbook} #{temp_chef_repo}/cookbooks/"
          end
        end
      else
        log "Could not find a '#{File.expand_path(dir)}' directory in your chef-repo."
      end
    end
  elsif File.exists?(File.expand_path(context.cookbook_path))
    cookbooks.each do |cookbook|
      if File.exists?("#{File.expand_path(context.cookbook_path)}/#{cookbook}")
        execute "cp -rf #{File.expand_path(context.cookbook_path)}/#{cookbook} #{temp_chef_repo}/cookbooks/"
      end
    end
  else
    log "Could not find a '#{File.expand_path(context.cookbook_path)}' directory in your chef-repo."
  end

  # Because they have a smaller footprint, we will copy over all the roles, environments
  # and nodes. This behavior will likely change in a future version of knife-container.
  %w(role environment node).each do |dir|
    path = context.send(:"#{dir}_path")
    if path.kind_of?(Array)
      path.each do |p|
        execute "cp -r #{File.expand_path(p)}/ #{File.join(temp_chef_repo, "#{dir}s")}" do
          not_if { Dir["#{p}/*"].empty? }
        end
      end
    elsif path.kind_of?(String)
      execute "cp -r #{path}/ #{File.join(temp_chef_repo, "#{dir}s/")}" do
        not_if { Dir["#{path}/*"].empty? }
      end
    end
  end
end

##
# Server Only Stuff
#
if context.chef_client_mode == 'client'

  directory File.join(temp_chef_repo, 'secure')

  # Add validation.pem
  file File.join(temp_chef_repo, 'secure', 'validation.pem') do
    content File.read(context.validation_key)
    mode '0600'
  end

  # Copy over trusted certs
  unless Dir["#{context.trusted_certs_dir}/*"].empty?
    directory File.join(temp_chef_repo, 'secure', 'trusted_certs')
    execute "cp -r #{context.trusted_certs_dir}/* #{File.join(temp_chef_repo, 'secure', 'trusted_certs/')}"
  end

  # Copy over encrypted_data_bag_key
  unless context.encrypted_data_bag_secret.nil?
    if File.exists?(context.encrypted_data_bag_secret)
      file File.join(temp_chef_repo, 'secure', 'encrypted_data_bag_secret') do
       content File.read(context.encrypted_data_bag_secret)
       mode '0600'
      end
    end
  end
end

##
# Create Ohai Plugin
#

# create Ohai folder
# directory File.join(temp_chef_repo, "ohai")

# docker hints directory
# directory File.join(temp_chef_repo, "ohai", "hints")

# docker plugins directory
# directory File.join(temp_chef_repo, "ohai_plugins")

# docker_container Ohai plugin
# cookbook_file File.join(temp_chef_repo, "ohai_plugins", "docker_container.rb") do
#   source "plugins/docker_container.rb"
#   mode "0755"
# end
