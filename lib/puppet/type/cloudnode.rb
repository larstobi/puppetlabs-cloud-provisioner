Puppet::Type.newtype(:cloudnode) do
    @doc = "Manage cloud nodes."
    ensurable

    newparam(:name) do
        desc "The node name. Corresponds to i.e. the Name tag on Amazon EC2."
        isnamevar
    end

    newparam(:platform) do
        desc "Cloud provider."
    end

    newparam(:type) do
        desc "The instance type. Corresponds to i.e.e m1.small on Amazon EC2."
    end

    newparam(:region) do
        desc "The region to look for the node."
    end

    newparam(:image) do
        desc "The AMI to create the node with."
    end

    newparam(:group) do
        desc "The security group to use."
    end

    newparam(:keypair) do
        desc "The name of the key pair."
    end

    newparam(:monitoring) do
        desc "Use monitoring for the instance."

        validate do |value|
            unless value == "true" or value == "false"
                raise ArgumentError, "%s must be true or false" % value
            end
        end
    end

    newparam(:tags) do
        desc "Tag the instance."
        defaultto Hash.new
    end
end
