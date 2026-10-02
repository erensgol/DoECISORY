# Methodology

This section details the theoretical and mathematical formulations implemented in **DoECISORY.jl**, covering physical decay adjustments, multi-objective optimisation with kinetic penalties, candidate pool generation, and sequential interphase knowledge transfer.

All formulations are defined in standard mathematical notation and implemented via functional Julia routines.

---

## 1. Radioactive Decay Corrections: Pre- and Post-Reaction Latency

In systems involving radioisotopes or decaying chemical species, elapsed time is a physical variable that alters reagent mass and product activity. Precursor decay before synthesis and analytical latency after reaction completion are managed via [`VISE_ApplyForwReveDecay_DDEF`](@ref) and [`MOLE_CalcRadioDecay_DDEF`](@ref):

* **Precursor Preparation Delay ($\Delta t_{\text{forw}}$):** The elapsed time between stock precursor calibration and addition to the reaction vessel at $t_0$.
* **Reaction Duration ($\Delta t_{\text{reaction}}$):** The controlled residence time in the reactor.
* **Measurement Latency ($\Delta t_{\text{reve}}$):** The post-reaction elapsed time between synthesis completion (End of Synthesis, EOS) and analytical quantification (HPLC, SPE, or dose calibrator).

### 1.1. Forward Precursor Decay Correction
Between precursor calibration and reaction initiation ($t_0$), elapsed preparation time ($\Delta t_{\text{forw}}$) leads to radioactive decay.

If uncorrected, the nominal activity recorded in the design matrix introduces systematic bias into the regression model. The true starting activity $A_{\text{actual}}$ is computed using `MOLE_CalcRadioDecay_DDEF` with `Reverse=false`:

```math
A_{\text{actual}} = A_{\text{nominal}} \cdot \exp(-\lambda \cdot \Delta t_{\text{forw}})
```

where:
* $A_{\text{nominal}}$ is the nominal precursor activity or mass,
* $\lambda = \frac{\ln 2}{t_{1/2}}$ is the physical decay constant derived from the half-life ($t_{1/2}$),
* $\Delta t_{\text{forw}}$ is the preparation duration.

The training matrix column (`ACTUAL_<Precursor>`) is populated with these values, removing preparation latency variance from the model.

### 1.2. Reverse Product Decay Correction (EOS Alignment)
Following synthesis completion (EOS), analytical chromatography and quantification involve variable delay ($\Delta t_{\text{reve}}$).

To compare product yields across all design runs on an equivalent basis, raw measured activity $A_{\text{measured}}$ is reconstructed back to the EOS reference state using `MOLE_CalcRadioDecay_DDEF` with `Reverse=true`:

```math
A_{\text{EOS}} = A_{\text{measured}} \cdot \exp(+\lambda \cdot \Delta t_{\text{reve}})
```

Updating the response column (`ACTUAL_<Output>`) isolates chemical conversion yield from post-synthesis analytical waiting times.

---

## 2. Decay-Coupled Yield Penalty (DCYP) and Desirability Regularisation

### 2.1. Decay-Coupled Yield Penalty (DCYP)
During reaction execution, chemical transformation often exhibits an asymptotic plateau or sigmoidal rise with respect to duration ($\Delta t_{\text{reaction}}$). However, exponential physical decay concurrently diminishes the remaining radioactive payload:

```math
Y_{\text{net}}(t) = Y_{\text{chemical}}(t) \cdot \exp(-\lambda \cdot t)
```

Optimising solely for percentage conversion yield ($Y_{\text{chemical}}$) leads to artificially prolonged reaction times that produce severely degraded net injectable radioactivity.

In DoECISORY, the **Decay-Coupled Yield Penalty (DCYP)** integrates physical decay directly into the multi-criteria composite desirability function $D$:

```math
D_{\text{adjusted}} = D \cdot \exp(-\lambda \cdot \Delta t_{\text{reaction}})
```

By embedding this penalty into both gradient-free metaheuristics and continuous landscape evaluations, DoECISORY identifies the precise kinetic optimum that balances chemical synthesis kinetics against nuclear half-life.

### 2.2. Gaussian Neighbour-Weighting Regularisation
Standard Derringer-Suich desirability functions combine individual desirability transformations $d_i(y_i)$ via geometric averaging:

```math
D = \left( \prod_{i=1}^{k} d_i(y_i)^{w_i} \right)^{\frac{1}{\sum w_i}}
```

Sharp boundaries or disparate objective weightings can induce numerical singularities and noisy objective landscapes that trap gradient or evolutionary search engines in suboptimal local modes.

