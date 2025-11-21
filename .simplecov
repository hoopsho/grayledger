SimpleCov.formatters = [SimpleCov::Formatter::HTMLFormatter]

SimpleCov.configure do
  root "/home/cjm/work/grayledger"

  # Set minimum coverage threshold
  minimum_coverage 30
  minimum_coverage_by_file 0

  # Enable branch coverage
  enable_coverage :branch

  # Add custom groups for better organization
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Jobs", "app/jobs"
  add_group "Mailers", "app/mailers"
  add_group "Policies", "app/policies"
  add_group "Services", "app/services"
  add_group "Helpers", "app/helpers"
  add_group "Concerns", "app/concerns"
  add_group "Config", "config"
  add_group "Lib", "lib"

  # Exclude files from coverage
  add_filter "/test/"
  add_filter "/db/migrate"
  add_filter "/config/initializers"
  add_filter "config/application.rb"
  add_filter "config/boot.rb"
  add_filter "config/environment.rb"
  add_filter "bin/"

  # Exclude generated/system files
  add_filter ".git"
  add_filter ".bundle"
  add_filter "log/"
  add_filter "tmp/"
  add_filter "vendor/"
  add_filter "coverage/"
  add_filter "node_modules/"
  add_filter "app/assets/"

  # Set output directory
  coverage_dir "coverage"
end
