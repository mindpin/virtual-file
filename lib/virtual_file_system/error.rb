module VirtualFileSystem
  class Error < Exception
    def self.raise!(msg = nil, &cond)
      raise self.new(msg) if !cond || cond.call
    end
  end

  InvalidStore     = Class.new Error
  FileNameConflict = Class.new Error
  InvalidPath      = Class.new Error
end