To guarantee numerical stability, DoECISORY applies a **Gaussian Neighbour-Weighting Regularisation** scheme across a discrete scale of importance weights:

```math
\mathbf{w}_{\text{star}} = [0.50,\, 0.75,\, 1.00,\, 1.50,\, 2.00]
```

For each user-specified weight $w_i$, the neighbouring lower ($w_m$), current ($w_c$), and upper ($w_p$) weights are extracted. The regularised composite desirability is calculated by blending standard exponential weighting with local neighbour-smoothed averaging:

```math
u = d_i(y_i)^{\frac{w_c}{k}}, \quad e = \frac{d_i(y_i)^{\frac{w_m}{k}} + d_i(y_i)^{\frac{w_c}{k}} + d_i(y_i)^{\frac{w_p}{k}}}{3}
```

```math
\text{Score}_{\text{composite}} = 0.50 \cdot \prod_{i=1}^{k} u_i + 0.50 \cdot \prod_{i=1}^{k} e_i
```

This regularisation smoothens narrow ridges in the multi-response landscape, enabling both deterministic grid searches and metaheuristic solvers to converge reliably upon stable global solutions.

---

## 3. Candidate Pool Generation and Selection

Rather than restricting the output to a single theoretical point $x^*$, DoECISORY constructs a structured **Candidate Pool** covering distinct operational compromises: global optimality, input conservation, and output specialisation.

### 3.1. Search Strategy and Deduplication
1. **Continuous Metaheuristic Optimisation:** Explores the continuous parameter space via evolutionary metaheuristics (`BlackBoxOptim.jl`), locating the global mathematical peak coordinate $\mathbf{x}_{\text{BBO}}$ and score $S_{\text{BBO}}$.
2. **Deterministic High-Density Grid:** Evaluates the 3-factor space across a dense grid ($21^3 = 9,261$ or $41^3 = 68,921$ nodes), computing deterministic multi-model predictions and desirability scores.
3. **Euclidean Deduplication:** Grid points are checked against the BBO peak using normalised Euclidean distance:
   ```math
   \text{dist}(\mathbf{x}_i, \mathbf{x}_{\text{BBO}}) = \sum_{j=1}^{d} \frac{|x_{i,j} - x_{\text{BBO},j}|}{U_j - L_j} > 0.01
   ```
   Points clustering within $1\%$ of the BBO optimum are pruned to avoid redundant solutions.

### 3.2. Candidate Classification
From the deduplicated search results, DoECISORY builds a multi-criteria portfolio of candidates rather than forcing a single deterministic compromise:

* **1. Absolute Global Leaders:**
  * `TOP-01*`: Continuous metaheuristic global optimum from `BlackBoxOptim`.
  * `TOP-02`: Highest-scoring discrete node identified on the high-density grid.
* **2. Input Minimisation Leaders (`INP-<Factor>`):**
  Isolated within the top performance tier ($D(\mathbf{x}) \ge 0.90 \cdot D_{\max}$). For each active experimental factor $j \in \{1, \dots, d\}$, the algorithm extracts the coordinate that individually minimises that specific input:
  ```math
  \mathbf{x}_{\text{INP-}j} = \arg\min_{\mathbf{x} \in \text{Tier}_{90}} x_j
  ```
  * `INP-X1` (e.g. `INP-Temperature`): Formulations that operate at the lowest possible thermal load to prevent substrate decomposition.
  * `INP-X2` (e.g. `INP-ReactionTime`): Formulations with minimal residence time, reducing physical radioactive decay and equipment occupancy.
  * `INP-X3` (e.g. `INP-Precursor`): Formulations that conserve scarce or expensive active pharmaceutical ingredients (APIs).
* **3. Output Specialisation Leaders (`OUT-<Response>`):**
  Identified within the same $90\%$ desirability tier by evaluating which candidate maximises or minimises individual quality attributes:
  * `OUT-Y1` (e.g. `OUT-RadiochemicalYield`): Prioritises maximal conversion.
  * `OUT-Y2` (e.g. `OUT-RadiolyticImpurity`): Prioritises minimal radiolytic fragmentation.
  * `OUT-Y3` (e.g. `OUT-ColloidalFraction`): Prioritises minimal colloidal suspension.

This multi-faceted portfolio allows the research team to select a leader tailored to specific laboratory limitations (e.g. reagent scarcity, heating constraints, or purity thresholds) before advancing to the next sequential phase.

---

## 4. Sequential Interphase Transfer (ACTA and ASTM)

The **Interphase Knowledge Transfer (IPKT)** framework connects sequential experimental phases through a two-step mathematical operator: **ACTA** handles intra-space domain adaptation, while **ASTM** executes cross-system affine mapping and space regeneration.

