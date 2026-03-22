---
title: DaishoDoE
emoji: 🧪
colorFrom: purple
colorTo: indigo
sdk: docker
pinned: false
license: agpl-3.0
short_description: Decision-Adaptive Interactive Sequential Hybrid Optimization
---

# DaishoDoE Framework

**A Decision-Adaptive, Interactive, and Sequential Hybrid Optimisation Framework for Design of Experiments (DoE)**

Developed at **Hacettepe University, Department of Radiopharmacy**, DaishoDoE is a high-performance scientific framework designed to revolutionise the way experimental designs are synthesised and analysed. Built entirely in **Julia** with a high-fidelity **Dash** interface, it provides researchers with robust tools for DOE methodologies including Box-Behnken, Taguchi, and more.

---

## Project Vision & Architecture

DaishoDoE is engineered for academic excellence and scientific integrity. It follows a strict functional and stateless architecture, ensuring reproducibility and stability in complex computational environments.

- **Lib_Mole**: Stoichiometry and chemical calculations.
- **Lib_Core**: Mathematical algorithms and matrix generation.
- **Lib_Vise**: Statistical engines (GLM, Regression, Hypothesis Testing).
- **Lib_Arts**: High-fidelity visualisation using PlotlyJS (Viridis palette).

# Deployment & Usage

### Cloud Deployment
The application is ready for cloud interaction and can be accessed at:  
[https://erensgol-daishodoe.hf.space](https://erensgol-daishodoe.hf.space)

### Local Installation
For superior computational performance, local installation is recommended.
To run DaishoDoE locally:

1. Clone the repository:
   ```bash
   git clone https://github.com/erensgol/DaishoDoE.git
   cd DaishoDoE
   ```
2. Start the application:
   - **Windows**: Run `run_DDE.bat`
   - **Manual**: `julia --project -e "include(\"app.jl\")"`

---

# 📄 License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPLv3)**. 

> [!NOTE]
> The AGPLv3 ensures that if you run a modified version of this software as a network service, you must make the source code of that modified version available to your users. 

---

# Author & Contact

**Pharmacist Eren Selim GÖL**  
*Lead Software Architect & Julia Developer*  
Hacettepe University, Department of Radiopharmacy.  
