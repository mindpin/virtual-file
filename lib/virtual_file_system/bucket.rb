module VirtualFileSystem
  class Bucket
    attr_reader :name, :store

    delegate :get_url, :file_info, :to => :store

    # @param name [Symbol] bucket name
    # @param store [Symbol] store name for this buck
    def initialize(name, store: :nonexist)
      @name  = name.to_sym
      @store = Store.new(store)

      self.class.all[self.name] = self
    end

    # List all initialized buckets
    # @return [Hash] bucket name as keys
    def self.all
      @all ||= {}
    end
  end
end
