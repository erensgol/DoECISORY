# Workflow Manual

This manual provides a practical guide to using DoECISORY in Julia scripts and notebooks.

---

## 1. Experimental Design Generation

DoECISORY supports four 3-factor experimental design methods via `CORE_GenDesign_DDEF`:

| Code | Method Name | Run Count | Description |
| :--- | :--- | :---: | :--- |
| `"BB15"` | Box-Behnken Design | 15 | 3-level design without extreme corners. |
| `"CD17"` | Central Composite Design | 17 | Full factorial cube with face-centred axial points. |
| `"TL09"` | Taguchi L9 Orthogonal Array | 9 | Fractional screening design. |
| `"DF14"` | Fractional D-Optimal Design | 14 | Directional design oriented by a specified search vector. |

### Example

```julia
using DoECISORY

# Generate Box-Behnken matrix
X_bb = CORE_GenDesign_DDEF("BB15")

# Generate Directional D-optimal design with search direction [1, -1, 1]
X_df = CORE_GenDesign_DDEF("DF14", 3; Direction=[1, -1, 1])
```

---

## 2. Coordinate Mapping (Coded to Physical)

Experimental matrices are generated in coded space $[-1, 0, 1]$. To map these coded coordinates to physical quantities (e.g. Temperature in °C, Concentration in mg/mL), use `CORE_MapLevels_DDEF`:

```julia
config = [
    Dict("Levels" => [20.0, 40.0, 60.0]),   # Factor 1: Temperature (min, mid, max)
    Dict("Levels" => [1.0, 5.0, 10.0]),     # Factor 2: Concentration
    Dict("Levels" => [10.0, 30.0, 60.0])    # Factor 3: Time
]

physical_matrix = CORE_MapLevels_DDEF(X_bb, config)
```

---

## 3. Optimality Metrics (D, A, G, I)

Evaluate the properties of an experimental design matrix:

```julia
metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_bb), "quadratic")

println("D-efficiency:    ", metrics["D"])
println("A-efficiency:    ", metrics["A"])
println("G-efficiency:    ", metrics["G"])
println("I-efficiency:    ", metrics["I"])
println("Condition Number:", metrics["Condition"])
```

---

## 4. Statistical Modelling (OLS, ANOVA, and AIC)

Fit linear or quadratic response surface models and inspect statistical metrics:

```julia
X = Float64.(X_bb)
# Experimental response
Y = [10.0 + 3.0*r[1] - 2.5*r[2] + 1.8*r[3]^2 for r in eachrow(X)]

# Fit model
model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=["Temp", "Conc", "Time"])

println("R-squared:          ", model["R2"])
println("Adjusted R-squared: ", model["AdjR2"])
println("AIC:                ", model["AIC"])

# Compute ANOVA table
anova = VISE_GenerateAnovaTable_DDEF(model)
```

---

## 5. Desirability Functions

Optimise multiple responses simultaneously using Derringer-Suich desirability functions:

```julia
# Define optimisation goals (Type: Maximise, Minimise, or Nominal)
goal_yield  = Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 40.0, "Weight" => 1.0)
goal_impur  = Dict("Type" => "Minimise", "Min" => 0.0,  "Max" => 5.0,  "Target" => 1.0,  "Weight" => 1.0)

# Evaluate desirability for individual response values
d1 = CORE_CalcDesirability_DDEF(25.0, goal_yield)
d2 = CORE_CalcDesirability_DDEF(2.0, goal_impur)

# Overall composite desirability (geometric mean)
D = sqrt(d1 * d2)
println("Composite Desirability: ", round(D, digits=4))
```

---

## 6. Sequential Transitions (ACTA)

The Adaptive Continuous Transition Algorithm (ACTA) calculates contracted and shifted factor boundaries for the next experimental phase based on the best result from Phase 1:

```julia
leader_coords = [0.2, -0.4, 0.6]
# next_bounds = FLOW_ApplyACTA_DDEF(...)
```
