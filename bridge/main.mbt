///|
/// No numerical logic in JavaScript: both CLI and web call this entry point.
pub fn run_request(source : String) -> String {
  @root.solve_json(source) catch {
    @root.Invalid(message) => {
      let value : Json = {
        "version": 1,
        "error": { "code": "INVALID_REQUEST", "message": Json::string(message) },
      }
      value.stringify()
    }
  }
}
