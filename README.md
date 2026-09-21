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
[![Platform](https://img.shields.io/badge/Platform-Windows_%7C_Linux_%7C_macOS-lightgrey)]()

**DoECISORY** is a Julia package and interactive web application for Design of Experiments (DoE), statistical modeling, and multi-objective optimization. Developed at **Hacettepe University, Department of Radiopharmacy**, it can be used either as a standalone Julia library (in scripts or Jupyter Notebooks) or through its browser interface.

---

## Capabilities

* **Design Generation**: Box-Behnken (BB15), Central Composite (CD17), Taguchi (TL09), and Fractional D-Optimal (DF14).
* **Optimality Metrics**: Calculation of D-, A-, G-, and I-efficiency metrics, as well as matrix condition numbers.
* **Regression & Model Selection**: Ordinary Least Squares (OLS) regression (linear and quadratic), evaluated via AIC, adjusted $R^2$, and PRESS $Q^2$.
* **Stoichiometry & Decay Correction**: Formulation mass balance, unit validation, and radioisotope radioactive decay adjustments (F-18, Ga-68, Lu-177, Ac-225).
* **Optimization**: Multi-response Derringer-Suich desirability functions solved via BlackBoxOptim.
* **Outputs**: Formatted multi-sheet Excel reports (`.xlsx`) and Plotly response surface plots.

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
👉 **[https://erensgol-doecisory.hf.space](https://erensgol-doecisory.hf.space)**

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

## Author & Academic Affiliation

**Pharmacist Eren Selim GÖL**  
*Lead Software Architect & Julia Developer*  
Hacettepe University, Faculty of Pharmacy, Department of Radiopharmacy  
Ankara, Türkiye  
[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?style=flat&logo=linkedin)](https://www.linkedin.com/in/erensgol)
