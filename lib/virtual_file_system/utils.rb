module VirtualFileSystem
  module Utils
    class << self
      def tokenize(path)
        path.split("/").keep_if(&:present?)
      end

      def dir(path)
        join tokenize(path)[0..-2]
      end

      def join(tokens)
        tokens.unshift("").join("/")
      end

      def traverse(path, &block)
        self.tokenize(path).reduce(nil, &block)
      end

      def rename(name)
        base   = ::File.basename(name, ".*")
        ext    = ::File.extname(name)
        regexp = /(\((?<num>\d+)\))?$/
        match  = base.match(regexp)
        num    = match[:num].to_i

        %Q|#{base.gsub(regexp, "")}(#{num + 1})#{ext}|
      end
    end
  end
end
