module Helpers
  def fixture_path
    Pathname.new(File.expand_path("../fixtures", __FILE__))
  end
end
