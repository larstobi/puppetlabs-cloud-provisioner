require 'facter/util/ec2'
def ec2_tags
    ec2_userdata = Facter.value('ec2_userdata')
    begin
        value = ec2_userdata.split(',').collect do |tag|
            Hash[*tag.split(':')]
        end
    rescue Exception
        Facter.warn "Could not parse ec2_userdata tags to hash."
    end
    Facter.add("ec2_tags") { setcode { value } }
end


begin
    if (Facter::Util::EC2.has_euca_mac? || Facter::Util::EC2.has_openstack_mac? ||
        Facter::Util::EC2.has_ec2_arp?) && Facter::Util::EC2.can_connect?
        ec2_tags
    else
        Facter.debug "Not an EC2 host"
    end
rescue NoMethodError
end
