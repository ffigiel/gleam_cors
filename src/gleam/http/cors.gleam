import gleam/io
import gleam/http.{Options}
import gleam/http/request
import gleam/http/response
import gleam/http/service
import gleam/bit_builder.{BitBuilder}
import gleam/result
import gleam/list

// boring stuff
type Middleware =
  service.Middleware(BitString, BitBuilder, BitString, BitBuilder)

type Service =
  service.Service(BitString, BitBuilder)

type Request =
  request.Request(BitString)

type Response =
  response.Response(BitBuilder)

// package starts here
pub type Config {
  Config(allowed_origins: List(String))
}

pub fn middleware(config: Config) -> Middleware {
  fn(service: Service) -> Service {
    fn(request: Request) -> Response {
      case request.method {
        Options -> handler(request, config)
        _ -> service(request)
      }
    }
  }
}

fn handler(request: Request, config: Config) -> Response {
  let response =
    response.new(200)
    |> response.set_body(bit_builder.new())

  let is_allowed =
    request.get_header(request, "origin")
    |> result.map(is_origin_allowed(_, config))
    |> result.unwrap(False)

  case is_allowed {
    True ->
      response
      |> prepend_response_headers(
        "access-control-allow-origin",
        config.allowed_origins,
      )
    False -> response
  }
}

fn is_origin_allowed(origin: String, config: Config) -> Bool {
  list.contains(config.allowed_origins, "*") || list.contains(
    config.allowed_origins,
    origin,
  )
}

fn prepend_response_headers(
  response: Response,
  name: String,
  values: List(String),
) -> Response {
  case values {
    [] -> response
    [v, ..vs] ->
      response
      |> response.prepend_header(name, v)
      |> prepend_response_headers(name, vs)
  }
}
