require "spec_helper"

module VirtualFileSystem
  describe Store do
    let(:name)  {:dummy}
    let(:store) {Store.new(name)}

    before {DummyVFSModule.reset!}

    describe ".new(name)" do
      context "when name is invalid" do
        let(:store) {Store.new(:nonexist)}

        it {expect{store}.to raise_error(InvalidStore)}
      end

      context "when name is valid" do
        subject {store}

        it {expect{store}.to change{DummyVFSModule.extended?}.from(nil).to(true)}
        its(:name) {should be :dummy}
      end
    end
  end
end
