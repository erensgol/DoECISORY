---
title: DoECISORY
emoji: 🧪
colorFrom: yellow
colorTo: purple
sdk: docker
pinned: false
license: mpl-2.0
short_description: DoE with Computational Interactive SeqOpt for Response Yield
---

# DoECISORY.jl

**Design of Experiments with Computational Interactive Sequential Optimisation for Response Yield**

[![CI](https://github.com/erensgol/DoECISORY.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/erensgol/DoECISORY.jl/actions/workflows/CI.yml)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://erensgol.github.io/DoECISORY.jl/dev/)
[![codecov](https://codecov.io/gh/erensgol/DoECISORY.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/erensgol/DoECISORY.jl)
[![Julia Version](https://img.shields.io/badge/Julia-v1.10+-9558B2)](https://julialang.org)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](LICENSE)
[![Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97-Cloud_App-FFD21E)](https://erensgol-doecisory.hf.space)
[![ORCID](https://img.shields.io/badge/-0009--0000--4491--7759-A6CE39?logo=orcid&logoColor=white)](https://orcid.org/0009-0000-4491-7759)

**DoECISORY** is a Julia package and interactive web application for Design of Experiments (DoE), statistical modelling, and multi-objective optimisation. Developed for formulation science and scientific research, it supports cloud deployment, local workstation execution, and integration with the Julia REPL, Pluto.jl, and Jupyter environments.

> *If you use DoECISORY in your research, please [cite this repository](#citation).*

---

## Capabilities

* **3-Factor Experimental Designs**: Specialised matrices for 3-factor formulation spaces, including Box-Behnken (BB15), Central Composite (CD17), Taguchi (TL09), and Fractional D-Optimal (DF14).
* **Optimality Metrics**: Evaluation of D-, A-, G-, and I-efficiencies and design matrix condition numbers.
* **Statistical Modelling & Diagnostics**: Linear and quadratic OLS regression with AIC, adjusted $R^2$, VIF multicollinearity, and ANOVA diagnostics.
* **Sequential Multi-Phase Optimisation**: Search-space transitions (ACTA&ASTM) tracking leader formulation conditions across stages.
* **Stoichiometry & Radiochemical Kinetics**: Mass balance audits, physical unit checks, and decay corrections (DCYP incubation penalties, FORW/REVE decay alignment).
* **Multi-Objective Optimisation**: Derringer-Suich desirability profiling with continuous and categorical objective functions via global metaheuristics.
* **Scientific Reporting & Visualisation**: Automated multi-sheet Excel workbooks (`.xlsx`), interactive Plotly response surfaces, and project archives (`.zip`).

---

## Architecture & Scientific Workflow

DoECISORY follows an iterative three-stage experimental workflow:

1. **Phase 1: Formulation Design (`Gui_Deck`)**  
   * **Ingredient Specification & Audit**: Input active ingredients and excipients; automatic stoichiometric mass balancing and physical unit auditing (`Lib_Mole`).
   * **Design Selection**: Generate 3-factor coded matrices (`BB15`, `CD17`, `TL09`, `DF14`) and evaluate D-, A-, G-, and I-optimality metrics (`Lib_Core`).
   * **Protocol Generation**: Export laboratory execution workbooks (`.xlsx`) with automated randomised run orders (`Sys_Fast`).

2. **Phase 2: Statistical Modelling & Analytics (`Gui_Lens`)**  
   * **OLS Regression & ANOVA**: Import experimental responses, fit linear or quadratic models, compute $R^2$, AIC, VIF multicollinearity, and ANOVA diagnostics (`Lib_Vise`).
   * **Multi-Objective Desirability**: Optimise competing responses simultaneously using Derringer-Suich desirability profiling (`Lib_Core`).
   * **Visual Analytics & Reporting**: Generate 2D contour and 3D response surface plots (`Lib_Arts`) and export scientific report workbooks (`.xlsx`).

3. **Phase 3: Sequential Space Transitions (`Sys_Flow`)**  
   * **Adaptive Navigation (ACTA&ASTM)**: Identify optimal leader formulation coordinates and perform automated search-space contraction and translation to define factor boundaries for subsequent iterative phases.

---

## Getting Started & Usage Workflows

DoECISORY supports three distinct execution pathways depending on operational and research requirements:

---

### Pathway 1: Cloud Deployment (Hugging Face Spaces)

DoECISORY is deployed as a containerised service on Hugging Face Spaces, providing access to the complete computational platform and graphical interface without requiring local Julia installation, dependency resolution, or local storage.

Select the access point according to your operational goal:

* **[Launch Web Application](https://erensgol-doecisory.hf.space)** *(Primary Workspace)*  
  Opens the DoECISORY interface directly in your browser without external platform headers.

* **[Hugging Face Space Portal](https://huggingface.co/spaces/erensgol/DoECISORY)** *(Container Management & Wake-up)*  
  Use if the cloud container has entered sleep mode to trigger a wake-up restart.

---

### Pathway 2: Local Repository Deployment

For users working directly with the source code:

```bash
git clone https://github.com/erensgol/DoECISORY.jl.git
cd DoECISORY.jl
```

* **Option 2A: Interactive Gateway (`Run_DoE.bat`)**  
  Execute `Run_DoE.bat` in the project root to open the startup menu:
  - **Standard Mode [1]**: Default execution profile. Utilises a precompiled system image (`build/sysimage.dll` or `sysimage.so`) if present, or proceeds with standard JIT compilation.
  - **Developer Mode [2]**: Environment for code modification without restarting the session (via Revise.jl)
  - **Clean JIT Mode [3]**: JIT execution with basic compiler optimisations (`-O1`), bypassing any system image.
  - **Build Sysimage [4]**: Compiles a local system image via `build/compiler.jl` to eliminate JIT latency.
  - **Run Test Suite [5]**: Executes the automated test suite (100 verifications) directly from the gateway menu.

* **Sysimage Compilation Workflow**  
  Install `PackageCompiler` once in your global Julia environment (`@v#.#`):
  ```bash
  julia -e "using Pkg; Pkg.activate(); Pkg.add(\"PackageCompiler\")"
  ```
  Then build the precompiled sysimage via command-line or `Run_DoE.bat`:
  ```bash
  julia --project=. build/compiler.jl
  ```
  Once compiled, the application launches with prewarmed Plotly and Dash caches.

* **Option 2B: Command-Line Execution**  
  Launch directly from the terminal with automatic multi-threading:
  ```bash
  julia --threads=auto --project=. app.jl
  ```
  The server outputs operational logs to the terminal and serves the interface locally at `http://127.0.0.1:8060`.

---

### Pathway 3: Julia Package Ecosystem (`Pkg`)

For integration into existing Julia workflows or computational pipelines:

```julia
using Pkg
# Install from GitHub repository:
Pkg.add(url="https://github.com/erensgol/DoECISORY.jl")
# Or once published to the General Registry:
# Pkg.add("DoECISORY")

using DoECISORY
```

#### Option 3A: Launching the Web Interface from Julia

* **Interactive Terminal Mode (Synchronous)**  
  Launches the server and streams runtime logs directly to the console:
  ```julia
  run_app(wait=true)
  ```
  *(Press `Ctrl + C` in the console to terminate the server).*

* **Asynchronous Process Mode (Non-blocking)**  
  Spawns the server as an independent child process, keeping the active REPL prompt unblocked:
  ```julia
  run_app()
  ```

#### Option 3B: Headless Algorithmic Execution (Julia REPL, Scripts & Notebooks)

Mathematical, stoichiometric, and statistical routines in DoECISORY can be executed directly without launching the graphical user interface. This enables interactive computational workflows within the **Julia REPL**, standalone `.jl` scripts, **Pluto.jl**, and **Jupyter Notebooks**:

```julia
using DoECISORY

# 1. Generate a 3-factor experimental design matrix (e.g. Box-Behnken, 15 runs)
X_coded = CORE_GenDesign_DDEF("BB15")

# 2. Compute D-, A-, G-, and I-optimality metrics and condition number
metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
println("D-Efficiency: ", round(metrics["D"], digits=4))
println("Condition No: ", round(metrics["Condition"], digits=2))

# 3. Fit a quadratic OLS regression model
X = Float64.(X_coded)
Y = [2.5 + 1.2*x[1] - 0.8*x[2] + 0.5*x[3]^2 for x in eachrow(X)]
model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=["Temp", "Time", "Conc"])
println("R²: ", round(model["R2"], digits=4))

# 4. Predict responses (interactive in REPL, or wrapped in begin...end in Pluto.jl)
begin
    pred = VISE_Predict_DDEF(model, [0.0, 0.0, 0.0])
    println("Predicted Centre Response: ", round(pred[1], digits=2))
end
```

> **Design Space Scope:** DoECISORY is designed for 3-factor experimental and formulation studies. Matrix generators (`BB15`, `CD17`, `TL09`, `DF14`), optimality calculations, and response surface models operate on 3 continuous factors.

---

## Module Structure

The package is organised into functional submodules following strict architectural separation of concerns:

| Module / Component | Purpose |
| :--- | :--- |
| **DoECISORY** | Root module, public API exports, and application launcher (`run_app`). |
| **app.jl** | Primary application entry point, routing orchestrator, and server bootstrapper. |
| **Lib_Core** | Mathematical algorithms, experimental design matrices, and D-A-G-I optimality metrics. |
| **Lib_Mole** | Chemistry, stoichiometry, mass balance validation, and radioactive decay equations. |
| **Lib_Vise** | Statistics (OLS regression, AIC selection, VIF multicollinearity, HypothesisTests). |
| **Lib_Arts** | Visualisation suite (PlotlyJS, 2D/3D response surfaces and contours). |
| **Sys_Fast** | System utilities, Excel (XLSX) I/O, transient storage, and cross-module sync. |
| **Sys_Flow** | Workflow orchestration, multi-phase search-space transitions, and candidate tracking. |
| **Gui_Base** | Shared Dash-Bootstrap UI components, common layouts, and design tokens. |
| **Gui_Deck** | Design phase UI, ingredient tables, and Protocol Templates management. |
| **Gui_Lens** | Analysis phase UI, Criteria Profiles, desirability tuning, and scientific report exports. |

---

## Testing

To run the automated test suite (100 verifications):

```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

To run the test suite with comprehensive line-by-line code coverage analysis (identical to Gateway Mode [5]):

```bash
julia --project=. test/coverage.jl
```

---

## Licence

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

---

## Citation

If you use DoECISORY in your research, please cite:

```bibtex
@software{Gol_DoECISORY_2026,
  author       = {Göl, Eren Selim},
  title        = {{DoECISORY.jl: Design of Experiments with Computational Interactive Sequential Optimisation for Response Yield}},
  year         = {2026},
  version      = {0.1.0},
  url          = {https://github.com/erensgol/DoECISORY.jl}
}
```

---

## Author & Contact

**Eren Selim GÖL, MPharm**  
Radiopharmacy Researcher | Lead Software Architect & Developer  
* Department of Radiopharmacy, Faculty of Pharmacy, Hacettepe University  
* **ORCID**: [0009-0000-4491-7759](https://orcid.org/0009-0000-4491-7759)  
* [linkedin.com/in/erensgol](https://www.linkedin.com/in/erensgol)
