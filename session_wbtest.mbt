///|
fn session_test_request() -> String {
  let source =
    #|{"version":1,"mode":"feasibility","variables":["x"],"constraints":[{"expression":"x","range":[0.2,0.8]}],"box":[[0,1]],"contractors":{"propagation":false,"newton":false},"options":{"tolerance":0.03125,"max_assessments":500,"max_depth":20},"search":{"strategy":"bfs","split":"scaled"}}
  source
}

///|
fn without_session(source : String) -> String raise RootError {
  let o = j_document(source)
  o.remove("session") |> ignore
  Json::object(o).stringify()
}

///|
test "session chunks preserve one-shot output and never reset cumulative budgets" {
  let source = session_test_request()
  let session = new_paving_session(source)
  session.advance(1)
  assert_eq(session.assessments, 1)
  assert_eq(session.queue.pending().length(), 2)
  assert_true(
    !j_object(j_document(session.snapshot()).get("session").unwrap()).is_empty(),
  )
  let checkpoint = session.checkpoint()
  let restored = restore_paving_session(checkpoint)
  assert_eq(restored.checkpoint(), checkpoint)
  assert_eq(restored.replayed_events, 1)
  assert_eq(restored.replayed_leaf_checks, 0)
  while !restored.queue.empty() {
    restored.advance(3)
  }
  assert_eq(without_session(restored.snapshot()), solve_json(source))
  let finished = restored.snapshot()
  restored.advance(20000)
  assert_eq(restored.snapshot(), finished)
}

///|
test "checkpoint cannot forge a whole-box inside or outside decision" {
  let source = session_test_request()
  for kind in ["inside", "outside"] {
    let checkpoint : Json = {
      "checkpoint_version": 1,
      "kind": "rootcover.feasibility",
      "request": Json::string(source),
      "events": [{ "kind": Json::string(kind) }],
    }
    let rejected = try {
      restore_paving_session(checkpoint.stringify()) |> ignore
      false
    } catch {
      Invalid(_) => true
    }
    assert_true(rejected)
  }
  let empty = new_paving_session(source)
  let restored = restore_paving_session(empty.checkpoint())
  assert_true(!restored.queue.empty())
  assert_eq(restored.assessments, 0)
}

///|
test "a malformed split cannot remove or escape the initial domain" {
  for point in [-0.1, 0.0, 1.0, 1.1] {
    let checkpoint : Json = {
      "checkpoint_version": 1,
      "kind": "rootcover.feasibility",
      "request": Json::string(session_test_request()),
      "events": [{ "kind": "split", "axis": 0, "point": Json::number(point) }],
    }
    let rejected = try {
      restore_paving_session(checkpoint.stringify()) |> ignore
      false
    } catch {
      Invalid(_) => true
    }
    assert_true(rejected)
  }
}

///|
test "depth precision and total assessment stops survive restore" {
  let o = j_document(session_test_request())
  o.set("options", {
    "tolerance": 0.000001,
    "max_assessments": 3,
    "max_depth": 1,
  })
  let session = new_paving_session(Json::object(o).stringify())
  session.advance(1)
  let restored = restore_paving_session(session.checkpoint())
  restored.advance(100)
  assert_eq(restored.assessments, 3)
  assert_eq(restored.unknown.length(), 2)
  assert_true(restored.unknown.all(b => b.reason == "depth limit reached"))
  assert_true(restored.queue.empty())
  assert_eq(restore_paving_session(restored.checkpoint()).unknown.length(), 2)
}

///|
test "positive alternatives restore valid inactive undefined atoms" {
  let source =
    #|{"version":1,"mode":"feasibility","variables":["x"],"constraints":[{"expression":"x","range":[-2,-1]},{"expression":"log(x)","range":[0,1]}],"formula":{"any":[0,1]},"box":[[-2,3]],"options":{"tolerance":0.05,"max_assessments":1000}}
  let session = new_paving_session(source)
  session.advance(5)
  let restored = restore_paving_session(session.checkpoint())
  restored.advance(1000)
  assert_true(restored.formula_inside.any(b => b.box[0].contains(-1.5)))
  assert_eq(without_session(restored.snapshot()), solve_json(source))
}

///|
test "restore preserves contractor allowance instead of granting each chunk a fresh one" {
  let source =
    #|{"version":1,"mode":"feasibility","variables":["x","y"],"constraints":[{"expression":"x^2+y^2","range":[0.8,1.2]}],"box":[[-2,2],[-2,2]],"contractors":{"max_steps":9},"options":{"max_assessments":80,"tolerance":0.05},"search":{"strategy":"dfs","split":"smear"}}
  let session = new_paving_session(source)
  session.advance(7)
  let restored = restore_paving_session(session.checkpoint())
  assert_eq(restored.contractor_calls, session.contractor_calls)
  restored.advance(80)
  assert_true(restored.contractor_calls <= 9)
  assert_eq(without_session(restored.snapshot()), solve_json(source))
}
