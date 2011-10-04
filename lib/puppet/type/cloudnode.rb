Puppet::Type.newtype(:cloudnode) do
    @doc = "Manage cloud nodes."
    ensurable

    newparam(:name) do
        desc "The node name. Stored in a tag on Amazon EC2."
        isnamevar
    end

    newparam(:platform) do
        desc "Cloud provider. For example AWS."
    end

    newparam(:type) do
        desc "The instance type. For example m1.small on Amazon EC2."
    end

    newparam(:region) do
        desc "The region for the instance. For example us-east-1 or eu-west-1"
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
