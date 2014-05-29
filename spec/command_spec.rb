require "spec_helper"

module VirtualFileSystem
  describe Command do
    let(:creator)  {DummyCreator}
    let(:bucket)   {:bucket}
    let(:cmd)      {Command.new(bucket, creator)}
    let(:path)     {"/a/b/c"}
    let(:store_id) {SecureRandom.hex}

    before {Bucket.new(:bucket, :store => :dummy)}

    describe "#mkdir(path)" do
      let(:mkdir)  {cmd.mkdir(path)}
      let(:mkdir1) {cmd.mkdir(path)}

      it {expect{mkdir}.to change{File.count}.from(0).to(3)}

      it "creates dirs according to path" do
        mkdir

        File.where(:is_dir => true).count.should be 3

        a, b, c = %W|a b c|.map do |name|
          File.find_by(:name => name)
        end

        c.dir_id.should eq b.id
        b.dir_id.should eq a.id
        a.toplevel?.should be true
      end

      it "returns target dir when dir exists" do
        mkdir.should eq mkdir1
      end
    end

    describe "#put(path, store_id, mode: :default)" do
      let(:path)  {"/a/b/c.png"}
      let(:put1)  {cmd.put(path, store_id)}
      let(:put1a) {cmd.put(path, store_id)}
      let(:put2)  {cmd.put(path, store_id, :mode => :force)}
      let(:put2a) {cmd.put(path, store_id, :mode => :force)}
      let(:put3)  {cmd.put(path, store_id, :mode => :rename)}
      let(:put3a) {cmd.put(path, store_id, :mode => :rename)}
      let(:put3b) {cmd.put(path, store_id, :mode => :rename)}

      context "when file does not exist" do
        subject {put1}

        its(:name)      {should eq "c.png"}
        its(:is_dir)    {should be false}
        its("dir.name") {should eq "b"}

        context "when dir exists" do
          before {cmd.mkdir(Utils.dir path)}

          it {expect{put1}.to change{File.count}.by(1)}
          it {expect{put1}.to change{File.get("/a").files_count}.by(1)}
          it {expect{put1}.to change{File.get("/a/b").files_count}.by(1)}
        end

        context "when dir does not exists" do
          it {expect{put1}.to change{File.count}.by(3)}
        end
      end

      context "when file exist" do
        context "when default mode" do
          before {put1}

          it {expect{put1a}.to raise_error(FileNameConflict)}
        end

        context "when force mode" do
          let(:path) {"/a/b/c.png"}
          before {put2}

          it {expect{put2a}.to change{File.where(:id => put2.id).first}.to(nil)}
          it {expect{put2a}.not_to change{File.count}}
          it {expect{put2a}.not_to change{File.get("/a").files_count}}
          it {expect{put2a}.not_to change{File.get("/a/b").files_count}}
          it {expect{put2a}.to change{File.removed.count}.by(1)}
        end

        context "when rename mode" do
          before  {put3}
          subject {put3a}

          its(:name) {should eq "c(1).png"}
          it {expect{put3a}.to change{File.count}.by(1)}
          it {expect{put3a}.to change{File.get("/a").files_count}.by(1)}
          it {expect{put3a}.to change{File.get("/a/b").files_count}.by(1)}

          context "when renamed file exists" do
            before  {put3a}
            subject {put3b}

            its(:name) {should eq "c(2).png"}
            it {expect{put3b}.to change{File.count}.by(1)}
            it {expect{put3b}.to change{File.get("/a").files_count}.by(1)}
            it {expect{put3b}.to change{File.get("/a/b").files_count}.by(1)}
          end
        end
      end
    end

    describe "#exists?(path)" do
      let(:exists) {cmd.exists?(path)}
      subject {exists}

      context "when path does not exist" do
        it {should be false}
      end

      context "when path exists" do
        before {cmd.mkdir(path)}

        it {should be true}
      end
    end

    describe "#ls(path)" do
      let(:ls) {cmd.ls(path)}
      subject {ls}

      context "when path deos not exist" do
        it {expect{ls}.to raise_error{InvalidPath}}
      end

      context "when path points to a file" do
        before {cmd.put(path, store_id)}

        it {expect{ls}.to raise_error{InvalidPath}}
      end

      context "when path exists and points to a directory" do
        before do
          cmd.mkdir(path)
          cmd.put(path + "/file1", store_id)
          cmd.put(path + "/file2", store_id)
          cmd.put(path + "/file3", store_id)
        end

        it {should include(path + "/file1", path + "/file2", path + "/file3")}
      end
    end

    describe "rm(path)" do
      let(:rm) {cmd.rm(path)}
      subject {rm}

      context "when path does not exist" do
        it {expect{rm}.not_to change{File.removed.count}}
      end

      context "when path exists" do
        before do
          cmd.mkdir(path)
          cmd.put(path + "/file1", store_id)
          cmd.put(path + "/file2", store_id)
          cmd.put(path + "/file3", store_id)
        end
        
        it {expect{rm}.to change{File.removed.count}.by(4)}
        it {expect{rm}.to change{File.get(path)}.to(nil)}
        it {expect{rm}.to change{File.get(path + "/file1")}.to(nil)}
        it {expect{rm}.to change{File.get(path + "/file2")}.to(nil)}
        it {expect{rm}.to change{File.get(path + "/file3")}.to(nil)}
        it {expect{rm}.to change{File.get("/a").files_count}.by(-4)}
        it {expect{rm}.to change{File.get("/a/b").files_count}.by(-4)}
      end
    end

    describe "#mv(from, to, mode: mode)" do
      let(:from) {"/a/b/c"}
      let(:to)   {"/d/e/f"}
      let(:file) {File.get(from)}
      let(:dest) {File.get(to)}
      let(:mv1)  {cmd.mv(from, to)}
      let(:mv2)  {cmd.mv(from, to, :mode => :force)}
      let(:mv3)  {cmd.mv(from, to, :mode => :rename)}

      before {cmd.mkdir(from)}

      context "when `to` does not exist" do
        it {expect{mv1}.to change {file.reload.name}.from("c").to("f")}
        it {expect{mv1}.to change {file.reload.dir.name}.from("b").to("e")}
        it {expect{mv1}.to change {file.reload.dir.dir.name}.from("a").to("d")}

        context "when `to`'s dir exists" do
          before {cmd.mkdir("/d/e")}

          it {expect{mv1}.not_to change {File.count}}
        end

        context "when `to`'s dir does not exists" do
          it {expect{mv1}.to change {File.count}.by(2)}
        end
      end

      context "when `to` exists" do
        before {cmd.mkdir(to)}

        context "when default mode" do
          it {expect{mv1}.to raise_error{FileNameConflict}}
        end

        context "when force mode" do
          it {expect{mv2}.to change {file.reload.name}.from("c").to("f")}
          it {expect{mv2}.to change {file.reload.dir.name}.from("b").to("e")}
          it {expect{mv2}.to change {file.reload.dir.dir.name}.from("a").to("d")}
          it {expect{mv2}.to change {File.get(from)}.to(nil)}
          it {expect{mv2}.to change {File.get(to)}.to(file.reload)}
          it {expect{mv2}.to change {File.get("/a").files_count}.by(-1)}
          it {expect{mv2}.to change {File.get("/a/b").files_count}.by(-1)}
          it {expect{mv2}.not_to change {File.get("/d").files_count}}
          it {expect{mv2}.not_to change {File.get("/d/e").files_count}}
          it {expect{mv2}.to change {File.removed.count}.by(1)}
        end

        context "when rename mode" do
          it {expect{mv3}.to change {file.reload.name}.from("c").to("f(1)")}
          it {expect{mv3}.to change {file.reload.dir.name}.from("b").to("e")}
          it {expect{mv3}.to change {file.reload.dir.dir.name}.from("a").to("d")}
          it {expect{mv3}.not_to change {File.get("/a/b").id}}
          it {expect{mv3}.not_to change {File.get("/d/e/f").id}}
          it {expect{mv3}.to change {File.get("/a").files_count}.by(-1)}
          it {expect{mv3}.to change {File.get("/a/b").files_count}.by(-1)}
          it {expect{mv3}.to change {File.get("/d").files_count}.by(1)}
          it {expect{mv3}.to change {File.get("/d/e").files_count}.by(1)}
          it {expect{mv3}.not_to change {File.count}}
        end
      end
    end

    describe "#cp(from, to, mode: mode)" do
      let(:from) {"/a/b/c"}
      let(:to)   {"/d/e/f"}
      let(:file) {File.get(from)}
      let(:dest) {File.get(to)}
      let(:cp1)  {cmd.cp(from, to)}
      let(:cp2)  {cmd.cp(from, to, :mode => :force)}
      let(:cp3)  {cmd.cp(from, to, :mode => :rename)}

      before {cmd.mkdir(from)}

      context "when `to` does not exist" do
        subject {cp1}

        its(:name)          {should eq "f"}
        its("dir.name")     {should eq "e"}
        its("dir.dir.name") {should eq "d"}

        it {expect{cp1}.not_to change{file}}

        context "when `to`'s dir exists" do
          before {cmd.mkdir("/d/e")}

          it {expect{cp1}.to change {File.count}.by(1)}
        end

        context "when `to`'s dir does not exists" do
          it {expect{cp1}.to change {File.count}.by(3)}
        end
      end

      context "when `to` exists" do
        before {cmd.mkdir(to)}

        context "when default mode" do
          it {expect{cp1}.to raise_error{FileNameConflict}}
        end

        context "when force mode" do
          it {expect{cp2}.not_to change {File.get("/a/b/c")}}
          it {expect{cp2}.not_to change {File.count}}
          it {expect{cp2}.not_to change {File.get("/a").files_count}}
          it {expect{cp2}.not_to change {File.get("/a/b").files_count}}
          it {expect{cp2}.not_to change {File.get("/d").files_count}}
          it {expect{cp2}.not_to change {File.get("/d/e").files_count}}
        end

        context "when rename mode" do
          subject {cp3}

          its(:name) {should eq "f(1)"}
          it {expect{cp3}.not_to change {File.get("/a/b").files.count}}
          it {expect{cp3}.to change {File.get("/d/e").files.count}.by(1)}
          it {expect{cp3}.to change {File.count}.by(1)}
          it {expect{cp3}.not_to change {File.get("/a").files_count}}
          it {expect{cp3}.not_to change {File.get("/a/b").files_count}}
          it {expect{cp3}.to change {File.get("/d").files_count}.by(1)}
          it {expect{cp3}.to change {File.get("/d/e").files_count}.by(1)}
        end
      end
    end

    describe "#is_dir?(path)" do
      let(:is_dir?) {cmd.is_dir?(path)}
      subject {is_dir?}

      context "when path does not exist" do
        it {expect{is_dir?}.to raise_error{InvalidPath}}
      end

      context "when path is dir" do
        before {cmd.mkdir(path)}

        it {should be true}
      end

      context "when path is not dir" do
        before {cmd.put(path, store_id)}

        it {should be false}
      end
    end

    describe "#is_file?(path)" do
      let(:is_file?) {cmd.is_file?(path)}
      subject {is_file?}

      context "when path does not exist" do
        it {expect{is_file?}.to raise_error{InvalidPath}}
      end

      context "when path is file" do
        before {cmd.put(path, store_id)}

        it {should be true}
      end

      context "when path is not file" do
        before {cmd.mkdir(path)}

        it {should be false}
      end
    end

    describe "#get_size(path)" do
      let(:get_size) {cmd.get_size(path)}
      subject {get_size}

      context "when path does not exist" do
        it {expect{get_size}.to raise_error{InvalidPath}}
      end

      context "when path is a dir" do
        before {cmd.mkdir(path)}

        it {should be 0}
      end

      context "when path is a file" do
        let(:path) {"/a/b/c.png"}
        before {cmd.put(path, store_id)}

        it {should be 1234}
      end
    end

    describe "#get_count(path)" do
      let(:get_count) {cmd.get_count("/a")}
      subject {get_count}

      context "when path does not exist" do
        it {expect{get_count}.to raise_error{InvalidPath}}
      end

      context "when path is a file" do
        before {cmd.put(path, store_id)}
        subject {cmd.get_count(path)}

        it {should be 0}
      end

      context "when path is a dir" do
        before do
          cmd.mkdir(path)
          cmd.put(path + "/file1", store_id)
          cmd.put(path + "/file2", store_id)
          cmd.put(path + "/file3", store_id)
        end

        it {should be 5}
      end
    end

    describe "#get_last_modified(path)" do
      let(:last_modified) {cmd.get_last_modified(path)}
      subject {last_modified}

      context "when path does not exist" do
        it {expect{last_modified}.to raise_error{InvalidPath}}
      end

      context "when path exists" do
        let(:time) {(Date.today - 30).to_datetime}

        before do
          Timecop.freeze(time) do
            cmd.put(path, store_id)
          end
        end

        context "when not modified" do
          let(:file) {File.get(path)}

          it {should eq time}
          it {expect(file.created_at).to eq(subject)}
        end

        context "when modified" do
          let(:file) {File.get(path)}
          let(:time) {(Date.today - 10).to_datetime}


          before do
            Timecop.freeze(time) do
              file.remove!
            end
          end

          it {should eq time}
        end
      end
    end

    describe "#delta(cursor, limit=100)" do
      let(:cursor) {(Date.today - 30).to_datetime}
      let(:time)   {Date.today - 20}
      let(:limit)  {4}
      let(:delta)  {cmd.delta(cursor, limit)}
      subject {delta}

      before do
        (1..16).each do |n|
          Timecop.freeze(time + n) do
            cmd.put("/file#{n}", store_id)
          end
        end

        Timecop.freeze(time + 18) do
          cmd.mkdir("/a/b/c")
        end
      end

      context "when not exceeding limit" do
        let(:new_cursor) {File.get("/file4").last_modified.to_time}

        its([:new_cursor]) {should eq new_cursor}
        its([:has_more])   {should be true}
        it {expect(subject[:entries].size).to be 4}
        it {expect(subject[:entries][0][:path]).to  eq "/file1"}
        it {expect(subject[:entries][-1][:path]).to eq "/file4"}
      end

      context "when exceeding limit" do
        let(:limit)      {20}
        let(:new_cursor) {File.get("/a/b/c").last_modified.to_time}
        
        its([:new_cursor]) {should eq new_cursor}
        its([:has_more])   {should be false}

        it {expect(subject[:entries].size).to be 19}
        it {expect(subject[:entries][0][:path]).to  eq "/file1"}
        it {expect(subject[:entries][0][:is_dir]).to  be false}
        it {expect(subject[:entries][-1][:path]).to eq "/a/b/c"}
        it {expect(subject[:entries][-1][:is_dir]).to be true}
      end
    end
  end

  describe ".Command(bucket, creator)" do
    let(:creator)  {DummyCreator}
    let(:bucket)   {:bucket}
    subject {VirtualFileSystem::Command(bucket, creator)}

    it {should be_a Command}
  end
end
