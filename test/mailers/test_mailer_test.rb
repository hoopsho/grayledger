require "test_helper"

class TestMailerTest < ActionMailer::TestCase
  test "welcome email is sent correctly" do
    email = TestMailer.welcome("recipient@example.com")

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal ["recipient@example.com"], email.to
    assert_equal "Welcome to GrayLedger - Test Email", email.subject
    assert_match(/Welcome to GrayLedger/, email.html_part.decoded)
    assert_match(/GrayLedger sent at/, email.text_part.decoded)
  end
end
