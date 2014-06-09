require 'docker' # it gets this from chef-init

Ohai.plugin(:DockerContainer) do
  provides "docker_container"

  def container_id
    shell_out("hostname").stdout.strip
  end

  def looks_like_docker?
    hint?('docker_container') || !!Docker.version && !!Docker::Container.get(container_id)
  end

  ##
  # The format of the data is collection is the inspect API
  # http://docs.docker.io/reference/api/docker_remote_api_v1.11/#inspect-a-container
  #
  collect_data do
    metadata_from_hints = hint?('docker_container')

    if looks_like_docker?
      Ohai::Log.debug("looks_like_docker? == true")
      docker_container Mash.new

      if metadata_from_hints
        Ohai::Log.debug("docker_container hints present")
        metadata_from_hints.each { |k,v| docker_container[k] = v }
      end

      container = Docker::Container.get(container_id).json
      container.each { |k,v| docker_container[k] = v }
    else
      Ohai::Log.debug("looks_like_docker? == false")
      false
    end
  end
end
