# Graphical Interface Guide

This guide provides an operational manual for using **DoECISORY.jl** via its interactive browser interface. 

All steps are managed through input forms, visual controls, and Microsoft Excel workbooks without requiring command-line interaction.

---

## 1. Application Startup

From a Julia environment or terminal:

```julia
using DoECISORY
run_app()
```

Your default web browser will open the application at `http://127.0.0.1:8060`.

---

## 2. Experimental Design (Deck)

The **Deck** workspace manages formulation setup, mass balance auditing, and experimental matrix generation:

```
  [1. Define Factors] ───► Enter Factor Names, Physical Units, and [Min, Mid, Max] Levels
            │
  [2. Select Design]  ───► Choose Design Geometry (BB15, CD17, TL09, or DF14 Directional)
            │
  [3. Recipe Audit]   ───► Specify Active Precursor, Buffer, Excipients & Run Stoichiometric Check
            │
  [4. Export Excel]   ───► Click "Generate & Download Protocol Workbook (.xlsx)"
```

### 2.1. Defining Ingredients & Stoichiometry
1. In the **Formulation Configuration** card, input each reagent:
   * **Active Precursor (`VAR`):** Continuous variables subject to experimental variation.
   * **Fixed Salts/Buffers (`FIX`):** Constant formulation components.
   * **Diluent/Filler (`FILL`):** Solvent or carrier adjusted to maintain a constant total volume.
2. If working with short-lived radionuclides (e.g. $^{18}\text{F}$, $^{68}\text{Ga}$), toggle **Is Radioactive** and enter the physical half-life.
3. Click **Audit Mass Balance** to verify that concentration and total volume constraints are strictly satisfied.

### 2.2. Generating the Protocol Sheet
1. Select your target design geometry (e.g. `DF14 Directional D-Optimal`).
2. Click **Download Protocol Workbook**. An Excel file (`DoECISORY_Protocol.xlsx`) is downloaded containing pre-formatted, colour-coded worksheets ready for benchtop execution.

---

## 3. Data Analysis and Modelling (Lens)

Once laboratory runs are performed and analytical results obtained:

```
  [1. Upload Results] ───► Drag and drop the completed Excel workbook into the Lens Dropzone
            │
  [2. Set Objectives] ───► Define Min/Max targets, enable DCYP time-decay penalty if needed  
            │
  [3. View Report]    ───► Open the Statistical Summary Modal, review ANOVA and Q²
            │
  [4. 3D Inspection]  ───► Rotate 3D response surfaces, inspect equipotential contour slices
            │
  [5. Candidate Pool] ───► Select optimal leader (TOP-01, INP-Temperature, or INP-Precursor)
```

### 3.1. Uploading Experimental Data
1. Navigate to the **Lens** tab.
2. Drag and drop your completed workbook. The system parses all input columns, measured outputs, and any recorded preparation/measurement latency times (`TIME_FORW_MINS_`, `TIME_REVE_MINS_`).
3. Precursor forward decay and analytical EOS reverse decay corrections are applied automatically via `VISE_ApplyForwReveDecay_DDEF` if configured.

### 3.2. Interactive Visualisation
* **3D Surface Rotation:** Click and drag on the 3D surface plot to inspect topography, response peaks, and saddle points.
* **Factor Slicing:** Use the slider below the graph to fix the third factor coordinate and evaluate 2D cross-sectional contours.

### 3.3. Statistical Diagnostics and Audit Report
1. Click **Analytical Summary** to open the full statistical report modal.
2. The modal displays:
   * Cross-validated $Q^2$ and $R^2$ values,
   * ANOVA $F$-tests and Lack-of-Fit indicators,
   * Variance Inflation Factors (VIF) to ensure absence of collinear distortion.
3. Click **Download Report (.txt)** to save the complete formatted analysis report for your laboratory notebook.

---

## 4. Sequential Phase Transition (ACTA & ASTM)

To advance from Phase 1 to Phase 2:

1. In the **Candidate Leaders Table**, review the ranked solutions:
   * `TOP-01*`: Global unconstrained composite desirability.
   * `INP-Precursor`: Lowest precursor consumption within $90\%$ of maximum desirability.
   * `INP-Temperature`: Lowest thermal load candidate.
   * `OUT-Impurity`: Lowest radiolytic impurity candidate.
2. Select your preferred candidate row.
3. **ACTA Contraction Factor ($c$):** Adjust the slider to set the search range contraction:
   * $c = 0.50$ (Default): Contracts the factor range by 50% around the selected leader.
   * $c = 0.75$: Mild 25% refinement for broader confirmation.
   * $c = 0.25$: Aggressive 75% zoom for precise fine-tuning.
4. Review the **IPKT Interval Bar Chart** to visually confirm that the new boundaries are valid and safely clamped away from equipment limits.
5. Click **Commit Phase Transition & Download Phase 2 Protocol**. The updated workbook is immediately generated with Phase 1 variance preserved in metadata.
