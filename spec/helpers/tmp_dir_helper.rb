module TmpDirHelper
  def in_tmp_dir(dir_name = 'tmp_working_dir')
    Dir.mktmpdir(dir_name) do |dir|
      Dir.chdir(dir) do
        yield dir
      end
    end
  end
end

RSpec.configure do |config|
  config.include TmpDirHelper
end
