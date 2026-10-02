# Case Study: Sequential Peptide Radiolabelling

This case study demonstrates the sequential optimisation workflow in **DoECISORY.jl**, tracking an experimental peptide formulation through initial design, radioactive decay adjustments, quadratic regression, multi-objective optimisation with kinetic penalties, and automated phase transition via **ACTA** and **ASTM**.

---

## Problem Formulation

* **Objective:** Optimise formulation parameters for a Gallium-68 labelled model peptide.
* **Continuous Factors (3):**
  1. `Temperature` ($X_1$): $30.0$ to $90.0\,^\circ\text{C}$ (centre: $60.0\,^\circ\text{C}$)
  2. `ReactionTime` ($X_2$): $5.0$ to $35.0\,\text{min}$ (centre: $20.0\,\text{min}$)
  3. `Precursor` ($X_3$): $10.0$ to $50.0\,\mu\text{g}$ (centre: $30.0\,\mu\text{g}$)
* **Responses (3):**
  1. `RadiochemicalYield` ($Y_1$, %): Maximise (Target: 95.0%, Min: 60.0%, Weight: 1.5)
  2. `RadiolyticImpurity` ($Y_2$, %): Minimise (Target: 1.0%, Max: 8.0%, Weight: 1.0)
  3. `ColloidalFraction` ($Y_3$, %): Minimise (Target: 0.5%, Max: 5.0%, Weight: 1.0)
* **Radionuclide:** Gallium-68 ($t_{1/2} = 67.71\,\text{min}$, $\lambda = 0.010237\,\text{min}^{-1}$)

---

## 1. Recipe Specification and Stoichiometry

Before allocating precious radioisotope doses or physical resources, the formulation recipe is audited in `Gui_Deck` or headless scripts for mass balance and concentration validity:

```julia
using DoECISORY

# Define formulation ingredients
recipe = [
    Dict("Name" => "Peptide_Precursor", "Role" => "VAR",  "MW" => 1435.6, "Unit" => "ug", "Mass" => 30.0),
    Dict("Name" => "Sodium_Acetate",    "Role" => "FIX",  "MW" => 82.03,  "Unit" => "mg", "Mass" => 15.0),
    Dict("Name" => "Ascorbic_Acid",     "Role" => "FIX",  "MW" => 176.12, "Unit" => "mg", "Mass" => 5.0),
    Dict("Name" => "Water_for_Inj",     "Role" => "FILL", "MW" => 18.015, "Unit" => "uL", "Mass" => 1000.0)
]

# Run stoichiometric audit
total_vol_uL = 1000.0
target_conc_ug_mL = 30.0
audit_ok, audit_report, summary_df, total_mass_mg, _ = MOLE_QuickAudit_DDEF(recipe, total_vol_uL, target_conc_ug_mL)

println("Stoichiometric Audit Passed: ", audit_ok)
```

---

## 2. Design Matrix Generation (DF14)

We construct a 14-point directional D-optimal (`"DF14"`) design matrix oriented towards elevated temperature and moderate duration, then evaluate its information efficiency:

```julia
# 1. Generate coded 14-run design matrix in [-1, 0, 1]
X_coded = CORE_GenDesign_DDEF("DF14", 3; Direction=[1, 0, 1])

# 2. Evaluate D-, A-, G-, and I-optimality metrics for a quadratic model
metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
println("D-efficiency:     ", round(metrics["D"], digits=2), "%")
println("Condition Number: ", round(metrics["Condition"], digits=2))

# 3. Map coded coordinates to physical laboratory units
factor_config = [
    Dict("Name" => "Temperature",  "Levels" => [30.0, 60.0, 90.0]),
    Dict("Name" => "ReactionTime", "Levels" => [5.0,  20.0, 35.0]),
    Dict("Name" => "Precursor",    "Levels" => [10.0, 30.0, 50.0])
]

X_physical = CORE_MapLevels_DDEF(X_coded, factor_config)
```

---

## 3. Experimental Dataset and Decay Adjustments

We simulate laboratory observations including preparation delay ($\Delta t_{\text{forw}}$) and measurement latency ($\Delta t_{\text{reve}}$) across all three experimental responses:

