require "test_helper"

class TestJobTest < ActiveJob::TestCase
  test "should enqueue test job" do
    assert_enqueued_with(job: TestJob) do
      TestJob.perform_later("test-argument")
    end
  end

  test "should execute test job" do
    TestJob.perform_now("test-argument")
    # If we get here without an error, the job executed successfully
    assert true
  end
end
