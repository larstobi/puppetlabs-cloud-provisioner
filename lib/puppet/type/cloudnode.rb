Puppet::Type.newtype(:cloudnode) do
    @doc = "Manage cloud nodes."

    ensurable do
        desc "What state the node should be in."

        newvalue(:present) do
            provider.create
        end

        newvalue(:absent) do
            provider.destroy
        end

        newvalue(:running) do
            provider.start
        end

        newvalue(:stopped) do
            provider.stop
        end

        # Possible EC2 states:
        # http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/ApiReference-ItemType-InstanceStateType.html?r=9564
        # states = %w( pending running shutting-down terminated stopping stopped )
        def insync?(is)
            # an empty array is analogous to no should values
            return true if @should.empty?

            # only support a single should
            should = @should.first
            # use Symbol to match should
            is = "shuttingdown" if is == "shutting-down"
            is = is.to_sym
            stop_state = [:stopped, :stopping, :shuttingdown]

            case should
            when :present
                return is != :terminated
            when :running
                return stop_state.include?(is) ? false : true
            when :stopped
                return stop_state.include?(is) ? true : false
            end
            false
        end

        def retrieve
            current = provider.properties[:ensure]
        end
    end

    newparam(:name) do
        desc "The node name. Stored in a tag on Amazon EC2."
        isnamevar

        validate do |value|
            if value.nil?
                raise ArgumentError, "%s must not be nil" % value
            end
        end
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

    newparam(:monitoring, :boolean => true) do
        desc "Use monitoring for the instance."
        newvalues(:true, :false)
        defaultto :false
    end

    newparam(:username) do
        desc "The username to use when logging in via SSH."
    end

    newparam(:commands) do
        desc "Bootstrapping commands to run via SSH."

        munge do |value|
            if value.is_a?(String)
                Array(value)
            else
                value
            end
        end
    end

    newparam(:logoutput, :boolean => true) do
        desc "Whether to log output from bootstrap."
        newvalues(:true, :false)
        defaultto :false
    end

    newparam(:tags) do
        desc "Tag the instance."
        defaultto Hash.new
    end
end
