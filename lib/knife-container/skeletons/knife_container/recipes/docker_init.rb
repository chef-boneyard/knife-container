context = KnifeContainer::Generator.context
dockerfile_dir = File.join(context.dockerfiles_path, context.dockerfile_name)
temp_chef_repo = File.join(dockerfile_dir, "chef")
user_chef_repo = File.join(context.dockerfiles_path, "..")

##
# Initial Setup
#

# Create Dockerfile directory (REPO/NAME)
directory dockerfile_dir do
  recursive true
end

# Dockerfile
template File.join(dockerfile_dir, "Dockerfile") do
  source "dockerfile.erb"
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
  source "config.rb.erb"
  helpers(KnifeContainer::Generator::TemplateHelper)
end

# First Boot JSON
file File.join(temp_chef_repo, "first-boot.json") do
  content context.first_boot
end


##
# Resolve run list
#
require 'chef/run_list/run_list_item'
run_list_items = context.send(:run_list).map { |i| Chef::RunList::RunListItem.new(i) }
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
unless context.run_list.empty?
  template File.join(dockerfile_dir, "Berksfile") do
    source "berksfile.erb"
    variables :cookbooks => cookbooks
    helpers(KnifeContainer::Generator::TemplateHelper)
    only_if { context.generate_berksfile }
  end
end

# Symlink the necessary directories into the temp chef-repo (if local-mode)
if context.chef_client_mode == "zero"
  cookbook_dir = context.send(:cookbook_path)
  role_dir = context.send(:role_path)
  env_dir = context.send(:environment_path)
  node_dir = context.send(:node_path)

  if cookbook_dir.kind_of?(Array)
    cookbook_dir.each do |dir|
      if File.exists?(File.expand_path(dir))
        directory "#{temp_chef_repo}/cookbooks"
        cookbooks.each do |cookbook|
          execute "cp -rf #{File.expand_path(dir)}/#{cookbook} #{temp_chef_repo}/cookbooks/" do
            only_if { File.exists?("#{File.expand_path(dir)}/#{cookbook}") }
          end
        end
      else
        log "Could not find a 'cookbooks' directory in your chef-repo."
      end
    end
  elsif File.exists?(File.expand_path(cookbook_dir))
    directory "#{temp_chef_repo}/cookbooks"
    cookbooks.each do |cookbook|
      execute "cp -rf #{File.expand_path(dir)}/#{cookbook} #{temp_chef_repo}/cookbooks/" do
        only_if { File.exists?("#{File.expand_path(dir)}/#{cookbook}") }
      end
    end
  else
    log "Could not find a 'cookbooks' directory in your chef-repo."
  end

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
if context.chef_client_mode == "client"

  # Add validation.pem
  file File.join(temp_chef_repo, "validation.pem") do
    content File.read(context.validation_key)
    mode '0600'
  end

  # Copy over trusted certs
  unless Dir["#{context.trusted_certs_dir}/*"].empty?
    directory File.join(temp_chef_repo, "trusted_certs")
    execute "cp -r #{context.trusted_certs_dir}/* #{File.join(temp_chef_repo, "trusted_certs/")}"
  end

  # Copy over encrypted_data_bag_key
  file File.join(temp_chef_repo, "encrypted_data_bag_secret") do
   content File.read(context.encrypted_data_bag_secret)
   mode '0600'
   only_if { File.exists?(File.join(context.encrypted_data_bag_secret)) }
  end

end

##
# Create Ohai Plugin
#

# create Ohai folder
directory File.join(temp_chef_repo, "ohai")

# docker hints directory
directory File.join(temp_chef_repo, "ohai", "hints")

# docker plugins directory
directory File.join(temp_chef_repo, "ohai_plugins")

# docker_container Ohai plugin
cookbook_file File.join(temp_chef_repo, "ohai_plugins", "docker_container.rb") do
  source "plugins/docker_container.rb"
  mode "0755"
end
