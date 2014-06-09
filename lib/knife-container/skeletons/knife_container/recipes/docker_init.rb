context = KnifeContainer::Generator.context
dockerfile_dir = File.join(context.dockerfiles_path, context.dockerfile_name)
temp_chef_repo = File.join(dockerfile_dir, "chef")

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

# Dockerfile directory (REPO/NAME)
directory dockerfile_dir do
  recursive true
end

# create temp chef-repo
directory temp_chef_repo do
  recursive true
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
          execute "cp -rf #{File.expand_path(dir)}/#{cookbook} #{temp_chef_repo}/cookbooks/"
        end
      else
        log "Source cookbook directory not found."
      end
    end
  elsif File.exists?(File.expand_path(cookbook_dir))
    directory "#{temp_chef_repo}/cookbooks"
    context.send(:run_list).each do |cookbook|
      execute "cp -rf #{File.expand_path(cookbook_dir)}/#{cookbook.match(/recipe\[(.*)\]/)[1]} #{temp_chef_repo}/cookbooks/"
    end
  else
    log "Source cookbook directory not found."
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

# Add validation.pem (if server-mode)
if context.chef_client_mode == "client"
  file File.join(temp_chef_repo, "validation.pem") do
    content File.read(context.validation_key)
    mode '0600'
  end
end

directory File.join(temp_chef_repo, "ohai")

# docker hints directory
directory File.join(temp_chef_repo, "ohai", "hints")

# docker plugins directory
directory File.join(temp_chef_repo, "ohai", "plugins")

# docker_container Ohai plugin
cookbook_file File.join(temp_chef_repo, "ohai", "plugins", "docker_container.rb") do
  source "plugins/docker_container.rb"
  mode "0755"
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

# Dockerfile
template "#{dockerfile_dir}/Dockerfile" do
  source "dockerfile.erb"
  helpers(KnifeContainer::Generator::TemplateHelper)
end
