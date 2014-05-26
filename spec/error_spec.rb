require "spec_helper"

module VirtualFileSystem
  describe Error do
    describe ".raise!(msg, &cond)" do
      let(:msg) {"error"}

      it {expect {Error.raise!}.to raise_error(Error)}
      it {expect {Error.raise!(msg) {true}}.to raise_error(Error, msg)}
      it {expect {Error.raise! {false}}.not_to raise_error}
    end
  end
end
