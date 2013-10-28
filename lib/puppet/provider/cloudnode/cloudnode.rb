require 'puppet/cloudpack'
require 'timeout'

Puppet::Type.type(:cloudnode).provide(:cloudnode) do
  desc "Puppet CloudPack provider."
  mk_resource_methods
  PUPPET_ID = "Puppet-ID"

  def print_result result
    result.each do |line|
      if line.is_a?(Fog::SSH::Result)
        puts line.command
        puts line.stdout
        puts line.stderr
      else
        puts line.inspect
      end
    end
  end

  def try_again(server, try_number, max_tries, wait)
      if try_number >= max_tries
        Puppet.debug "Server #{server}: tried SSH #{try_number} times: connection failed."
        return false
      else
        Puppet.debug "Server #{server}: connection failed, retrying..."
        try_number += 1
      end
      sleep wait
      true
  end

  def ssh(server, username, commands)
    Puppet.debug "Server #{server} will now login via SSH to #{username}@#{server}"
    ssh = Fog::SSH.new(server, username, {:forward_agent => true})
    wait = 5
    max_tries = 100
    try_number = 1
    begin
      result = ssh.run(commands)
      if Puppet[:debug] and @resource[:logoutput] == :true
        print_result result
      end
      return result
    rescue Errno::ECONNREFUSED
      retry if try_again(server, try_number, max_tries, wait)
    rescue Errno::ETIMEDOUT
      retry if try_again(server, try_number, max_tries, wait)
    rescue Timeout::Error
      retry if try_again(server, try_number, max_tries, wait)
    end
  end

  def enableroot server
    commands = ['/usr/bin/sudo /bin/sed -i "s/^.*\ ssh-rsa\ AAAA/\ ssh-rsa\ AAAA/" /root/.ssh/authorized_keys']
    Puppet.debug "Server #{server.id} will now enable root on #{server.dns_name}"

    result = ssh(server.dns_name, @resource[:username], commands)
    if Puppet[:debug] and @resource[:logoutput] == :true
      print_result result
    else
      puts "enableroot: will not print result"
    end
    return result
  end

  def bootstrap server
    if @resource[:enableroot]
      username = 'root'
    else
      username = @resource[:username]
    end
    Puppet.debug "Server #{server.id} bootstrapping with these commands: #{@resource[:commands].inspect}"
    ssh(server.dns_name, username, @resource[:commands])
  end

  def create
    options = {
      :region     => @resource[:region],
      :image      => @resource[:image],
      :type       => @resource[:type],
      :group      => [@resource[:group]],
      :keyname    => @resource[:keypair],
      :monitoring => @resource[:monitoring],
      :tags       => tags,
      :userdata   => tags_to_s(tags), # Access from instance via $ec2_userdata
      :username   => @resource[:username]
    }
    self.debug "#create parameters: #{options.inspect}"
    server = Puppet::CloudPack.create(options, true)
    if @resource[:commands].is_a?(Array)
      if @resource[:enableroot]
        enableroot server
      end
      bootstrap server
    end
  end

  # Make tags available to the instance via http://169.254.169.254/1.0/user-data
  def tags_to_s tags
    tags.collect do |key,value|
      "#{key}:#{value}"
    end.join(',')
  end

  def s_to_hash string
    return string if string.class == Hash
    hash = Hash.new
    begin
      string.split(',').each do |tag|
        hash.merge!(Hash[*tag.split(':')])
      end
    rescue Exception => e
      Puppet.warning "Could not parse string of tags to hash: #{string}, #{e}"
    end
    hash
  end

  def tags
    tags = {PUPPET_ID => @resource[:name]}
    tags["Name"] = @resource[:name] # Convenience for AWS Web Console.
    resource_tags = s_to_hash(@resource[:tags])
    tags.merge!(resource_tags) # Overwrites Name tag from resource_tags if defined.
  end

  def destroy
    self.debug "#destroy: #{properties.inspect}"
    Puppet::CloudPack.terminate(properties[:dns_name], {:region => @resource[:region]})
  end

  def start
    self.debug "#start: #{properties[:name]} (#{properties[:id]})"
    Puppet::CloudPack.start(properties[:id], {:platform => 'AWS', :region => @resource[:region]})
    true
  end

  def stop
    self.debug "#stop: #{properties[:name]} (#{properties[:id]})"
    Puppet::CloudPack.stop(properties[:id], {:platform => 'AWS', :region => @resource[:region]})
    true
  end

  def self.instances
    @regions.collect do |region|
    Puppet::CloudPack.list_detailed({:region => region}).collect do |id, instance|
      next if instance["state"] == "terminated"
      next if instance["tags"][PUPPET_ID].nil?
      new(:name => instance["tags"][PUPPET_ID],
          :id => instance["id"],
          :dns_name => instance["dns_name"],
          :availability_zone => instance["availability_zone"],
          :region => region,
          :ensure => instance['state'])
      end
    end.flatten
  end

  def self.prefetch(resources)
    @regions = resources.collect do |name, resource|
      resource[:region]
    end.uniq

    duplicates = {}
    instances.each do |instance|
      next if instance.nil?

      if duplicates[instance.name]
        raise Puppet::Error, "Duplicate name tags for #{instance.name}"
      else
        duplicates[instance.name] = true
      end

      if resource = resources[instance.name]
        resource.provider = instance
      end
    end
  end

  def properties
    if @property_hash.empty?
      @property_hash = {:ensure => :absent}
    end
    @property_hash
  end
end
