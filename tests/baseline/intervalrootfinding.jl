# Functional reference adapter; no upstream implementation is copied or ported.
# Run in a separate Julia project with IntervalRootFinding and JSON3 installed.
using IntervalRootFinding, JSON3
const IRF = IntervalRootFinding
const I = interval

cases = Any[]
function scalar(name, expression, domain, f)
    push!(cases, (name=name, variables=["x"], equations=[expression], box=[domain], f=f, region=I(domain...)))
end
scalar("documented_four_roots", "sin(x)-0.1*x^2+1", [-10.,10.], x->sin(x)-0.1*x^2+1)
scalar("fixed_point", "cos(x)-x", [0.,1.], x->cos(x)-x)
scalar("exponential_decay", "exp(-x)-x", [0.,1.], x->exp(-x)-x)
scalar("log_domain", "log(x)", [-2.,2.], log)
scalar("sqrt_domain", "sqrt(x)-2", [-1.,9.], x->sqrt(x)-2)
scalar("nested_transcendentals", "sin(exp(x))", [0.,2.], x->sin(exp(x)))
scalar("atan", "atan(x)-0.5", [0.,2.], x->atan(x)-0.5)
scalar("asin", "asin(x)-0.25", [-.9,.9], x->asin(x)-0.25)
scalar("acos", "acos(x)-1", [-.9,.9], x->acos(x)-1)
scalar("sinh", "sinh(x)-1", [-2.,2.], x->sinh(x)-1)
scalar("cosh", "cosh(x)-2", [-2.,2.], x->cosh(x)-2)
scalar("tanh", "tanh(x)-0.5", [-2.,2.], x->tanh(x)-0.5)
scalar("pole_without_root", "1/x", [-1.,1.], x->1/x)
scalar("absolute_corner", "abs(x)", [-.5,2.], abs)
scalar("sqrt_boundary", "sqrt(x)", [-.5,2.], sqrt)
scalar("multiple_log_root", "log(x)^2", [-.5,2.], x->log(x)^2)
push!(cases, (name="trigonometric_2d", variables=["x","y"], equations=["sin(x)","cos(y)"],
    box=[[-3.,3.],[-3.,3.]], f=x->[sin(x[1]),cos(x[2])], region=[I(-3.,3.),I(-3.,3.)]))
push!(cases, (name="robot_2r", variables=["q1","q2"],
    equations=["cos(q1)+cos(q1+q2)-1","sin(q1)+sin(q1+q2)-1"],
    box=[[-.25,1.8],[-2.,2.]], f=x->[cos(x[1])+cos(x[1]+x[2])-1,sin(x[1])+sin(x[1]+x[2])-1],
    region=[I(-.25,1.8),I(-2.,2.)]))
for n in [12,32]
    names=["x$(i)" for i in 0:n-1]
    equations=["2*$(names[i])"*(i>1 ? "-$(names[i-1])-1" : "-2") for i in 1:n]
    push!(cases, (name="coupled_$(n)d", variables=names, equations=equations, box=[[0.,2.] for _ in 1:n],
        f=x->[2*x[i]-(i>1 ? x[i-1]+1 : 2) for i in 1:n], region=[I(0.,2.) for _ in 1:n]))
end
results = Any[]
for case in cases
    runs = Any[]
    for contractor in [IRF.Newton, IRF.Krawczyk]
        try
            roots_found=IRF.roots(case.f,case.region; contractor, abstol=1e-7,max_iteration=10000)
            cells=map(roots_found) do root
                region=IRF.root_region(root)
                box=region isa AbstractVector ? region : [region]
                Dict("box"=>[[Float64(inf(v)),Float64(sup(v))] for v in box],"status"=>string(IRF.root_status(root)))
            end
            push!(runs,Dict("method"=>string(contractor),"cells"=>cells,
                "unique"=>count(c->c["status"]=="unique",cells),"unknown"=>count(c->c["status"]!="unique",cells)))
        catch error
            push!(runs,Dict("method"=>string(contractor),"error"=>sprint(showerror,error)))
        end
    end
    push!(results,Dict("name"=>case.name,"request"=>Dict("version"=>1,"variables"=>case.variables,
        "equations"=>case.equations,"box"=>case.box,"options"=>Dict("tolerance"=>1e-7,"max_assessments"=>10000)),"reference"=>runs))
end
report=Dict("julia_version"=>string(VERSION),"intervalrootfinding_version"=>string(pkgversion(IRF)),
    "purpose"=>"functional comparison, not a timing benchmark or proof of full parity", "cases"=>results)
open(ARGS[1],"w") do io
    JSON3.write(io,report)
end
println("Completed ",length(cases)," models with Newton and Krawczyk.")
