Rails.application.routes.draw do
  # Mission Control - Solid Queue admin dashboard
  require "mission_control/jobs"
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # Letter Opener Web - Email preview in development
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  get "welcome/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify the app is live.
  get "up" => "rails/health#show", :as => :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path for basic testing
  root "rails/health#show"

  # ============================================================================
  # TASK-4.4: Test routes for rate limiting integration tests
  # ============================================================================
  # These routes are used only for testing Rack::Attack throttle rules
  # Always defined so they're available in test environment
  post "test_otp_generation", to: "test_throttle#otp_generation"
  post "test_otp_validation", to: "test_throttle#otp_validation"
  post "test_receipt_upload", to: "test_throttle#receipt_upload"
  post "test_ai_categorization", to: "test_throttle#ai_categorization"
  post "test_entry_creation", to: "test_throttle#entry_creation"
  post "test_general_api", to: "test_throttle#general_api"
  get "test_general_api", to: "test_throttle#general_api"
end
