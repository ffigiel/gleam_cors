import gleam/http.{Method, Options}
import gleam/http/request.{Request}
import gleam/http/response
import gleam/http/service.{Middleware}
import gleam/bit_builder.{BitBuilder}
import gleam/result
import gleam/list
import gleam/set.{Set}
import gleam/function
import gleam/string

type Config {
  Config(
    allowed_origins: AllowedOrigins,
    allowed_methods: AllowedMethods,
    allowed_headers: AllowedHeaders,
  )
}

type AllowedOrigins {
  AllowAll
  AllowSome(Set(String))
}

type AllowedMethods =
  Set(Method)

type AllowedHeaders =
  Set(String)

const allow_origin_header = "Access-Control-Allow-Origin"

const allow_all_origins = "*"

const request_method_header = "Access-Control-Request-Method"

const request_headers_header = "Access-Control-Request-Headers"

const allow_headers_header = "Access-Control-Allow-Headers"

fn parse_config(
  allowed_origins: List(String),
  allowed_methods: List(Method),
  allowed_headers: List(String),
) -> Result(Config, Nil) {
  try allowed_origins = parse_allowed_origins(allowed_origins)
  try allowed_methods = parse_allowed_methods(allowed_methods)
  try allowed_headers = parse_allowed_headers(allowed_headers)
  Config(allowed_origins, allowed_methods, allowed_headers)
  |> Ok
}

fn parse_allowed_origins(l: List(String)) -> Result(AllowedOrigins, Nil) {
  case list.contains(l, allow_all_origins), l {
    True, _ -> Ok(AllowAll)
    _, origins -> {
      let origins_set =
        origins
        |> list.map(string.lowercase)
        |> set.from_list
        // `handler` relies on "" not being in the set, "" is not a valid origin anyway
        |> set.delete("")
      case set.size(origins_set) {
        0 -> Error(Nil)
        _ ->
          AllowSome(origins_set)
          |> Ok
      }
    }
  }
}

fn parse_allowed_methods(l: List(Method)) -> Result(AllowedMethods, Nil) {
  let methods_set = set.from_list(l)
  case set.size(methods_set) {
    0 -> Error(Nil)
    _ -> Ok(methods_set)
  }
}

fn parse_allowed_headers(l: List(String)) -> Result(AllowedHeaders, Nil) {
  let headers_set =
    l
    |> list.map(string.lowercase)
    |> set.from_list
  case set.size(headers_set) {
    0 -> Error(Nil)
    _ -> Ok(headers_set)
  }
}

type Response =
  response.Response(BitBuilder)

pub fn middleware(
  origins allowed_origins: List(String),
  methods allowed_methods: List(Method),
  headers allowed_headers: List(String),
) -> Middleware(a, BitBuilder, a, BitBuilder) {
  case parse_config(allowed_origins, allowed_methods, allowed_headers) {
    Ok(config) -> middleware_from_config(config)
    Error(_) -> function.identity
  }
}

fn middleware_from_config(
  config: Config,
) -> Middleware(a, BitBuilder, a, BitBuilder) {
  fn(service) {
    fn(request: Request(a)) -> Response {
      case request.method {
        Options -> handler(request, config)
        _ -> service(request)
      }
    }
  }
}

fn handler(request: Request(a), config: Config) -> Response {
  let response =
    response.new(200)
    |> response.set_body(bit_builder.new())

  let origin =
    request.get_header(request, "origin")
    |> result.unwrap("")

  let ac_request_method =
    request.get_header(request, request_method_header)
    |> result.then(http.parse_method)
    |> result.unwrap(http.Other(""))

  let ac_request_headers =
    request.get_header(request, request_headers_header)
    |> result.map(string.split(_, ", "))
    |> result.unwrap([])

  let is_request_allowed =
    is_origin_allowed(origin, config.allowed_origins) && is_method_allowed(
      ac_request_method,
      config.allowed_methods,
    ) && are_headers_allowed(ac_request_headers, config.allowed_headers)
  case is_request_allowed {
    True ->
      response
      |> prepend_allow_origin_header(origin, config.allowed_origins)
      |> prepend_allow_headers_header(ac_request_headers)
    False -> response
  }
}

fn is_origin_allowed(origin: String, allowed_origins: AllowedOrigins) -> Bool {
  case allowed_origins {
    AllowAll -> True
    AllowSome(origins) -> set.contains(origins, string.lowercase(origin))
  }
}

fn is_method_allowed(method: Method, allowed_methods: AllowedMethods) -> Bool {
  set.contains(allowed_methods, method)
}

fn are_headers_allowed(
  request_headers: List(String),
  allowed_headers: AllowedHeaders,
) -> Bool {
  list.all(
    request_headers,
    fn(header) { set.contains(allowed_headers, string.lowercase(header)) },
  )
}

fn prepend_allow_origin_header(
  response: Response,
  origin: String,
  allowed_origins: AllowedOrigins,
) -> Response {
  case allowed_origins {
    AllowAll ->
      response
      |> response.prepend_header(allow_origin_header, allow_all_origins)
    AllowSome(_) ->
      response
      |> response.prepend_header(allow_origin_header, origin)
      |> response.prepend_header("Vary", "Origin")
  }
}

fn prepend_allow_headers_header(
  response: Response,
  headers: List(String),
) -> Response {
  case list.length(headers) {
    0 -> response
    _ ->
      string.join(headers, ", ")
      |> response.prepend_header(response, allow_headers_header, _)
  }
}
