require 'puppet/cloudpack'
Puppet::Type.type(:cloudnode).provide(:cloudnode) do
    desc "Puppet CloudPack provider."

    def create
        resource_tags = @resource[:tags]
        name_tag = {"Name" => @resource[:name]}
        tags = resource_tags.merge(name_tag)
        options = {
            :region => @resource[:region],
            :image => @resource[:image],
            :group => [@resource[:group]],
            :keypair => @resource[:keypair],
            :monitoring => @resource[:monitoring],
            :tags => tags
        }
        self.debug "#create parameters: #{options.inspect}"
        Puppet::CloudPack.create(options)
    end

    def destroy
        list = find_all_by_name(Puppet::CloudPack.list({:region => @resource[:region]}))
        case list.length
        when nil
            false
        when 1
            dns_name = list.first["dns_name"]
            self.debug "#destroy: #{dns_name}"
            # SERVER: "ec2-11-222-33-44.eu-west-1.compute.amazonaws.com"
            # OPTIONS: {:region=>"eu-west-1"}
            Puppet::CloudPack.terminate(dns_name, {})
        else
            raise Puppet::Error, "Ambiguous argument. Duplicate Name tags found: #{list.inspect}"
        end
    end

    def exists?
        list = find_all_by_name(Puppet::CloudPack.list({:region => @resource[:region]}))
        case list.length
        when nil
            false
        when 1
            true
        else
            self.warning("Duplicate Name tags found!")
            true
        end
    end

    def find_all_by_name list
        list.find_all do |id, status|
            # EC2 states: pending, running, shutting-down, stopping, stopped, terminated
            status["state"] != "terminated" and status["tags"]["Name"] == @resource[:name]
        end
    end
end