```julia
using DataFrames, Random
Random.seed!(42)

N = size(X_physical, 1)

# Synthetic experimental dataset with physical non-linear behaviour
df_exp = DataFrame(
    :RUN => 1:N,
    Symbol("INPUT_Temperature")  => X_physical[:, 1],
    Symbol("INPUT_ReactionTime") => X_physical[:, 2],
    Symbol("INPUT_Precursor")    => X_physical[:, 3],
    # Preparation delay before synthesis initiation (0 to 12 mins)
    :TIME_FORW_MINS_Peptide_Precursor => rand(0.0:0.5:12.0, N),
    # Analytical latency before HPLC quantification (5 to 25 mins)
    :TIME_REVE_MINS_RadiochemicalYield => rand(5.0:1.0:25.0, N)
)

# 1. Radiochemical Yield (%): Peak around 75°C, 18 min, 35 ug
df_exp[!, :RESULT_RadiochemicalYield] = [
    clamp(70.0 + 0.38*r[1] + 0.90*r[2] + 0.22*r[3] - 0.003*r[1]^2 - 0.024*r[2]^2 + randn()*1.0, 50.0, 99.0)
    for r in eachrow(X_physical)
]

# 2. Radiolytic Impurity (%): Increases with temperature and time
df_exp[!, :RESULT_RadiolyticImpurity] = [
    clamp(0.8 + 0.045*r[1] + 0.075*r[2] - 0.012*r[3] + 0.0005*r[1]*r[2] + randn()*0.25, 0.4, 10.0)
    for r in eachrow(X_physical)
]

# 3. Colloidal Fraction (%): Forms at low precursor concentration and excessive heating
df_exp[!, :RESULT_ColloidalFraction] = [
    clamp(3.5 - 0.03*r[1] + 0.04*r[2] - 0.055*r[3] + 0.0004*r[1]^2 + randn()*0.20, 0.1, 6.0)
    for r in eachrow(X_physical)
]
```

---

## 4. Regression Modelling and ANOVA

We fit full quadratic response surface models for all three outputs and verify goodness-of-fit and lack-of-fit sufficiency:

```julia
in_names  = ["Temperature", "ReactionTime", "Precursor"]
out_names = ["RadiochemicalYield", "RadiolyticImpurity", "ColloidalFraction"]

X_mat = Matrix{Float64}(X_physical)
Y_yield   = Vector{Float64}(df_exp[!, :RESULT_RadiochemicalYield])
Y_impur   = Vector{Float64}(df_exp[!, :RESULT_RadiolyticImpurity])
Y_colloid = Vector{Float64}(df_exp[!, :RESULT_ColloidalFraction])

# Fit quadratic models
model_yield   = VISE_Regress_DDEF(X_mat, Y_yield,   "quadratic"; InNames=in_names)
model_impur   = VISE_Regress_DDEF(X_mat, Y_impur,   "quadratic"; InNames=in_names)
model_colloid = VISE_Regress_DDEF(X_mat, Y_colloid, "quadratic"; InNames=in_names)

println("--- Model Validation Summary ---")
println("Yield   | R²: ", round(model_yield["R2"], digits=3),   " | Q²: ", round(model_yield["Q2"], digits=3))
println("Impurity| R²: ", round(model_impur["R2"], digits=3),   " | Q²: ", round(model_impur["Q2"], digits=3))
println("Colloid | R²: ", round(model_colloid["R2"], digits=3), " | Q²: ", round(model_colloid["Q2"], digits=3))

# Check ANOVA and Lack-of-Fit for Primary Response
anova_yield = VISE_GenerateAnovaTable_DDEF(model_yield)
```

---

## 5. Multi-Objective Optimisation and DCYP

We establish desirability criteria across all 3 responses, apply **DCYP** for Gallium-68 on factor 2 (`ReactionTime`), and explore the multi-criteria Candidate Pool:

```julia
# 1. Multi-Objective Goals
goals = [
    Dict("Type" => "Maximise", "Min" => 60.0, "Max" => 98.0, "Target" => 95.0, "Weight" => 1.5),
    Dict("Type" => "Minimise", "Min" => 0.5,  "Max" => 8.0,  "Target" => 1.0,  "Weight" => 1.0),
    Dict("Type" => "Minimise", "Min" => 0.2,  "Max" => 5.0,  "Target" => 0.5,  "Weight" => 1.0)
]

# 2. DCYP Modifier: λ = ln(2) / 67.71 on Factor 2
lambda_ga68 = log(2) / 67.71
dcyp_mod = CORE_ModifierDCYP_DDES(2, lambda_ga68, "Ga-68")

# 3. Continuous Optimisation & Candidate Pool Generation
bounds = hcat(minimum(X_mat; dims=1)', maximum(X_mat; dims=1)')
models = [model_yield, model_impur, model_colloid]

best_coords, best_score = CORE_OptimiseDesirability_DDEF(
    models, goals, bounds; 
    MaxTime=2.5, 
    ModifiersDCYP=[dcyp_mod]
)

println("\n--- Global Optimum (TOP-01*) ---")
println("  Temperature:   ", round(best_coords[1], digits=1), " °C")
println("  Reaction Time: ", round(best_coords[2], digits=1), " min (Decay-penalised)")
println("  Precursor:     ", round(best_coords[3], digits=1), " ug")
println("  Composite Desirability: ", round(best_score, digits=4))
```

