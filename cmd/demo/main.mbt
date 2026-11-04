///|
fn main {
  let x = @root.Expr::Variable(0)
  let system : @root.System = {
    names: ["x"],
    equations: [@root.Expr::Sub(@root.Expr::Pow(x, 2), @root.Expr::Const(4.0))],
  }
  let result = @root.solve(
    system,
    [@root.interval(-3.0, 3.0)],
    @root.default_options(),
  ) catch {
    _ => {
      println("Unexpected invalid system")
      return
    }
  }
  println(
    "RootCover: complete=\{result.complete}, unique roots=\{result.roots.length()}",
  )
  for r in result.roots {
    println(
      "x in [\{r.enclosure[0].lo}, \{r.enclosure[0].hi}], contraction bound=\{r.certificate.q}",
    )
  }
}
