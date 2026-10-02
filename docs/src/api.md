# Modular API Reference

To bridge the gap between modular software architecture and physical laboratory execution, this reference is organised into two complementary views:
1. **[The Experimental Pipeline (Chronological Workflow Map)](#the-experimental-pipeline-chronological-workflow-map):** A step-by-step guide matching standard laboratory protocol sequences.
2. **[Modular Architecture Reference](#modular-architecture-reference):** Complete function signatures, parameter descriptions, and docstrings grouped by library namespace (`Lib_Core`, `Lib_Mole`, `Lib_Vise`, `Lib_Arts`, `Sys_Flow`, `Sys_Fast`).

---

## The Experimental Pipeline (Chronological Workflow Map)

```
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 1: Formulation & Stoichiometric Audit      (Lib_Mole)  │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 2: Experimental Design & Optimality        (Lib_Core)  │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 3: Data Ingestion, Decay & Modelling       (Lib_Vise)  │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 4: Multi-Objective Optimisation & Pools    (Lib_Core)  │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 5: Interphase Knowledge Transfer (IPKT)    (Sys_Flow)  │
  │          [Phase 1 Leader  ──►  Phase 2 Search Bounds]       │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ Stage 6: Scientific Reporting & Visualisation    (Lib_Arts)  │
  └─────────────────────────────────────────────────────────────┘
```

### Stage 1: Formulation Specification & Stoichiometric Auditing
*Pre-experimental verification of recipe mass balance, molar ratios, and concentration consistency.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`MOLE_ParseTable_DDEF`](@ref) | Component Parsing | Extracts active reagents (`VAR`), fixed salts (`FIX`), and diluents (`FILL`) from input dictionaries or tables. |
| [`MOLE_QuickAudit_DDEF`](@ref) | Mass Conservation Audit | Verifies that solute masses and diluent volumes sum strictly to the target concentration and total volume. |
| [`MOLE_CalcMass_DDEF`](@ref) | Mass Calculation | Computes mass from volume, concentration, and molecular weight. |
| [`MOLE_ProcessDesign_DDEF`](@ref) | Protocol Synthesis | Computes dynamic ingredient dispensing volumes for every single run across the experimental design matrix. |
| [`MOLE_ValidatePhysicalUnit_DDEF`](@ref) | Unit Verification | Confirms validity and compatibility of physical laboratory units (e.g. `mg`, `ug`, `mL`, `uL`, `mM`). |

---

### Stage 2: Experimental Design Generation & Information Optimality
*Constructing coded matrices, mapping physical laboratory units, and evaluating experimental efficiency.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`CORE_GenDesign_DDEF`](@ref) | Matrix Generator | Generates 3-factor coded matrices for Box-Behnken (`"BB15"`), Central Composite (`"CD17"`), Taguchi (`"TL09"`), or Fractional D-Optimal (`"DF14"`). |
| [`CORE_CalcDesignMetrics_DDEF`](@ref) | Optimality Diagnostics | Evaluates D-, A-, G-, and I-efficiencies and condition numbers $\kappa(X^T X)$ for linear, interaction, or quadratic models. |
| [`CORE_MapLevels_DDEF`](@ref) | Coordinate Mapping | Maps dimensionless coded levels $[-1, 0, 1]$ to physical equipment setpoints and experimental ranges. |
| [`CORE_CodeMatrix_DDEF`](@ref) | Level Normalisation | Transforms raw physical laboratory values back to dimensionless coded coordinates for orthogonal regression. |
| [`CORE_ValidateDesign_DDEF`](@ref) | Geometry Validation | Verifies matrix rank, balance, degree-of-freedom adequacy, and absence of degenerate rows. |

---

