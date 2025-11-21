require "test_helper"

class AlertMailerTest < ActionMailer::TestCase
  test "critical_threshold_alert sends email with correct content" do
    assert_emails(1) do
      AlertMailer.critical_threshold_alert("error_rate", 0.08, 0.05, "error_rate").deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal ["alerts@grayledger.local"], email.from
    assert_equal ["admin@grayledger.local"], email.to
    assert email.subject.include?("error_rate")
    assert email.body.encoded.include?("8.0%")
    assert email.body.encoded.include?("5.0%")
  end

  test "critical_threshold_alert formats percentage values correctly" do
    assert_emails(1) do
      AlertMailer.critical_threshold_alert("error_rate", 0.084, 0.05, "error_rate").deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert email.body.encoded.include?("8.4%")
  end

  test "critical_threshold_alert formats cache hit rate correctly" do
    assert_emails(1) do
      AlertMailer.critical_threshold_alert("cache_hit_rate", 0.70, 0.80, "cache_hit_rate").deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert email.body.encoded.include?("70.0%")
    assert email.body.encoded.include?("80.0%")
  end

  test "critical_threshold_alert formats job failures correctly" do
    assert_emails(1) do
      AlertMailer.critical_threshold_alert("job_failures", 12, 10, "job_failures").deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert email.body.encoded.include?("12 failures/hr")
    assert email.body.encoded.include?("10 failures/hr")
  end

  test "critical_threshold_alert includes both text and html parts" do
    assert_emails(1) do
      AlertMailer.critical_threshold_alert("error_rate", 0.08, 0.05, "error_rate").deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 2, email.parts.length
    assert email.parts.any? { |part| part.content_type.include?("text/plain") }
    assert email.parts.any? { |part| part.content_type.include?("text/html") }
  end

  test "critical_threshold_alert includes timestamp" do
    assert_emails(1) do
      AlertMailer.critical_threshold_alert("error_rate", 0.08, 0.05, "error_rate").deliver_now
    end

    email = ActionMailer::Base.deliveries.last
    assert email.body.encoded.include?(Time.current.year.to_s)
  end
end
