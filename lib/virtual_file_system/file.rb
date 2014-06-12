module VirtualFileSystem
  class File
    include Mongoid::Document
    include Mongoid::Timestamps

    field :store_id,      :type => String
    field :name,          :type => String
    field :is_dir,        :type => Boolean,  :default => false
    field :creator_id,    :type => Integer
    field :last_modified, :type => DateTime, :default => proc {Time.now}
    field :is_removed,    :type => Boolean,  :default => false
    field :files_count,   :type => Integer,  :default => 0
    field :bucket,        :type => Symbol

    scope :removed, proc {
      unscoped.where(:is_removed => true).order_by(:last_modified => :desc)
    }

    default_scope proc {
      where(:is_removed => false).order_by(:name => :asc)
    }

    belongs_to :dir,
               :class_name  => self.to_s

    has_many   :files,
               :class_name  => self.to_s,
               :foreign_key => :dir_id,
               :dependent   => :destroy

    validates :creator_id,
              :presence     => true

    validates :store_id,
              :presence     => {:if => proc {!self.is_dir}}

    validates :files_count,
              :numericality => {:greater_than_or_equal_to => 0}

    validates :name,
              :presence     => true,
              :format       => {:without => /[\\|\?|\:|\*|\"|\>|\<|\|]+/}

    validates :bucket,
              :presence     => true,
              :inclusion    => {:in => proc {Bucket.all.keys}}

    validate :name_conflict

    after_save  :recursive_remove!
    before_save :set_dir_files_count!
    before_save :set_last_modified!

    def toplevel?
      !(self.dir_id || self.is_removed)
    end

    def remove!
      self.is_removed = true
      self.save
    end

    def rename!
      self.name = Utils.rename(self.name)
      return self if self.save
      self.rename!
    end

    def path
      Utils.join path_tokens
    end

    def raw_attributes
      self.attributes.keep_if do |key, _|
        !%W|_id updated_at created_at|.include?(key)
      end
    end

    def delta_attributes
      {
        :path          => self.path,
        :size          => self.is_dir ? 0 : self.info[:size],
        :is_dir        => self.is_dir,
        :last_modified => self.last_modified.to_time
      }
    end

    def info
      return nil if self.is_dir
      get_bucket.file_info(self.store_id)
    end

    def uri
      return nil if self.is_dir
      get_bucket.get_uri(self.store_id)
    end

    def self.get(path, include_remove: false)
      Utils.traverse(path) do |dir, name|
        next_dir = self.where(:dir_id => dir && dir.id, :name => name).first
        break if !next_dir
        next_dir
      end
    end

    def self.files_count
      self.where(:dir_id => nil).pluck(:files_count).join(:+)
    end

    protected

    def path_tokens(tokens = [])
      current = [self.name] + tokens 
      return current if !self.dir
      self.dir.path_tokens current
    end

    def set_dir_files_count!
      dir = self.dir
      return if !dir || self.invalid?
      case
      when self.is_removed
        dir.files_count -= (1 + self.files_count)
      when self.new_record?
        dir.files_count += 1
      when self.changed.include?("files_count")
        change = self.changes["files_count"]
        dir.files_count += change[1] - change[0].to_i
      when self.changed.include?("dir_id")
        change = self.changes["dir_id"]
        if change[0]
          old_dir = self.class.find(change[0])
          old_dir.files_count -= (self.files_count + 1)
          old_dir.save
        end
        dir.files_count += (self.files_count + 1)
      end

      dir.save
    end

    private

    def get_bucket
      Bucket.all[self.bucket]
    end

    def name_conflict
      dup = File.where(:dir_id => self.dir_id, :name => self.name).first
      cond = dup && dup.id != self.id
      errors.add(:name, "name conflict") if cond
    end

    def recursive_remove!
      self.files.each(&:remove!) if self.is_dir && self.is_removed
    end

    def set_last_modified!
      if self.is_removed || !self.changed.include?("dir_id")
        self.last_modified = Time.now
      end
    end
  end
end
