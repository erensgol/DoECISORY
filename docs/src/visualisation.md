# Visualisation

*(Draft / Placeholder)*

This section outlines the interactive visualisation implemented in **DoECISORY.jl** via `Lib_Arts` and PlotlyJS. 

> [!NOTE]
> High-resolution interactive visual graphics, embedded figures, and dynamic walkthroughs are currently under active co-development. The structural headings and conceptual scope below represent the visualisation portfolio.

---

## 1. Palette Standards

* **Scientific Colour Mapping:** Natively employs the perceptually uniform, colourblind-accessible **Viridis** colour scale for all response surfaces and contour gradients.
* **Resolution & Publication Quality:** Renders responsive vector outputs suitable for high-resolution manuscript publication and live interactive web inspection.

---

## 2. Response Surfaces and Contours

* **Dual-Mode Rendering:** Interactive 3D response surfaces with continuous rotation, pitch, and zoom alongside planar 2D equipotential contour projections.
* **Analytical Resolution:** Surface meshes computed over fine continuous evaluation grids to highlight ridges, saddles, and global maxima.

*(Interactive figures and sample code snippets to be embedded)*

---

## 3. Factor Slicing

* **Multi-Factor Projection:** For 3-factor designs, fixing one factor coordinate at specified levels (e.g. minimum, centre, maximum, or optimal leader level) while generating orthogonal 2D slices across the remaining active factors.
* **Interaction Diagnostics:** Isolating cross-term curvature and identifying robust operating regions across varying parameter slices.

*(Slicing demonstrations to be embedded)*

---

## 4. Sequential Space Visualisation

* **Search Space Dynamics:** Visualisation of search domain contraction ($c$) and directional translation ($\delta$) between successive experimental phases via `FLOW_RenderIPKT_DDEF`.
* **Range Comparison Bars:** Horizontal interval bars juxtaposing previous design limits, adapted search boundaries, and the selected leader operating point.

*(Transition bar charts to be embedded)*
