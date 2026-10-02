# Scripting Guide

This guide covers batch execution, scripted workflows, multi-threading, and system image compilation for **DoECISORY.jl**.

---

## 1. Programmatic Workflow

Core computational functions follow the convention `[MODULE_TAG]_[PascalCaseAction]_DDEF`.

### 1.1. Script Example

```julia
using DoECISORY

# 1. Generate Design Matrix
X_coded = CORE_GenDesign_DDEF("DF14", 3; Direction=[1, -1, 1])

# 2. Map to Laboratory Units
factor_config = [
    Dict("Name" => "Temperature", "Levels" => [25.0, 50.0, 75.0]),
    Dict("Name" => "Time",        "Levels" => [10.0, 30.0, 50.0]),
    Dict("Name" => "Catalyst",    "Levels" => [0.1,  0.5,  0.9])
]
X_physical = CORE_MapLevels_DDEF(X_coded, factor_config)

# 3. Fit Regression Model
X = Matrix{Float64}(X_physical)
Y = [12.4 + 0.3*r[1] + 1.2*r[2] - 0.02*r[2]^2 for r in eachrow(X)]
model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=["Temperature", "Time", "Catalyst"])

# 4. Multi-Response Optimisation with DCYP
bounds = hcat(minimum(X; dims=1)', maximum(X; dims=1)')
goals  = [Dict("Type" => "Maximise", "Min" => 10.0, "Max" => 50.0, "Target" => 45.0, "Weight" => 1.0)]
dcyp   = CORE_ModifierDCYP_DDES(2, 0.006315, "F-18")

best_coords, best_score = CORE_OptimiseDesirability_DDEF([model], goals, bounds; ModifiersDCYP=[dcyp])

# 5. Interphase Knowledge Transfer (IPKT = ACTA + ASTM)
# Step A: ACTA domain contraction
acta_levels = FLOW_CalcACTA_DDEF(best_coords[1], [25.0, 50.0, 75.0], 0.50, 0.0, 20.0)

# Step B: ASTM affine transformation and safety validation
phase2_levels = [FLOW_ApplyASTM_DDEF(x, 1.0, 0.0) for x in acta_levels]
```

---

## 2. Multi-Threading

The high-density grid evaluation (`VISE_GridSearch_DDEF`) scales across all available CPU cores.

### 2.1. Invocation with Multiple Threads
Launch Julia with automated thread detection:

```bash
julia --threads=auto
```

Or specify a dedicated thread allocation:

```bash
julia --threads=8
```

Within Julia, verify thread availability:

```julia
using Base.Threads
println("Allocated Threads: ", nthreads())
```

When thread counts exceed 4, `VISE_GridSearch_DDEF` dynamically upgrades evaluation resolution from $21^3$ ($9,261$ coordinates) to $41^3$ ($68,921$ coordinates) without increasing execution latency.

---

## 3. System Image Compilation

To reduce Just-In-Time (JIT) latency and achieve fast startup, compile a local system image using `PackageCompiler.jl`:

### 3.1. Compilation via `system/compiler.jl`

A pre-configured compiler harness is located at `system/compiler.jl`:

```julia
using PackageCompiler

PackageCompiler.create_sysimage(
    [:DoECISORY, :Dash, :PlotlyJS, :DataFrames, :XLSX];
    sysimage_path = "system/DoECISORY_sysimage.so", # or .dll on Windows
    precompile_execution_file = "system/precompile_workload.jl"
)
```

### 3.2. Launching with Native Sysimage

On Linux / macOS:
```bash
julia -J system/DoECISORY_sysimage.so -e "using DoECISORY; run_app()"
```

On Windows (PowerShell):
```powershell
julia -J system\DoECISORY_sysimage.dll -e "using DoECISORY; run_app()"
```