### Stage 3: Experimental Data Ingestion & Statistical Diagnostics
*Correcting pre/post latency delays, fitting response surfaces, ANOVA, and cross-validation.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`VISE_ApplyForwReveDecay_DDEF`](@ref) | Latency Normalisation | Corrects preparation delays ($\Delta t_{\text{forw}}$) and analytical delays ($\Delta t_{\text{reve}}$) using first-order rate kinetics. |
| [`MOLE_CalcRadioDecay_DDEF`](@ref) | Kinetic Decay Engine | Computes forward degradation ($\exp(-\lambda t)$) or reverse reference restoration ($\exp(+\lambda t)$). |
| [`VISE_Regress_DDEF`](@ref) | Response Surface Fitter | Fits Ordinary Least Squares (OLS) linear, 2-factor interaction, or full quadratic response surfaces. |
| [`VISE_SelectBestModel_DDEF`](@ref) | Parsimonious Model Selection | Evaluates AICc, BIC, and adjusted $R^2$ to select the most robust model hierarchy without overfitting. |
| [`VISE_GenerateAnovaTable_DDEF`](@ref) | ANOVA & Hypothesis Testing | Computes Sequential and Adjusted Sum of Squares, mean squares, $F$-statistics, and $p$-values. |
| [`VISE_LackOfFit_DDEF`](@ref) | Model Adequacy Diagnostic | Partitions residual sum of squares into Pure Error (replicates) and Lack of Fit. |
| [`VISE_CrossValidate_DDEF`](@ref) | Predictive Power Diagnostic | Evaluates Leave-One-Out cross-validated $Q^2$ and PRESS statistic to protect against model overparameterisation. |
| [`VISE_CalcVIF_DDEF`](@ref) | Multicollinearity Audit | Computes Variance Inflation Factors (VIF) to detect collinear distortions among predictor terms. |

---

### Stage 4: Multi-Objective Optimisation & Candidate Pool Generation
*Arbitrating competing quality targets, applying kinetic trade-off penalties, and isolating leader portfolios.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`CORE_OptimiseDesirability_DDEF`](@ref) | Continuous Metaheuristic | Solves multi-response Derringer-Suich desirability using `BlackBoxOptim` with optional DCYP kinetic penalty. |
| [`VISE_GridSearch_DDEF`](@ref) | Deterministic Grid Evaluation | Evaluates regularised composite desirability across $9,261$ to $68,921$ nodes with multi-threaded parallel execution. |
| [`CORE_ApplyDCYP_DDEF`](@ref) | Kinetic Penalty Operator | Penalises composite desirability $D$ against duration: $D_{\text{adj}} = D \cdot \exp(-\lambda \Delta t)$. |
| [`FLOW_GetCandidates_DDEF`](@ref) | Candidate Pool Extraction | Extracts Absolute Leaders (`TOP-01`, `TOP-02`), Input Minimisation (`INP-<Factor>`), and Output Specialisation (`OUT-<Response>`). |
| [`FLOW_AskLeader_DDEF`](@ref) | Interactive Leader Selection | Queries or selects a specific leader strategy from the candidate pool for interphase advancement. |

---

