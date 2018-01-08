require 'unicorn'

class FakeHttpServer < Unicorn::HttpServer
  def process_client(_client)
  end
end
