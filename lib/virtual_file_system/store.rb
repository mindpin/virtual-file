module VirtualFileSystem
  class Store
    attr_reader :name, :module_name

    # @param name [Symbol] a valid store backend name,
    #     which then get evaluated according to module name
    def initialize(name)
      @name        = name.to_sym
      @module_name = "#{self.name.capitalize}VFSModule"

      extend self.backend
    end

    # @return [Module] evaluated from provided store
    #     backend name
    def backend
      @backend = self.module_name.constantize
    rescue NameError => ex
      msg = "Invalid store name - #{self.module_name}."
      InvalidStore.raise!(msg)
    end
  end
end
