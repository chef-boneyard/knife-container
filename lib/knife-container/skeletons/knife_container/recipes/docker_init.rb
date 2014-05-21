
context = KnifeContainer::Generator.context
dockerfile_dir = File.join(context.dockerfiles_path, context.dockerfile_name)
temp_chef_repo = File.join(dockerfile_dir, "chef")


# Dockerfile directory (REPO/NAME)
directory dockerfile_dir do
  recursive true
end

# create temp chef-repo
directory temp_chef_repo do
  recursive true
end

# Symlink the necessary directories into the temp chef-repo (if local-mode)
if context.chef_client_mode == "zero"
  %w(cookbook role environment node).each do |dir|
    link ::File.join(temp_chef_repo, "#{dir}s") do
      to context.send(:"#{dir}_path")
      only_if { File.exists?(context.send(:"#{dir}_path")) }
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

# Client Config
template File.join(temp_chef_repo, "#{context.chef_client_mode}.rb") do
  source "config.rb.erb"
  helpers(KnifeContainer::Generator::TemplateHelper)
end 

# First Boot JSON
file File.join(temp_chef_repo, "first-boot.json") do
  content context.first_boot.to_json
end

# Dockerfile
template "#{dockerfile_dir}/Dockerfile" do
  source "dockerfile.erb"
  helpers(KnifeContainer::Generator::TemplateHelper)
end
