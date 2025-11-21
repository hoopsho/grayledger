# Importmap Configuration for Zero-Build-Step JavaScript

## Overview

This Rails 8 application uses **importmap-rails** to manage JavaScript dependencies without any build step. This means:

- No Node.js required
- No webpack, Vite, or other bundlers
- No package.json or node_modules
- ESM (ES Modules) loaded directly in the browser
- Zero build overhead for development

## Configuration Files

### 1. `/home/cjm/work/grayledger/config/importmap.rb`

This is the central configuration file that maps JavaScript package names to their CDN URLs:

```ruby
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus-rails", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
```

**Key Options:**
- `preload: true` - Preload critical scripts (improves performance by starting download early)
- `to:` - Maps to a specific CDN URL
- `pin_all_from` - Auto-maps all controllers in a directory

### 2. `/home/cjm/work/grayledger/app/javascript/application.js`

The main entry point that imports Turbo and Stimulus:

```javascript
import "@hotwired/turbo-rails"
import "@hotwired/stimulus-rails"
import { application } from "./controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)
```

### 3. `/home/cjm/work/grayledger/app/javascript/controllers/application.js`

The Stimulus application bootstrap:

```javascript
import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Hot Module Replacement for development
if (import.meta.hot) {
  import.meta.hot.dispose(() => application.stop())
  import.meta.hot.accept(() => {
    console.log("HMR accepted")
  })
}

export { application }
```

### 4. Layout Template: `/home/cjm/work/grayledger/app/views/layouts/application.html.erb`

The `<%= importmap_tags %>` helper renders the necessary script tags in the HTML head:

```erb
<%= importmap_tags %>
```

This generates:
- An `<script type="importmap">` tag with the import map JSON
- A `<script>` tag that loads the application.js entry point
- All with **Subresource Integrity (SRI)** hashes by default

## How Importmap Works

### 1. Browser Loading Flow

```
1. Browser loads HTML page
2. Sees <script type="importmap"> with package mappings
3. Sees <script type="module" src="application.js">
4. Browser resolves imports via the importmap
5. CDN packages load directly (no bundler)
6. Rails 8 handles module caching intelligently
```

### 2. Module Resolution Example

When your code does:
```javascript
import { Controller } from "@hotwired/stimulus"
```

Importmap converts this to:
```javascript
// Actual request to CDN
https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.x/dist/stimulus.min.js
```

### 3. Development vs Production

**Development:**
- Propshaft serves `app/javascript/*` files directly
- No bundling step
- Changes are instant (reload page to see)

**Production:**
- Propshaft pre-digests and compresses all assets
- `public/assets/` contains fingerprinted, gzipped versions
- CDN URLs are baked into the importmap at deploy time

## Subresource Integrity (SRI)

SRI is **enabled by default** in importmap-rails. Each `<script>` tag includes an `integrity` attribute:

```html
<script type="module" src="https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.x/dist/stimulus.min.js" integrity="sha384-..." crossorigin="anonymous"></script>
```

**Benefits:**
- Protects against CDN compromises
- Browsers verify script authenticity before execution
- CORS-compliant headers added automatically

**How Importmap Handles SRI:**
- SHA-384 hashes are fetched from CDN JavaScript API
- Hashes are cached in `config/importmap.lock` (if using `./bin/importmap` CLI)
- On each deploy, importmap regenerates hashes

## Adding New JavaScript Packages

### Option 1: Use the Importmap CLI (Recommended)

```bash
./bin/importmap pin @hotwired/keyboard-time-travel@^2.0
```

This automatically:
- Adds the pin to `config/importmap.rb`
- Calculates SRI hash
- Updates the lock file

### Option 2: Manual Pin in config/importmap.rb

```ruby
pin "@socket.io", to: "https://cdn.socket.io/4.5.4/socket.io.min.js"
pin "lodash-es", to: "https://cdn.jsdelivr.net/npm/lodash-es@4.17.21/lodash.min.js"
```

### Option 3: Pin from Node Packages (Development)

```bash
./bin/importmap pin lodash
# Downloads latest from npmpkg.com and adds to importmap.rb
```

## Creating Stimulus Controllers

Stimulus controllers auto-register via the `pin_all_from "app/javascript/controllers"` directive.

