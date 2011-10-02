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
        options = {:region => @resource[:region]}
        dns_name = dns_name_by_name_tag
        self.debug "#destroy: #{dns_name}"
        # SERVER: "ec2-11-222-33-44.eu-west-1.compute.amazonaws.com"
        # OPTIONS: {:region=>"eu-west-1"}
        Puppet::CloudPack.terminate(dns_name, options)
    end

    def exists?
        options = {:region => @resource[:region]}
        list = Puppet::CloudPack.list(options)
        match = false
        # TODO: This is too deeply nested to be pretty.
        list.each do |id, status|
            status.each do |key,value|
                if key == "tags"
                    value.each do |key,value|
                        if key == "Name" and status["state"] != "terminated"
                            match = true if @resource[:name] == value
                        end
                    end
                end
            end
        end
        match
    end

    def dns_name_by_name_tag
        options = {:region => @resource[:region]}
        list = Puppet::CloudPack.list(options)

        list.each do |id, status|
            status.each do |status_key,status_value|
                if status_key == "tags"
                    status_value.each do |tag_key,tag_value|
                        if tag_key == "Name"
                            # EC2 states: pending, running, shutting-down, stopping, stopped, terminated
                            if @resource[:name] == tag_value and
                                status["state"] != "terminated"
                                return status["dns_name"]
                            end
                        end
                    end
                end

            end
        end
        nil
    end
end
