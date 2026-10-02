# DoECISORY.jl

**Design of Experiments with Computational Interactive Sequential Optimisation for Response Yield**

**DoECISORY.jl** is an open-source scientific computing library and decision-support assistant developed in Julia. It integrates classical Design of Experiments (DoE), temporal kinetic corrections, multi-objective metaheuristics, interphase knowledge transfer, and interactive diagnostic reporting into a unified, functional architecture.

---

## Core Capabilities

* **3-Factor Experimental Designs**: Matrices for 3-factor formulation spaces, including Box-Behnken (BB15), Central Composite (CD17), Taguchi (TL09), and Fractional D-Optimal (DF14).
* **Information Optimality Metrics**: Evaluation of D-, A-, G-, and I-efficiencies and design matrix condition numbers.
* **Stoichiometry and Mass Balance**: Automated mass balance audits, excipient balancing, molar ratios, and concentration consistency checks (`Lib_Mole`).
* **Temporal Kinetic Adjustments**: Pre-reaction ingredient degradation normalisation (e.g. stock holding delay, radionuclide decay, or labile precursor degradation) and post-reaction analytical latency restoration back to reference state (e.g. End of Synthesis - EOS) via `VISE_ApplyForwReveDecay_DDEF` and `MOLE_CalcRadioDecay_DDEF`.
* **Multi-Objective Optimisation and Kinetic Penalties (DCYP)**: Derringer-Suich desirability profiling with continuous and categorical criteria:
  - **Decay-Coupled Yield Penalty (DCYP)**: Universal kinetic trade-off arbitration penalising excessive reaction duration against exponential half-life decay ($t_{1/2}$, e.g. radionuclide decay or labile compound degradation).
  - **Gaussian Neighbour-Weighting Regularisation**: Smoothens multi-objective landscape ridges for stable metaheuristic and grid convergence.
* **Candidate Pool Formulation**: Generates a tiered portfolio of viable formulations rather than a single point:
  - *Absolute Leaders (`TOP-XX`)*: Highest unconstrained composite desirability.
  - *Input Minimisation (`INP-<Factor>`)*: Green chemistry and cost-saving formulations achieving $\ge 90\%$ desirability with minimal reagent consumption, reduced heating load, or shortest residence time.
  - *Output Specialisation (`OUT-<Response>`)*: Solutions prioritising critical quality attributes like purity, specific activity, or minimal by-product formation.
* **Sequential Interphase Transfer (ACTA and ASTM)**: Bridges successive experimental phases through:
  - *ACTA (Adaptive Contraction & Translation Algorithm)*: Evaluates relative position ($p_i$) to contract search boundaries ($c$) around the leader or translate them ($\delta$) upon boundary contact.
  - *ASTM (Affine Space Transformation Model)*: Applies affine scaling ($x_{\text{new}} = \alpha \cdot x_{\text{old}} + \beta$) and absolute physical clamping.
* **Statistical Diagnostics**: Seven-stage scientific analysis report featuring OLS linear and quadratic regression, ANOVA, Lack-of-Fit tests, cross-validated $Q^2$ (overfitting protection), and VIF multicollinearity screening.
* **Visualisation**: PlotlyJS 3D response surfaces, equipotential 2D contour maps with fixed-factor slicing, and IPKT interval shift charts (`Lib_Arts`).
* **Spreadsheet Data Exchange (Excel)**: Multi-sheet protocol workbooks (`.xlsx`) with formatting standards, formula preservation, and zero data loss (`Sys_Fast`).

---

## Execution Modes

DoECISORY provides two operational interfaces:

### [Graphical Interface (GUI)](interface.md)
* **Users:** Laboratory chemists, radiopharmacists, radiochemists, and formulation scientists.
* **Interface:** Browser-based interactive Dash platform (`run_app()`).
* **Workflow:** Graphical factor setup, automatic Excel workbook download, dropzone data ingestion, interactive 3D Plotly surfaces, and slider-controlled IPKT transitions without terminal coding.

### [Scripting and Batch Pipeline](scripting.md)
* **Users:** Biostatisticians, data scientists, chemical engineers, and automation specialists.
* **Interface:** Julia REPL, Jupyter/Pluto notebooks, or automated batch scripts.
* **Workflow:** Direct API dispatch, multi-threaded high-density grid evaluations (`--threads=auto`), and ahead-of-time sysimage compilation (`system/compiler.jl`).

---

## Installation

Install the package via the Julia package manager:

```julia
using Pkg
Pkg.add("DoECISORY")
```

Or clone the development branch directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/erensgol/DoECISORY.jl")
```

---

## Minimal Verification Example

Generate a standard 15-point Box-Behnken design (`"BB15"`), evaluate optimality, fit a quadratic response surface, and apply an IPKT contraction step:

```julia
using DoECISORY

# 1. Generate coded 15-run Box-Behnken design matrix
X_coded = CORE_GenDesign_DDEF("BB15", 3)

# 2. Evaluate D-efficiency
metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
println("D-Efficiency: ", round(metrics["D"], digits=2), "%")

# 3. Fit response surface model
X = Float64.(X_coded)
Y = [14.2 + 2.1*r[1] - 1.4*r[2] + 0.8*r[3]^2 for r in eachrow(X)]
model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=["Temp", "Time", "Conc"])

# 4. Predict response at the centre point [0, 0, 0]
pred = VISE_Predict_DDEF(model, [0.0, 0.0, 0.0])
println("Predicted Centre Value: ", round(pred[1], digits=2))

# 5. Interphase Knowledge Transfer (IPKT = ACTA + ASTM)
# Step A: ACTA domain contraction (c = 0.50 around leader 0.25)
acta_levels = FLOW_CalcACTA_DDEF(0.25, [-1.0, 0.0, 1.0], 0.50, 0.0, -1.0)

# Step B: ASTM affine scaling and boundary safety verification (α = 1.0, β = 0.0)
phase2_levels = [FLOW_ApplyASTM_DDEF(x, 1.0, 0.0) for x in acta_levels]
println("Adapted Phase 2 Coded Levels (IPKT): ", round.(phase2_levels, digits=3))
```

---

## Documentation Contents

```@contents
Pages = [
    "methodology.md",
    "interface.md",
    "scripting.md",
    "tutorial.md",
    "statistics.md",
    "visuals.md",
    "api.md",
    "citation.md"
]
Depth = 2
```