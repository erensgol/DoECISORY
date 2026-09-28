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

**Design of Experiments with Computational Interactive Sequential Optimization for Response Yield**

[![Julia Version](https://img.shields.io/badge/Julia-v1.10+-9558B2)](https://julialang.org)
[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows_%7C_Linux_%7C_macOS-lightgrey)]()
[![Hugging Face](https://img.shields.io/badge/%F0%9F%A4%97-Cloud_App-FFD21E)](https://erensgol-doecisory.hf.space)
[![ORCID](https://img.shields.io/badge/-0009--0000--4491--7759-A6CE39?logo=orcid&logoColor=white)](https://orcid.org/0009-0000-4491-7759)

**DoECISORY** is a Julia package and interactive web application for Design of Experiments (DoE), statistical modelling, and multi-objective optimisation. Developed for formulation science and scientific research, it supports cloud deployment, local workstation execution, and integration with the Julia REPL, Pluto.jl, and Jupyter computational environments.

> *If you use DoECISORY in your academic research, formulation development, or thesis, please [cite this repository](#citation).*

---

## Capabilities

* **Experimental Designs**: Box-Behnken, Central Composite, Taguchi, and Fractional D-Optimal matrices.
* **Optimality Metrics**: Evaluation of D-, A-, G-, and I-efficiencies and matrix condition numbers.
* **Statistical Modelling**: Linear and quadratic OLS regression with AIC, adjusted $R^2$, and ANOVA diagnostics.
* **Formulation & Decay**: Mass balance validation, physical unit checks, and radioactive decay corrections.
* **Multi-Objective Optimisation**: Derringer-Suich desirability profiling via global metaheuristic algorithms.
* **Scientific Reporting**: Multi-sheet Excel workbooks (`.xlsx`) and interactive Plotly response surfaces.

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
git clone https://github.com/erensgol/DoECISORY.git
cd DoECISORY
```

* **Option 2A: Interactive Gateway (`Run_DoE.bat`)**  
  Execute `Run_DoE.bat` in the project root to open the startup menu:
  - **Standard Mode**: Default execution profile. Utilises a precompiled system image (`build/sysimage.dll`) if present, or proceeds with standard JIT compilation.
  - **Developer Mode**: Development environment for code modification without restarting the session.
  - **Clean JIT Mode**: JIT execution with basic compiler optimisations (`-O1`), bypassing any system image.
  - **Build Sysimage**: Compiles a local system image via `build/compiler.jl` to reduce warmup time.
  - **Run Test Suite**: Executes the automated test suite (100 verifications) directly from the gateway menu.

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
Pkg.add("DoECISORY")
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
  Spawns the server as an independent child process, keeping the active Julia REPL prompt or notebook cell unblocked:
  ```julia
  run_app()
  ```

#### Option 3B: Headless Algorithmic Execution (Julia REPL, Scripts & Notebooks)

All mathematical, stoichiometric, and statistical routines in DoECISORY can be executed directly without launching the graphical user interface. This enables interactive computational workflows within the **Julia REPL**, standalone `.jl` scripts, **Pluto.jl**, and **Jupyter Notebooks**:

```julia
using DoECISORY

# 1. Generate an experimental design matrix (e.g. Box-Behnken, 15 runs, 3 factors)
X_coded = CORE_GenDesign_DDEF("BB15", 3)

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
    println("Predicted Center Response: ", round(pred[1], digits=2))
end
```

---

## Module Structure

The package is organised into functional submodules:

| Module | Purpose |
| :--- | :--- |
| **DoECISORY** | Root module, public API exports, and application launcher (`run_app`). |
| **Lib_Core** | Experimental design generation, level mapping, and D-A-G-I optimality metrics. |
| **Lib_Mole** | Stoichiometric checks, molar balances, and radioactive decay equations. |
| **Lib_Vise** | OLS regression, AIC model selection, VIF collinearity, and sensitivity analysis. |
| **Lib_Arts** | PlotlyJS visualisation (Pareto charts, 2D/3D response surfaces, contour slices). |
| **Sys_Fast** | Excel (XLSX) I/O, logging, and transient file management. |
| **Sys_Flow** | Multi-phase search-space transitions (Zoom & Shift) and candidate tracking. |
| **Gui_Base** | Shared Dash-Bootstrap components and theme styling tokens. |
| **Gui_Deck** | Design phase UI, ingredient tables, and recipe protocol exports. |
| **Gui_Lens** | Analysis phase UI, desirability tuning, and report generation. |

---

## Testing

To run the automated test suite (100 verifications):

```bash
julia --project=. -e "using Pkg; Pkg.test()"
```

---

## License

This project is licensed under the **Mozilla Public License 2.0 (MPL-2.0)**.

---

## Citation

If you use **DoECISORY** in your research, thesis, academic publications, or industrial workflows, please cite it using the following format:

```bibtex
@software{Gol_DoECISORY_2026,
  author    = {Göl, Eren Selim},
  title     = {{DoECISORY.jl: Design of Experiments with Computational Interactive Sequential Optimization for Response Yield}},
  year      = {2026},
  version   = {1.0.0},
  publisher = {Zenodo},
  doi       = {10.5281/zenodo.PLACEHOLDER},
  url       = {https://github.com/erensgol/DoECISORY}
}
```

---

## Author & Contact

**Eren Selim GÖL, MPharm**  
Radiopharmacy Researcher | Lead Software Architect & Developer  
* Department of Radiopharmacy, Faculty of Pharmacy, Hacettepe University  
* **ORCID**: [0009-0000-4491-7759](https://orcid.org/0009-0000-4491-7759)  
* [linkedin.com/in/erensgol](https://www.linkedin.com/in/erensgol)
