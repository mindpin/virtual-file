require "rspec"
require "virtual_file_system"
require "timecop"
require "pry"
ENV["MONGOID_ENV"] = "test"
Mongoid.load!("./spec/mongoid.yml")

module DummyVFSModule
  def self.extended(base)
    @extended = true
  end

  def self.extended?
    @extended
  end

  def self.reset!
    @extended = nil
  end

  def get_uri(store_id)
    return if !store_id

    {
      :type  => :disk,
      :value => "/physical/path/to/file"
    }
  end

  def file_info(store_id)
    return if !store_id

    {
      :size           => 1234,
      :mime_type      => "image/png",
      :mime_type_info => {}
    }
  end
end

module DummyCreator
  def self.id
    "4321"
  end
end

module VirtualFileSystem
  class File
    field :ext_field, :type => String
  end
end

RSpec.configure do |config|
  config.after(:each) do
    Mongoid.purge!
    VirtualFileSystem::Bucket.instance_eval {@all = {}}
  end
end