### Stage 5: Interphase Knowledge Transfer (Phase 1 → Phase 2 Transition)
*Bridging sequential experimental phases, contracting search boundaries, and transferring historical variance.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`FLOW_CalcACTA_DDEF`](@ref) | Boundary Adaptation (ACTA) | Computes contracted or translated factor boundaries $[L^{\text{new}}, U^{\text{new}}]$ around the selected leader. |
| [`FLOW_ApplyACTA_DDEF`](@ref) | Domain Contracting Operator | Directly generates new continuous factor bounds using contraction ratio $c$ and translation offset $\delta$. |
| [`FLOW_ApplyASTM_DDEF`](@ref) | Affine Mapping (ASTM) | Scales and shifts physical factor boundaries ($x' = \alpha x + \beta$) for equipment migration or volume scaling. |
| [`FLOW_ValidateASTM_DDEF`](@ref) | Absolute Boundary Clamping | Enforces hard thermodynamic, physical, and safety boundaries $[L^{\text{abs}}, U^{\text{abs}}]$ onto adapted levels. |
| [`FLOW_BuildIPKT_DDEF`](@ref) | Master Transfer Protocol | Builds the unified IPKT transition payload transferring active factors, fixed settings, and response targets from Phase 1 to Phase 2. |

---

### Stage 6: Scientific Reporting, Visualisation & Spreadsheet I/O
*Generating academic dossiers, interactive 3D response surfaces, and lossless Excel protocol sheets.*

| Function | Primary Role | Laboratory Action |
| :--- | :--- | :--- |
| [`VISE_GenerateScientificReport_DDEF`](@ref) | Academic Dossier Generator | Compiles a 7-stage interpreted scientific report ready for publication or regulatory filing. |
| [`ARTS_RenderSurface_DDEF`](@ref) | 3D Response Surface | Renders interactive Plotly 3D response surfaces with Viridis topography and optimal coordinate markers. |
| [`ARTS_RenderContour_DDEF`](@ref) | 2D Equipotential Contours | Plots 2D contour projections with fixed-factor slicing. |
| [`ARTS_RenderPareto_DDEF`](@ref) | Pareto Effect Chart | Displays standardised model coefficients sorted by statistical significance. |
| [`ARTS_RenderResidualsVsPred_DDEF`](@ref) | Diagnostic Residual Plot | Visualises studentised residuals versus fitted values to diagnose homoscedasticity. |
| [`FAST_SafeExcelWrite_DDEF`](@ref) | Protocol Export | Writes multi-tab formatted Excel workbooks preserving cell types, styles, and formulas. |
| [`FAST_ReadExcel_DDEF`](@ref) | Protocol Ingestion | Safely reads completed laboratory spreadsheets into DataFrames with strict type casting. |

---

## Modular Architecture Reference

The sections below document each module's internal symbols and types:

### Application Launcher

```@docs
APP_Launch_DDEF
run_app
```

---

## Experimental Design & Optimality (`Lib_Core`)

```@docs
CORE_GenDesign_DDEF
CORE_GenerateMatrix_DDEF
CORE_MapLevels_DDEF
CORE_CodeMatrix_DDEF
CORE_ExpandModelMatrix_DDEF
CORE_D_Efficiency_DDEF
CORE_CalcDesignMetrics_DDEF
CORE_OptimiseDesirability_DDEF
CORE_CalcDesirability_DDEF
CORE_ExtractGoal_DDEF
CORE_ValidateDesign_DDEF
CORE_ExtractLeader_DDEF
CORE_ModifierDCYP_DDES
CORE_ApplyDCYP_DDEF
```

---

## Stoichiometry & Mass Conservation (`Lib_Mole`)

```@docs
MOLE_ParseTable_DDEF
MOLE_QuickAudit_DDEF
MOLE_CalcMass_DDEF
MOLE_ApproxEq_DDEF
MOLE_ValidatePhysicalUnit_DDEF
MOLE_AuditMatrix_DDEF
MOLE_AuditBatch_DDEF
MOLE_ValidateDesignFeasibility_DDEF
MOLE_CalcRadioDecay_DDEF
MOLE_ProcessDesign_DDEF
MOLE_GetPercentageEquivalent_DDEF
MOLE_IsTimeUnit_DDEF
MOLE_ConvertTimeToMinutes_DDEF
```

---

## Statistical Modelling & ANOVA (`Lib_Vise`)

```@docs
VISE_Regress_DDEF
VISE_SelectBestModel_DDEF
VISE_Predict_DDEF
VISE_CrossValidate_DDEF
VISE_CalcMetrics_DDEF
VISE_GenerateAnovaTable_DDEF
VISE_LackOfFit_DDEF
VISE_CalcVIF_DDEF
VISE_PerformNormalityTest_DDEF
VISE_GridSearch_DDEF
VISE_SensitivityAnalysis_DDEF
VISE_GenerateScientificReport_DDEF
VISE_ExportToExcel_DDEF
VISE_ApplyForwReveDecay_DDEF
VISE_ExtractDCYP_DDEF
VISE_Execute_DDEF
VISE_GetTermNames_DDEF
VISE_ExpandDesign_DDEF
```

---

## Response Surface Visualisation (`Lib_Arts`)

```@docs
ARTS_RenderSurface_DDEF
ARTS_RenderContour_DDEF
ARTS_RenderSlice_DDEF
ARTS_RenderTrend_DDEF
ARTS_RenderPareto_DDEF
ARTS_RenderFit_DDEF
ARTS_RenderQQPlot_DDEF
ARTS_RenderResidualsVsPred_DDEF
ARTS_RenderSensitivityPlot_DDEF
ARTS_RenderSpace_DDEF
ARTS_RenderOptimalZone_DDEF
ARTS_RenderCandidates_DDEF
ARTS_RenderInteractionMatrix_DDEF
ARTS_Render_DDEF
```

---

## Workflow Transitions (`Sys_Flow`)

```@docs
FLOW_ApplyACTA_DDEF
FLOW_CalcACTA_DDEF
FLOW_ApplyASTM_DDEF
FLOW_ValidateASTM_DDEF
FLOW_AskLeader_DDEF
FLOW_BuildIPKT_DDEF
FLOW_CommitIPKT_DDEF
FLOW_GetCandidates_DDEF
FLOW_WriteLeaders_DDEF
FLOW_RenderIPKT_DDEF
```

---

## File Exchange & System Utilities (`Sys_Fast`)

```@docs
FAST_ReadExcel_DDEF
FAST_SafeExcelWrite_DDEF
FAST_InitialiseMaster_DDEF
FAST_GenerateSmartName_DDEF
FAST_SafeNum_DDEF
FAST_Log_DDEF
FAST_Data_DDEC
```
