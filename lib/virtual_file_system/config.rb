module VirtualFileSystem
  class Config
    def initialize(&block)
      instance_eval &block
    end

    def bucket(*args)
      Bucket.new(*args)
    end
  end

  def self.config(&block)
    @config ||= Config.new &block
  end
end