### Candidate Selection

In `Gui_Lens` or batch scripts, the full portfolio is presented:

| Candidate ID | Temp (°C) | Time (min) | Precursor (μg) | Pred. Yield (%) | Pred. Impurity (%) | Pred. Colloid (%) | Desirability | Operational Rationale |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| `TOP-01*` | 74.2 | 16.8 | 38.5 | 94.6 | 1.8 | 0.6 | 0.912 | Unconstrained Global Summit |
| `TOP-02` | 75.0 | 17.0 | 40.0 | 94.8 | 1.9 | 0.5 | 0.908 | High-Density Grid Mode |
| `INP-Temperature` | 62.5 | 22.0 | 42.0 | 90.2 | 1.1 | 0.8 | 0.845 | Minimal thermal stress on peptide |
| `INP-Precursor` | 76.0 | 17.5 | 24.5 | 92.4 | 1.9 | 0.9 | 0.885 | **36% Precursor API savings** |
| `OUT-Impurity` | 68.0 | 14.0 | 36.0 | 89.8 | 0.9 | 0.7 | 0.862 | Stringent clinical purity release |

*Decision:* Given that peptide precursor is costly and supply is limited, the researcher selects **`INP-Precursor`** (`[76.0, 17.5, 24.5]`), sacrificing only $2.2\%$ yield while conserving $36\%$ of active substrate.

---

## 6. Sequential Phase Transition (ACTA and ASTM)

The chosen leader is advanced into Phase 2 using the complete two-stage **IPKT** framework: **ACTA** adapts boundaries around the leader, while **ASTM** applies affine coordinate transformation and physical clamping:

```julia
# Selected Leader Coordinates: INP-Precursor
leader_coords = [76.0, 17.5, 24.5]

# Previous Phase 1 Boundaries [Min, Mid, Max]
old_levels = [
    [30.0, 60.0, 90.0],  # Factor 1: Temperature
    [5.0,  20.0, 35.0],  # Factor 2: ReactionTime
    [10.0, 30.0, 50.0]   # Factor 3: Precursor
]

# --------------------------------------------------------------------------
# Stage 1: ACTA Boundary Adaptation (p_i evaluation, contraction c = 0.50)
# --------------------------------------------------------------------------
acta_levels = Vector{Vector{Float64}}(undef, 3)
for i in 1:3
    # FLOW_CalcACTA_DDEF(LeaderVal, OldLevels, ContractionFactor, TranslationFactor, MinLimit)
    acta_levels[i] = FLOW_CalcACTA_DDEF(leader_coords[i], old_levels[i], 0.50, 0.0, 0.0)
end

println("--- Stage 1: ACTA Adapted Factor Bounds ---")
println("Factor 1 (Temp)   Levels: ", round.(acta_levels[1], digits=1), " °C")
println("Factor 2 (Time)   Levels: ", round.(acta_levels[2], digits=1), " min")
println("Factor 3 (Precur) Levels: ", round.(acta_levels[3], digits=1), " ug")

# --------------------------------------------------------------------------
# Stage 2: ASTM Affine Transformation & Clamping (x_new = α · x_old + β)
# --------------------------------------------------------------------------
# Temperature: Thermodynamic Invariance (α = 1.0, β = 0.0)
temp_astm = [FLOW_ApplyASTM_DDEF(x, 1.0, 0.0) for x in acta_levels[1]]

# Reaction Time: Kinetic Scaling (α = 0.90 to account for rapid vessel heating, β = 0.0)
time_astm = [FLOW_ApplyASTM_DDEF(x, 0.90, 0.0) for x in acta_levels[2]]

# Precursor: Systematic Offset + Absolute Safety Clamping [10.0, 100.0] ug
prec_astm = [FLOW_ApplyASTM_DDEF(x, 1.0, 0.0) for x in acta_levels[3]]
prec_phase2 = [FLOW_ValidateASTM_DDEF(x, 10.0, 100.0)[2] for x in prec_astm]

println("\n--- Stage 2: ASTM Transformed Phase 2 Operational Space ---")
println("Phase 2 Temperature Range : [", round(temp_astm[1], digits=1), ", ", round(temp_astm[3], digits=1), "] °C")
println("Phase 2 Reaction Time Range: [", round(time_astm[1], digits=1), ", ", round(time_astm[3], digits=1), "] min")
println("Phase 2 Precursor Range    : [", round(prec_phase2[1], digits=1), ", ", round(prec_phase2[3], digits=1), "] ug")
```

The resulting refined coordinates define the operational bounds for Phase 2, transferring prior mathematical variance and the optimised leader peak into `Gui_Deck` without experimental discontinuity.
