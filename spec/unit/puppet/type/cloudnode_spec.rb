require 'spec_helper'

describe Puppet::Type.newtype(:cloudnode) do
    before do
        @class = Puppet::Type.type(:cloudnode)

        # Init a fake provider
        @provider_class = stub 'provider_class', :ancestors => [], :name => 'fake',
        :suitable? => true, :supports_parameter? => true
        @class.stubs(:defaultprovider).returns @provider_class
        @class.stubs(:provider).returns @provider_class

        @provider = stub 'provider', :class => @provider_class, :clean => nil
        @provider.stubs(:is_a?).returns false
        @provider_class.stubs(:new).returns @provider

        @cloudnode = @class.new(:name => "foo")
    end

    it "should have :name be its namevar" do
        @class.key_attributes.should == [:name]
    end
end
