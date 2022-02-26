import gleeunit
import gleam/bit_builder.{BitBuilder}
import gleam/list
import gleam/http/response.{Response}
import gleam/http/request
import gleeunit/should
import gleam/http.{Delete, Options, Post}
import gleam/http/cors

pub fn main() {
  gleeunit.main()
}

fn service(_) -> Response(BitBuilder) {
  response.new(200)
  |> response.set_body(bit_builder.new())
}

pub fn allowed_origins_test() {
  let handler =
    service
    |> cors.middleware(
      origins: ["https://example.com", "http://example.com"],
      methods: [Post],
      headers: [],
    )
  let test_origin = fn(request, should_allow, origin) {
    let result =
      request
      |> request.prepend_header("Origin", origin)
      |> handler
      |> response.get_header("Access-Control-Allow-Origin")
    case should_allow {
      True -> should.equal(result, Ok(origin))
      False -> should.be_error(result)
    }
  }

  let preflight_req =
    request.new()
    |> request.set_method(Options)
    |> request.prepend_header("Access-Control-Request-Method", "POST")

  let normal_req =
    request.new()
    |> request.set_method(Post)

  // responses to both preflight and normal requests should include the Allow-Origin header
  [preflight_req, normal_req]
  |> list.each(fn(req) {
    test_origin(req, True, "https://example.com")
    test_origin(req, True, "http://example.com")
    test_origin(req, False, "http://example.com:80")
    test_origin(req, False, "http://localhost:8000")
  })
}

pub fn allowed_methods_test() {
  let origin = "https://example.com"
  let handler =
    service
    |> cors.middleware(origins: [origin], methods: [Post, Delete], headers: [])
  let test_method = fn(request, should_allow) {
    let result =
      request
      |> handler
      |> response.get_header("Access-Control-Allow-Origin")
    case should_allow {
      True -> should.equal(result, Ok(origin))
      False -> should.be_error(result)
    }
  }
  let with_cors_method = fn(request, method) {
    request.prepend_header(request, "Access-Control-Request-Method", method)
  }
  let req =
    request.new()
    |> request.set_method(Options)
    |> request.prepend_header("Origin", origin)

  test_method(with_cors_method(req, "POST"), True)
  test_method(with_cors_method(req, "Delete"), True)
  test_method(with_cors_method(req, "GET"), False)
  // disallow if there is no no request method header
  test_method(req, False)
}

pub fn allowed_headers_test() {
  let origin = "https://example.com"
  let handler =
    service
    |> cors.middleware(
      origins: [origin],
      methods: [Post],
      headers: ["Authorization", "Content-Type", "X-Request-Id"],
    )
  let test_headers = fn(request, should_allow) {
    let result =
      request
      |> handler
      |> response.get_header("Access-Control-Allow-Origin")
    case should_allow {
      True -> should.equal(result, Ok(origin))
      False -> should.be_error(result)
    }
  }
  let with_cors_headers = fn(request, headers) {
    request.prepend_header(request, "Access-Control-Request-Headers", headers)
  }
  let req =
    request.new()
    |> request.set_method(Options)
    |> request.prepend_header("Origin", origin)
    |> request.prepend_header("Access-Control-Request-Method", "POST")
  test_headers(with_cors_headers(req, "Authorization"), True)
  test_headers(with_cors_headers(req, "X-REQUEST-ID, content-type"), True)
  test_headers(with_cors_headers(req, "X-Request-Id, Whatever"), False)
  // allow if no cors headers are declared
  test_headers(req, True)
}
