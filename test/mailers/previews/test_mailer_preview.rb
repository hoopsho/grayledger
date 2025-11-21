# Preview all emails at http://localhost:3000/rails/mailers/test_mailer
class TestMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/test_mailer/welcome
  def welcome
    TestMailer.welcome
  end
end