**File: `app/javascript/controllers/form_submit_controller.js`**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  submit(event) {
    event.preventDefault()
    console.log("Form submitted!")
    this.formTarget.submit()
  }
}
```

**HTML Usage:**

```erb
<div data-controller="form-submit">
  <form data-form-submit-target="form">
    <!-- form fields -->
  </form>
</div>
```

Naming convention: `FormSubmitController` → `data-controller="form-submit"`

## Turbo Integration

Turbo Drive and Turbo Frames work seamlessly:

**Turbo Drive:**
```javascript
// Automatically intercepted by importmap-loaded turbo-rails
// No special configuration needed
```

**Turbo Streams (WebSockets):**
```erb
<%= turbo_stream.replace("post_#{@post.id}", partial: "post", locals: { post: @post }) %>
```

When rendered over WebSocket, importmap-loaded Stimulus controllers automatically reconnect.

## Performance Characteristics

### Load Time Behavior

| Scenario | Time | Notes |
|----------|------|-------|
| Cold start (no cache) | ~200ms | CDN roundtrips for 3-4 packages |
| Warm browser cache | ~50ms | Scripts cached locally |
| Subsequent pages (SPA-like) | ~20ms | Turbo Drive + cached scripts |

### Optimization Tips

1. **Preload Critical Packages:**
   ```ruby
   pin "application", preload: true
   pin "@hotwired/turbo-rails", preload: true
   ```

2. **Use Link Preload Headers** (in production):
   ```ruby
   # Rails automatically adds Link headers for preload: true pins
   ```

3. **Browser Caching:**
   - CDN URLs are immutable (include version)
   - Browser caches for 1 year by default
   - Subsequent page loads have zero download overhead

4. **Lazy Load Heavy Libraries:**
   ```ruby
   pin "chart.js"  # No preload, loaded on-demand by controller
   ```

## Content Security Policy (CSP)

Importmap works with CSP if properly configured in `config/initializers/content_security_policy.rb`:

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    # Allow jsdelivr CDN (where modules are fetched from)
    policy.script_src :self, :https, "https://cdn.jsdelivr.net"
  end

  # Enable nonce generation for inline scripts (importmap)
  config.content_security_policy_nonce_generator = ->(request) { request.session.id.to_s }
  config.content_security_policy_nonce_directives = %w(script-src style-src)
end
```

## Troubleshooting

### JavaScript Not Loading in Browser

1. **Check the Console:**
   - Look for 404 errors on CDN URLs
   - Verify `<script type="importmap">` is in source

2. **Verify Importmap Tags:**
   ```erb
   <%= importmap_tags %>
   ```
   Must be in `<head>` before closing tag

3. **Check Rails Server:**
   ```bash
   rails s
   # Visit http://localhost:3000
   # View page source - should see importmap JSON
   ```

### Module Not Found Error

```javascript
Uncaught TypeError: Failed to resolve module specifier "@hotwired/stimulus"
```

**Solution:** Ensure the pin exists in `config/importmap.rb`:

```ruby
pin "@hotwired/stimulus", to: "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.x/dist/stimulus.min.js"
```

### SRI Mismatch in Production

If you see "Failed to fetch (integrity mismatch)":

1. The SRI hash changed but wasn't updated
2. Run `./bin/importmap pins` to regenerate all hashes
3. Or manually delete the hash from the pin if you trust the CDN

## Comparison to Alternatives

| Feature | Importmap | Webpack | Vite |
|---------|-----------|---------|------|
| Build step | No | Yes | Yes |
| Node.js required | No | Yes | Yes |
| Dev experience | Instant | Fast | Very fast |
| Browser support | Modern ES6+ | IE11+ | Modern ES6+ |
| Bundle size | Larger (no tree-shake) | Small | Small |
| Production ready | Yes | Yes | Yes |

For Grayledger (modern browsers only), **Importmap is the perfect choice** because:
- Zero build overhead
- Simple to understand and debug
- Works perfectly with Hotwire
- No external tool dependencies

## Resources

- [Importmap Rails GitHub](https://github.com/rails/importmap-rails)
- [Rails Guides: JavaScript](https://guides.rubyonrails.org/javascript_with_rails.html)
- [MDN: ES Modules](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules)
- [Hotwired: Turbo + Stimulus](https://hotwired.dev)
