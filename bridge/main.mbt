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

///|
let active_session : Ref[@root.PavingSession?] = Ref(None)

///|
fn session_failure(message : String) -> String {
  let value : Json = {
    "error": { "code": "INVALID_SESSION", "message": Json::string(message) },
  }
  value.stringify()
}

///|
/// start/restore replace the session only after successful validation; advance
/// retains the in-memory frontier. CLI does not depend on this mutable slot.
pub fn run_session(source : String, steps : Int32, action : String) -> String {
  try {
    let session = match action {
      "start" => @root.new_paving_session(source)
      "restore" | "load" => @root.restore_paving_session(source)
      "advance" =>
        match active_session.val {
          Some(s) => s
          None => return session_failure("no active feasible-set session")
        }
      _ =>
        return session_failure(
          "session action must be start, restore, load or advance",
        )
    }
    if action != "load" {
      session.advance(steps)
    }
    active_session.val = Some(session)
    session.envelope()
  } catch {
    @root.Invalid(message) => session_failure(message)
  }
}
