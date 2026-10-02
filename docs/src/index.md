# DoECISORY.jl

**Design of Experiments with Computational Interactive Sequential Optimisation for Response Yield**

**DoECISORY.jl** is a Julia library and web application for experimental design, stoichiometry, statistical modelling, and response surface analysis:

- **Experimental Design**: 3-factor designs: Box-Behnken (BB15), Central Composite (CD17), Taguchi (TL09), and Fractional D-Optimal (DF14).
- **Optimality Metrics**: D-, A-, G-, and I-efficiencies and condition numbers.
- **Stoichiometry**: Mass conservation, physical unit checks, and radioactive decay equations.
- **Statistical Modelling**: OLS linear and quadratic regression, ANOVA, AIC model selection, and VIF multicollinearity checks.
- **Multi-Objective Optimisation**: Derringer-Suich desirability functions.
- **Visualisation**: 2D contour and 3D response surface plots using PlotlyJS.
- **Web Interface**: Dash browser interface launched via `run_app()`.

---

## Installation

Install DoECISORY using the Julia package manager:

```julia
using Pkg
Pkg.add("DoECISORY")
```

Or from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/erensgol/DoECISORY.jl")
```

---

## Quickstart

Generate a Box-Behnken design matrix, compute its D-efficiency, and fit a quadratic response surface model:

```julia
using DoECISORY

# 1. Generate coded 3-factor design matrix (15 runs)
X_coded = CORE_GenDesign_DDEF("BB15")

# 2. Evaluate design optimality metrics
metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
println("D-Efficiency: ", round(metrics["D"], digits=4))

# 3. Fit a quadratic response surface model
X = Float64.(X_coded)
Y = [2.5 + 1.2*x[1] - 0.8*x[2] + 0.5*x[3]^2 for x in eachrow(X)]
model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=["Temp", "Time", "Conc"])

# 4. Predict response at the centre point
pred = VISE_Predict_DDEF(model, [0.0, 0.0, 0.0])
println("Predicted Centre Response: ", round(pred[1], digits=2))
```

---

## Launching the Web Interface

To launch the web interface in your default browser:

```julia
using DoECISORY
run_app()
```

---

## Documentation Contents

```@contents
Pages = ["manual.md", "api.md", "licence.md"]
Depth = 2
```
