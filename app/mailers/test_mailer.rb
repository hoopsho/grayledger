class TestMailer < ApplicationMailer
  default from: "no-reply@grayledger.local"

  # Test welcome email to verify letter_opener_web configuration
  def welcome(email = "test@example.com")
    @greeting = "Welcome to GrayLedger"
    @timestamp = Time.current

    mail(
      to: email,
      subject: "Welcome to GrayLedger - Test Email"
    )
  end
end
