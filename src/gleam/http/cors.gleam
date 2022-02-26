import gleam/io
import gleam/http.{Options}
import gleam/http/request.{Request}
import gleam/http/response
import gleam/http/service.{Middleware}
import gleam/bit_builder.{BitBuilder}
import gleam/result
import gleam/list
import gleam/set.{Set}
import gleam/io

type Config {
  Config(allowed_origins: AllowedOrigins)
}

type AllowedOrigins {
  AllowNone
  AllowAll
  AllowSome(Set(String))
}

const allow_origin_header = "Access-Control-Allow-Origin"

const allow_all_origins = "*"

fn new_config(allowed_origins: List(String)) -> Config {
  let allowed_origins = case list.contains(allowed_origins, allow_all_origins), allowed_origins {
    True, _ -> AllowAll
    _, [] -> AllowNone
    _, other ->
      set.from_list(other)
      // `handler` relies on "" not being in the set, "" is not a valid origin anyway
      |> set.delete("")
      |> AllowSome
  }
  Config(allowed_origins: allowed_origins)
}

type Response =
  response.Response(BitBuilder)

pub fn middleware(
  allowed_origins: List(String),
) -> Middleware(a, BitBuilder, a, BitBuilder) {
  let config = new_config(allowed_origins)
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

  case is_origin_allowed(origin, config.allowed_origins) {
    True ->
      response
      |> prepend_allow_origin_header(origin, config.allowed_origins)
    False -> response
  }
}

fn is_origin_allowed(origin: String, allowed_origins: AllowedOrigins) -> Bool {
  case allowed_origins {
    AllowNone -> False
    AllowAll -> True
    AllowSome(origins) -> set.contains(origins, origin)
  }
}

fn prepend_allow_origin_header(
  response: Response,
  origin: String,
  allowed_origins: AllowedOrigins,
) -> Response {
  case allowed_origins {
    AllowNone -> response
    AllowAll ->
      response
      |> response.prepend_header(allow_origin_header, allow_all_origins)
    AllowSome(_) ->
      response
      |> response.prepend_header(allow_origin_header, origin)
  }
}
