class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Track job execution time [TASK-6.2]
  before_perform :track_job_start
  after_perform :track_job_completion

  private

  # Record job start time for performance metrics [TASK-6.2]
  def track_job_start
    @job_start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Track job execution time and record as metric [TASK-6.2]
  def track_job_completion
    return unless @job_start_time

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @job_start_time) * 1000).to_i
    job_name = self.class.name

    # Track using the MetricsTracker service
    MetricsTracker.track_timing(
      "job_execution_time_ms",
      duration_ms,
      job_class: job_name
    )
  end
end
