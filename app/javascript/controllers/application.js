import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
if (import.meta.hot) {
  import.meta.hot.dispose(() => application.stop())
  import.meta.hot.accept(() => {
    console.log("HMR accepted")
  })
}

export { application }
