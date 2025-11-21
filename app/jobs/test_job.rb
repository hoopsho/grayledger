class TestJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.info("TestJob executed with args: #{args.inspect}")
    puts "TestJob executed successfully at #{Time.current}"
  end
end
