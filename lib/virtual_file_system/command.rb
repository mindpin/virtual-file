module VirtualFileSystem
  class Command
    attr_reader :creator, :bucket

    def initialize(bucket, creator)
      @bucket  = bucket
      @creator = creator
    end

    # make target directory according to path
    # @param path [String] path name
    # @return [VirtualFileSystem::File] File model for target directory
    def mkdir(path)
      Utils.traverse(path) do |dir, name|
        params = make_params :is_dir => true,
                             :dir_id => dir.try(:id),
                             :name   => name

        scope.find_or_create_by(params)
      end
    end

    # create file according to path
    # @param path [String] path name
    # @param mode [Symbol] conflict solution modes: `:force` or `:rename`
    # @return [VirtualFileSystem::File] File model for target file
    def put(path, store_id, mode: :default, &block)
      dir = Utils.dir(path).empty? ? nil : self.mkdir(Utils.dir path)

      params = make_params :dir_id   => dir.try(:id),
                           :is_dir   => false,
                           :name     => Utils.tokenize(path).last,
                           :store_id => store_id

      dest = scope.where(params).first

      resolve_conflict(params, dest, mode) do |params, rename|
        file = File.new params
        block.call(file) if block_given?
        file
      end
    end

    # checke whether the target exists
    # @param path [String] path name
    # @return [Boolean]
    def exists?(path)
      !!scope.get(path)
    end

    # list the target directory
    # @param path [String] path name
    # @return [Array<String>] Array of absolute path
    #     of contained files
    def ls(path)
      dir = scope.get(path)
      InvalidPath.raise! {!dir.try(:is_dir)}
      dir.files.map(&:path)
    end

    # remove the target path
    # @param path [String] path name
    def rm(path)
      file = scope.get(path)
      return if !file
      file.remove!
    end

    # move file from `from` path to `to` path
    # @param from [String] path to the file to be moved
    # @param to [String] path to the destination
    # @param mode [Symbol] conflict solution modes: `:force` or `:rename`
    # @return [VirtualFileSystem::File] the moved file
    def mv(from, to, mode: :default, &block)
      target_file = scope.get(from)
      InvalidStore.raise! {!target_file}

      dest_dirname = Utils.dir to
      dest_file    = scope.get(to)
      dest_dir     = scope.get(dest_dirname) || self.mkdir(dest_dirname)

      params = make_params :name   => Utils.tokenize(to).last,
                           :dir_id => dest_dir.try(:id)

      resolve_conflict(params, dest_file, mode) do |params, rename|
        target_file.update_attributes params;
        block.call(target_file) if block_given?
        target_file
      end
    end

    # copy file from `from` path to `to` path
    # @param from [String] path to the file to be copied
    # @param to [String] path to the destination
    # @param mode [Symbol] conflict solution modes: `:force` or `:rename`
    # @return [VirtualFileSystem::File] copy of the target file
    def cp(from, to, mode: :default, &block)
      target_file = scope.get(from)
      InvalidStore.raise! {!target_file}

      dest_dirname = Utils.dir to
      dest_file    = scope.get(to)
      dest_dir     = scope.get(dest_dirname) || self.mkdir(dest_dirname)

      params = make_params :name   => Utils.tokenize(to).last,
                           :dir_id => dest_dir.try(:id)

      resolve_conflict(params, dest_file, mode) do |params, rename|
        copy = File.new target_file.raw_attributes
        copy.update_attributes params
        block.call(copy) if block_given?
        copy
      end
    end

    # check whether the path points to a dir
    # @param [String] path name
    # @return [Boolean]
    def is_dir?(path)
      file = scope.get(path)
      InvalidPath.raise! {!file}
      file.is_dir
    end

    # check whether the path points to a file
    # @param [String] path name
    # @return [Boolean]
    def is_file?(path)
      !self.is_dir?(path)
    end

    # get size of the target file
    # @param path [String] path name
    # @return [Integer] file size in bytes
    def get_size(path)
      file = scope.get(path)
      InvalidPath.raise! {!file}
      return 0 if file.is_dir
      file.info[:size]
    end

    # get count of all contained files in target dir
    # @param path [String] path name
    # @return [Integer] count of contained files
    def get_count(path)
      file = scope.get(path)
      InvalidPath.raise! {!file}
      return 0 if !file.is_dir
      file.files_count
    end

    # get last modified time of target file
    # @param path [String]
    # @return [DateTime] last modified time
    def get_last_modified(path)
      file = scope(:with_removed => true).get(path)
      InvalidPath.raise! do
        !file || !File.removed
      end
      file.last_modified
    end

    # get all files with `last_modified` later than cursor
    # @param cursor [DateTime] `last_modified` cursor
    # @param limit [Integer] limit length of returned entries
    # @return [Hash] delta info hash
    def delta(cursor, limit=100)
      criteria = scope(:with_removed => true)

      files = criteria.where(:last_modified.gt => cursor)
                      .order_by(:last_modified => :asc)
                      .limit(limit)
                      .map(&:delta_attributes)

      new_cursor = files.last[:last_modified]

      {
        :new_cursor => new_cursor,
        :has_more   => criteria.where(:last_modified.gt => new_cursor).any?,
        :entries    => files
      }
    end

    # get uri info hash of the target file
    # @param path [String] path to target file
    # return [Hash] uri info hash
    def get_uri(path)
      file = scope.get(path)
      InvalidPath.raise! {!file}
      file.uri
    end
    
    # get file info hash of the target file
    # @param path [String] path to target file
    # return [Hash] file info hash
    def file_info(path)
      file = scope.get(path)
      InvalidPath.raise! {!file}
      file.info
    end

    private

    def scope(with_removed: false)
      criteria = with_removed ? File.unscoped : File
      criteria.where(:bucket => bucket, :creator_id => creator.id)
    end

    def resolve_conflict(params, conflict_file, mode, &target_block)
      target = target_block.call(params)

      if !conflict_file
        target.save
        return target
      end

      case mode
      when :default
        FileNameConflict.raise!
      when :force
        conflict_file.remove!
      when :rename
        target.rename!
      end

      target.save
      target
    end

    def make_params(name: nil, is_dir: nil, dir_id: nil, store_id: nil)
      {
        :is_dir     => is_dir,
        :dir_id     => dir_id,
        :name       => name,
        :store_id   => store_id,
        :creator_id => creator.id,
        :bucket     => bucket,
      }.reject {|k, v| v.nil? && k != :dir_id}
    end
  end

  def self.Command(bucket, creator)
    Command.new(bucket, creator)
  end
end
