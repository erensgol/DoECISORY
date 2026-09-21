---
title: DoECISORY
emoji: 🧪
colorFrom: yellow
colorTo: purple
sdk: docker
pinned: false
license: agpl-3.0
short_description: DoE with Computational Interactive SeqOpt for Response Yield
---

# DoECISORY.jl

**Design of Experiments with Computational Interactive Sequential Optimization for Response Yield**

[![Julia Version](https://img.shields.io/badge/Julia-1.10%2B-9558B2?style=flat&logo=julia)](https://julialang.org)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Hugging Face Spaces](https://img.shields.io/badge/%F0%9F%A4%97%20Spaces-Live_Demo-yellow)](https://erensgol-doecisory.hf.space)
[![ORCID](https://img.shields.io/badge/ORCID-0009--0000--4491--7759-A6CE39?style=flat&logo=orcid&logoColor=white)](https://orcid.org/0009-0000-4491-7759)
[![Platform](https://img.shields.io/badge/Platform-Windows_%7C_Linux_%7C_macOS-lightgrey)]()

**DoECISORY** is a Julia package and interactive web application for Design of Experiments (DoE), statistical modeling, and multi-objective optimization. Designed for advanced formulation science and scientific research, it can be used either as a standalone Julia library (in scripts or Jupyter Notebooks) or through its browser interface.

---

## Capabilities

* **Experimental Designs**: Box-Behnken, Central Composite, Taguchi, and Fractional D-Optimal matrices.
* **Optimality Metrics**: Evaluation of D-, A-, G-, and I-efficiencies and matrix condition numbers.
* **Statistical Modelling**: Linear and quadratic OLS regression with AIC, adjusted $R^2$, and ANOVA diagnostics.
* **Formulation & Decay**: Mass balance validation, physical unit checks, and radioactive decay corrections.
* **Multi-Objective Optimisation**: Derringer-Suich desirability profiling via global metaheuristic algorithms.
* **Scientific Reporting**: Multi-sheet Excel workbooks (`.xlsx`) and interactive Plotly response surfaces.

---

## Getting Started

### 1. Using as a Julia Package (Headless / Jupyter)

Install via Julia's package manager:

```julia
using Pkg
Pkg.add(url="https://github.com/erensgol/DoECISORY.git")
```

Or activate from a local clone:

```julia
using Pkg
Pkg.activate(".")
using DoECISORY
```

#### Example Usage

```julia
using DoECISORY

# 1. Generate a coded Box-Behnken design (15 runs, 3 factors)
X_coded = CORE_GenDesign_DDEF("BB15", 3)

# 2. Calculate D-A-G-I optimality metrics
metrics = CORE_CalcDesignMetrics_DDEF(Float64.(X_coded), "quadratic")
println("D-Efficiency: ", round(metrics["D"], digits=4))
println("Condition No: ", round(metrics["Condition"], digits=2))

# 3. Fit a quadratic OLS model
X = Float64.(X_coded)
Y = [2.5 + 1.2*x[1] - 0.8*x[2] + 0.5*x[3]^2 for x in eachrow(X)]
model = VISE_Regress_DDEF(X, Y, "quadratic"; InNames=["Temp", "Time", "Conc"])
println("R²: ", round(model["R2"], digits=4), " | Adj-R²: ", round(model["R2_Adj"], digits=4))

# 4. Optional: open the interactive web UI from REPL or Jupyter
run_app()
```

---

### 2. Using the Web Interface

#### Online (Hugging Face Spaces)
The web interface is deployed and accessible at:  
**[https://erensgol-doecisory.hf.space](https://erensgol-doecisory.hf.space)**

#### Running Locally
To run the web app on your own machine:

1. Clone the repository:
   ```bash
   git clone https://github.com/erensgol/DoECISORY.git
   cd DoECISORY
   ```

2. Start the server:
   * **Windows**: Double-click `Run_DoE.bat`
   * **Terminal (macOS / Linux / Windows)**:
     ```bash
     julia --project=. app.jl
     ```
   The browser will open at `http://127.0.0.1:8060`.

---

## Module Structure

The package is organised into functional submodules:

| Module | Purpose |
| :--- | :--- |
| **DoECISORY** | Root module, public API exports, and application launcher (`run_app`). |
| **Lib_Core** | Experimental design generation, level mapping, and D-A-G-I optimality metrics. |
| **Lib_Mole** | Stoichiometric checks, molar balances, and radioactive decay equations. |
| **Lib_Vise** | OLS regression, AIC model selection, VIF collinearity, and sensitivity analysis. |
| **Lib_Arts** | PlotlyJS visualization (Pareto charts, 2D/3D response surfaces, contour slices). |
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

This project is licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**.

---

## Citation

* **Author**: Pharmacist Eren Selim GÖL
* **ORCID**: [0009-0000-4491-7759](https://orcid.org/0009-0000-4491-7759)

Please cite this work if you use **DoECISORY** in your research, thesis, academic publications, or industrial workflows.

The primary peer-reviewed scientific research article describing the methodology, algorithm design, and validation is currently in preparation.

> *Note: This section will be updated with the official journal publication, volume, and DOI as soon as the manuscript is published.*

---

## Author & Contact

**Pharmacist Eren Selim GÖL**  
Lead Software Architect & Developer<br>
[linkedin.com/in/erensgol](https://www.linkedin.com/in/erensgol)
