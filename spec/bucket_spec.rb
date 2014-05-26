require "spec_helper"

module VirtualFileSystem
  describe Bucket do
    let(:bucket1) {Bucket.new(:bucket1, :store => :dummy)}
    let(:bucket2) {Bucket.new(:bucket2, :store => :dummy)}

    subject {bucket1}

    describe ".all" do
      subject {Bucket.all}
      before {bucket1;bucket2}

      its(:size)   {should eq 2}
      its(:keys)   {should include(:bucket1, :bucket2)}
      its(:values) {should include(bucket1, bucket2)}
    end

    its(:name)  {should eq :bucket1}
    its(:store) {should be_a Store}
  end
end
