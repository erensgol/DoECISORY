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

# DoECISORY

**Design of Experiments with Computational Interactive Sequential Optimization for Response Yield**

Developed at **Hacettepe University, Department of Radiopharmacy**, DoECISORY is a high-performance scientific system designed to revolutionise the way experimental designs are synthesised and analysed. Built entirely in **Julia** with a high-fidelity **Dash** interface, it provides researchers with robust tools for DOE methodologies including Box-Behnken, Taguchi, Central Composite, and D-Optimal designs.

---

## Project Vision & Architecture

DoECISORY is engineered for academic excellence and scientific integrity. It follows a strict functional and stateless architecture, ensuring reproducibility and stability in complex computational environments.

- **Lib_Mole**: Stoichiometry and chemical calculations.
- **Lib_Core**: Mathematical algorithms and matrix generation.
- **Lib_Vise**: Statistical engines (Regression, Hypothesis Testing).
- **Lib_Arts**: High-fidelity visualisation using PlotlyJS (Viridis palette).
- **Sys_Fast**: Excel I/O, transient memory management and system utilities.
- **Sys_Flow**: Cross-phase scientific state transitions and design iteration.

---

# Deployment & Usage

### Cloud Deployment
The application is ready for cloud interaction and can be accessed at:  
[https://erensgol-doecisory.hf.space]

### Local Installation
For superior computational performance, local installation is recommended.
To run DoECISORY locally:

1. Clone the repository:
   ```bash
   git clone https://github.com/erensgol/DoECISORY.git
   cd DoECISORY
   ```
2. Start the application:
   - **Windows**: Run `Run_DoE.bat`
   - **Manual**: `julia --project=. app.jl`

---

# 📄 License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**. 

> [!NOTE]
> The AGPLv3 ensures that if you run a modified version of this software as a network service, you must make the source code of that modified version available to your users. 

---

# Author & Contact

**Pharmacist Eren Selim GÖL**  
*Lead Software Architect*  
https://www.linkedin.com/in/erensgol
