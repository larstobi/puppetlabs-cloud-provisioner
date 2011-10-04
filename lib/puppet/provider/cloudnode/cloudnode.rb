require 'puppet/cloudpack'
Puppet::Type.type(:cloudnode).provide(:cloudnode) do
    desc "Puppet CloudPack provider."
    mk_resource_methods

    def create
        resource_tags = @resource[:tags]
        name_tag = {"Name" => @resource[:name]}
        tags = resource_tags.merge(name_tag)
        options = {
            :region => @resource[:region],
            :image => @resource[:image],
            :type => @resource[:type],
            :group => [@resource[:group]],
            :keyname => @resource[:keypair],
            :monitoring => @resource[:monitoring],
            :tags => tags
        }
        self.debug "#create parameters: #{options.inspect}"
        Puppet::CloudPack.create(options)
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
                next if instance["tags"]["Name"].nil?
                next if instance["state"] == "terminated"

                new(:name => instance["tags"]["Name"],
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
