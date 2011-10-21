require 'spec_helper'
require 'puppet/cloudpack'

describe Puppet::Type.type(:cloudnode) do
    before do
        @node = Puppet::Type.type(:cloudnode).new(:name => "testnode")
    end

    it "should set the node name" do
        @node.name.should == "testnode"
    end

    it "should have :name be its namevar" do
        @node.name_var.should == :name
    end
end
