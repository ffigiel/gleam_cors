# gleam_cors

A CORS middleware for Gleam.

## Usage

Use the `middleware` function to set up CORS for your application. This middleware should be
placed early in your middleware stack (late in the pipeline).

```diff
+import gleam/http/cors
+import gleam/http
 import myproject/web/middleware

 pub fn stack() {
   service
   |> middleware.rescue
   |> middleware.log
+  |> cors.middleware(
+    origins: ["http://localhost:8000"],
+    methods: [http.Get, http.Post, http.Delete],
+    headers: ["Authorization", "Content-Type"],
+  )
 }
```

## Changelog

See [CHANGELOG.md](CHANGELOG.md)
