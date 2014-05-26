require "spec_helper"

module VirtualFileSystem
  describe Config do
    let(:config) do
      Config.new do
        bucket :bucket1, :store => :dummy
        bucket :bucket2, :store => :dummy
      end
    end

    it {expect{config}.to change{Bucket.all.size}.from(0).to(2)}
  end

  describe ".config(&block)" do
    subject {VirtualFileSystem.config {}}
    
    it {should be_a Config}
  end
end
