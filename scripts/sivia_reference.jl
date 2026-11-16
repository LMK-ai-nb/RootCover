# Independent SIVIA reference in Julia/IntervalArithmetic, written for cross-checking
# RootCover's feasible-set ratios on two pure-conjunction scenarios.
using IntervalRootFinding
const IA = IntervalRootFinding.IntervalArithmetic
using JSON3

lo(x) = IA.inf(x)
hi(x) = IA.sup(x)
width(x) = hi(x) - lo(x)

subset_band(x, a, b) = lo(x) >= a && hi(x) <= b
disjoint_band(x, a, b) = hi(x) < a || lo(x) > b

function robot_inside(B)
    q1, q2 = B
    c1 = cos(q1) + cos(q1 + q2)
    c2 = sin(q1) + sin(q1 + q2)
    c3 = cos(q1)
    ok = subset_band(c1, 0.98, 1.02) && subset_band(c2, 0.98, 1.02) && lo(c3) >= 0
    out = disjoint_band(c1, 0.98, 1.02) || disjoint_band(c2, 0.98, 1.02) || hi(c3) < 0
    return ok, out
end

function thermal_inside(B)
    a, k, b = B
    c1 = a + b
    c2 = a * exp(-k) + b
    c3 = a * exp(-2k) + b
    ok = subset_band(c1, 2.2, 2.3) && subset_band(c2, 1.42, 1.50) &&
         subset_band(c3, 0.94, 1.03) && lo(k) >= 0 && lo(a) >= 0
    out = disjoint_band(c1, 2.2, 2.3) || disjoint_band(c2, 1.42, 1.50) ||
          disjoint_band(c3, 0.94, 1.03) || hi(k) < 0 || hi(a) < 0
    return ok, out
end

function sivia(box, classify, tol)
    inside = 0.0
    envelope = 0.0
    inner_boxes = 0
    boundary_boxes = 0
    stack = [box]
    while !isempty(stack)
        B = pop!(stack)
        v = prod(width.(B))
        ok, out = classify(B)
        if ok
            inside += v
            envelope += v
            inner_boxes += 1
        elseif out
            # excluded, contributes nothing
        elseif maximum(width.(B)) <= tol
            envelope += v
            boundary_boxes += 1
        else
            d = argmax(width.(B))
            x = B[d]
            m = (lo(x) + hi(x)) / 2
            left = copy(B);  left[d] = IA.interval(lo(x), m)
            right = copy(B); right[d] = IA.interval(m, hi(x))
            push!(stack, left)
            push!(stack, right)
        end
    end
    return (inside=inside, envelope=envelope, inner_boxes=inner_boxes, boundary_boxes=boundary_boxes)
end

function run()
    results = Any[]
    scenarios = [
        ("robot_workspace", [IA.interval(-0.25, 1.8), IA.interval(-2.0, 2.0)], robot_inside, 0.02),
        ("thermal_parameters", [IA.interval(1.0, 3.0), IA.interval(0.1, 1.0), IA.interval(0.0, 0.5)], thermal_inside, 0.0625),
    ]
    for (name, box, fn, tol) in scenarios
        vol0 = prod(hi.(box) .- lo.(box))
        t = @elapsed r = sivia(box, fn, tol)
        push!(results, Dict(
            "name" => name,
            "tolerance" => tol,
            "variables" => length(box),
            "inside_boxes" => r.inner_boxes,
            "boundary_boxes" => r.boundary_boxes,
            "inside_volume_ratio" => round(r.inside / vol0; digits=6),
            "envelope_volume_ratio" => round(r.envelope / vol0; digits=6),
            "elapsed_seconds" => round(t; digits=2),
        ))
    end
    open("docs/evidence/sivia-cross-language.json", "w") do io
        JSON3.pretty(io, Dict(
            "implementation" => "hand-written SIVIA in Julia 1.13.3 + IntervalArithmetic (via IntervalRootFinding 0.7.2)",
            "scope" => "two pure-conjunction scenarios; volume ratios only, box counts not comparable",
            "cases" => results,
        ))
    end
end

run()
