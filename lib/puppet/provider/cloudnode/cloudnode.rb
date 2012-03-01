require 'puppet/cloudpack'
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

    def bootstrap server
        Puppet.debug "Server #{server.id} will now bootstrap via SSH with these commands: #{@resource[:commands].inspect}"
        ssh = Fog::SSH.new(server.dns_name, @resource[:username])
        wait = 5
        max_tries = 100
        try_number = 1
        begin
            result = ssh.run(@resource[:commands])
            if Puppet[:debug] and @resource[:logoutput] == :true
                print_result result
            end
            return result
        rescue Errno::ECONNREFUSED
            if try_number >= max_tries
                Puppet.debug "Server #{server.id}: tried SSH #{try_number} times: connection was refused."
                return false
            else
                Puppet.debug "Server #{server.id}: connection refused, retrying..."
                try_number += 1
            end
            sleep wait
            retry
        rescue Errno::ETIMEDOUT
            if try_number >= max_tries
                Puppet.debug "Server #{server.id}: tried SSH #{try_number} times: connection timed out."
                return false
            else
                Puppet.debug "Server #{server.id}: connection timed out, retrying..."
                try_number += 1
            end
            sleep wait
            retry
        end
    end

    def create
        options = {
            :region => @resource[:region],
            :image => @resource[:image],
            :type => @resource[:type],
            :group => [@resource[:group]],
            :keyname => @resource[:keypair],
            :monitoring => @resource[:monitoring],
            :tags => create_tags(@resource[:tags]),
            :username => @resource[:username]
        }
        self.debug "#create parameters: #{options.inspect}"
        server = Puppet::CloudPack.create(options, true)
        if @resource[:commands].is_a?(Array)
            bootstrap server
        end
    end

    def create_tags resource_tags
        tags = {PUPPET_ID => @resource[:name]}
        tags["Name"] = @resource[:name] # Convenience for AWS Web Console.
        tags.merge(resource_tags) # Overwrites Name tag from resource_tags if defined.
    end

    def destroy
        self.debug "#destroy: #{properties.inspect}"
        Puppet::CloudPack.terminate(properties[:dns_name], {:region => @resource[:region]})
    end

    def exists?
        properties[:ensure] != :absent
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
                :ensure => :present)
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
