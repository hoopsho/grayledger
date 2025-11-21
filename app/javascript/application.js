// Entry point for the application.
//
// This is the manifest file that'll be compiled into one of the application.js bundles.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but rather in separate, properly organized modules
// within the app/javascript directory.

// Turbo Drive enables fast, smooth page transitions
import "@hotwired/turbo-rails"

// Stimulus Controller Framework
import "@hotwired/stimulus-rails"
import { application } from "./controllers/application"

// Eager load all Stimulus controllers defined in the controllers directory.
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)
