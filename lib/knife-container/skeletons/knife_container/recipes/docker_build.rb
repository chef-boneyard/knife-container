context = KnifeContainer::Generator.context
dockerfile_dir = File.join(context.dockerfiles_path, context.dockerfile_name)
temp_chef_repo = File.join(dockerfile_dir, "chef")
berksfile = File.join(dockerfile_dir, "Berksfile") || context.berksfile

ruby_block "berkshelf" do
  block do
    require 'berkshelf'
    require 'berkshelf/berksfile'
    berks = Berkshelf::Berksfile.from_file(berksfile)
    berks.install

    if File.exists?(File.join(temp_chef_repo, "zero.rb"))
      if File.exists?(File.join(temp_chef_repo, "cookbooks")) && context.force_build
        FileUtils.rm_rf(File.join(temp_chef_repo, "cookbooks"))
      end
      berks.vendor(File.join(temp_chef_repo, "cookbooks"))
    elsif File.exists?(File.join(temp_chef_repo, "client.rb"))
      if context.force_build
        berks.upload(force: true, freeze: true)
      else
        berks.upload
      end
    end
  end
  only_if { File.exists?(berksfile) && context.run_berks}
end

# Build Docker image
ruby_block "build docker image" do
  block do
    `docker build -t #{context.dockerfile_name} #{dockerfile_dir}`
  end
end