### 4.1. Domain Adaptation (ACTA)
Given the chosen leader coordinate $x_i^*$ within current bounds $[L_i, U_i]$, the normalised relative position $p_i$ is evaluated:

```math
p_i = \frac{x_i^* - L_i}{U_i - L_i}
```

* **Contraction ($0.05 \le p_i \le 0.95$):**
  The optimum is situated within the internal search volume. The search window is contracted symmetrically around the leader point:
  ```math
  \Delta_{\text{new}} = c \cdot (U_i - L_i)
  ```
  ```math
  L_i^{\text{new}} = x_i^* - \frac{\Delta_{\text{new}}}{2}, \quad U_i^{\text{new}} = x_i^* + \frac{\Delta_{\text{new}}}{2}
  ```
  The contraction factor $c \in (0.0, 1.0]$ (default: $c = 0.50$, representing a $50\%$ range narrowing) is researcher-controlled via UI slider or script argument.

* **Translation ($p_i < 0.05$ or $p_i > 0.95$):**
  The optimum lies on or near the boundary, indicating that the true physical summit may reside outside the current domain. The range width is preserved while the window translates directionally toward the leader:
  ```math
  \delta = x_i^* - \frac{L_i + U_i}{2}
  ```
  ```math
  L_i^{\text{new}} = L_i + \delta, \quad U_i^{\text{new}} = U_i + \delta
  ```

* **Absolute Clamping:**
  All newly derived boundaries are checked against physical, thermodynamic, and safety limits $[L_i^{\text{abs}}, U_i^{\text{abs}}]$ via `FLOW_ValidateASTM_DDEF`:
  ```math
  L_i^{\text{clamped}} = \max\left(L_i^{\text{abs}},\, L_i^{\text{new}}\right), \quad U_i^{\text{clamped}} = \min\left(U_i^{\text{abs}},\, U_i^{\text{new}}\right)
  ```

### 4.2. Affine Transformation and Clamping (ASTM)
Following ACTA boundary adaptation, coordinates undergo affine mapping to accommodate inter-phase scale changes, equipment migrations, or formulation changes:

```math
x_{\text{transformed}} = \alpha \cdot x + \beta
```

This operator supports four distinct experimental scenarios:
1. **Thermodynamic Invariance ($\alpha = 1.0, \beta = 0.0$):** Factors such as temperature or pH that maintain identical physical boundaries across experimental scales are transferred directly.
2. **Kinetic & Volumetric Scaling ($\alpha \neq 1.0, \beta = 0.0$):** When transitioning from a 1 mL micro-reactor to a 10 mL preparative vessel, flow rates or reaction times are multiplied by scaling ratio $\alpha$.
3. **Systematic Offset ($\alpha = 1.0, \beta \neq 0.0$):** Incorporates systematic calibration offsets when changing analytical instruments or reagent batches.
4. **Space Regeneration & Factor Replacement:** When a solvent or catalyst is substituted between phases, common continuous factors retain their historical knowledge, peak positions, and variance through IPKT, while the novel factor is initialised with new physical levels. This avoids resetting the entire experimental campaign.

---

## 5. Directional D-Optimal Design (DF14)

In sequential DoE, standard symmetrical screening designs (such as Box-Behnken with 15 runs or Central Composite with 17 runs) distribute points uniformly. When prior screening or preliminary runs indicate a preferred directional gradient, DoECISORY offers the **DF14 (14-Point Directional D-Optimal)** matrix geometry.

### 5.1. D-Efficiency Formulation
The information matrix $M$ for a quadratic model $f(\mathbf{x})$ evaluated across design matrix $X$ ($N \times p$) is:

```math
M = \frac{1}{N} X^T X
```

D-optimality maximises the determinant of the information matrix, which is inversely proportional to the volume of the confidence ellipsoid for model parameters $\boldsymbol{\beta}$:

```math
D\text{-efficiency} = 100 \cdot \left( \frac{|X^T X|^{1/p}}{N} \right)
```

where $p$ is the number of estimated model terms (10 for a 3-factor full quadratic model) and $N = 14$.

### 5.2. Geometrical Construction
The DF14 design consists of:
* A central coordinate $[0, 0, 0]$,
* Replicated axial points oriented along the directional search vector $\mathbf{v}_{\text{dir}} \in \{-1, 0, 1\}^3$,
* Face-centred and fractional corner points selected to minimise the condition number $\kappa(X^T X)$ while maintaining estimability of all linear, interaction, and pure quadratic terms in fewer runs than standard 15-run Box-Behnken matrices.
