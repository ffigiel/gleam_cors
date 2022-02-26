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
import gleam/function

type Config {
  Config(allowed_origins: AllowedOrigins)
}

type AllowedOrigins {
  AllowAll
  AllowSome(Set(String))
}

const allow_origin_header = "Access-Control-Allow-Origin"

const allow_all_origins = "*"

fn parse_config(allowed_origins: List(String)) -> Result(Config, Nil) {
  try allowed_origins = parse_allowed_origins(allowed_origins)
  Config(allowed_origins: allowed_origins)
  |> Ok
}

fn parse_allowed_origins(l: List(String)) -> Result(AllowedOrigins, Nil) {
  case list.contains(l, allow_all_origins), l {
    True, _ -> Ok(AllowAll)
    _, other -> {
      let origins_set =
        set.from_list(other)
        // `handler` relies on "" not being in the set, "" is not a valid origin anyway
        |> set.delete("")
      case set.size(origins_set) {
        0 -> Error(Nil)
        _ ->
          AllowSome(origins_set)
          |> Ok()
      }
    }
  }
}

type Response =
  response.Response(BitBuilder)

pub fn middleware(
  allowed_origins: List(String),
) -> Middleware(a, BitBuilder, a, BitBuilder) {
  case parse_config(allowed_origins) {
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

  case is_origin_allowed(origin, config.allowed_origins) {
    True ->
      response
      |> prepend_allow_origin_header(origin, config.allowed_origins)
    False -> response
  }
}

fn is_origin_allowed(origin: String, allowed_origins: AllowedOrigins) -> Bool {
  case allowed_origins {
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
    AllowAll ->
      response
      |> response.prepend_header(allow_origin_header, allow_all_origins)
    AllowSome(_) ->
      response
      |> response.prepend_header(allow_origin_header, origin)
      |> response.prepend_header("Vary", "Origin")
  }
}
