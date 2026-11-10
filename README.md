# Peng–Robinson EOS | Real-Gas Property Calculator

#(Note: The .apk file is present within this repo, that can be installed and used it's safe to use and report has also been uploaded)
A Flutter-based thermodynamic software application that predicts the Pressure–Volume–Temperature (PVT) behaviour and thermodynamic properties of real gases using the **Peng–Robinson (PR) Equation of State**.

Developed as a Chemical Engineering project at IIT Delhi.

---

## Project Information

| Detail | Information |
|---|---|
| Project | Real-Gas Property Software Based on Peng–Robinson EOS |
| Group | Group 02 |
| Developers | Yug Bhushan and Shrish Kumar |
| Framework | Flutter |
| Programming Language | Dart |
| Application | Android APK and Flutter Web |
| Domain | Chemical Engineering / Thermodynamics |

## Overview

The ideal gas law provides a reasonable approximation under low-pressure and high-temperature conditions. However, real gases deviate significantly from ideal behaviour when intermolecular attractions and molecular volume become important.

This project implements the **Peng–Robinson cubic equation of state** to predict real-gas behaviour at specified temperatures and pressures.

The application calculates PVT properties, residual thermodynamic properties, fugacity and fugacity coefficient. It also provides interactive graphs and allows users to export their calculated results as PDF reports.

## Key Features

### 1. PVT Behaviour
- Compressibility factor (Z).
- Molar volume and density.
- Pressure, volume and temperature calculations.
- Calculation of all physical real roots of the cubic equation.
- Comparison with ideal-gas behaviour.

### 2. Thermodynamic Properties
- Residual enthalpy (Hᴿ).
- Residual entropy (Sᴿ).
- Absolute enthalpy (H).
- Absolute entropy (S).
- Fugacity (f).
- Fugacity coefficient (φ).

### 3. Multiple Input Modes

Users can select any two known state variables:

| Input Mode | Calculated Property |
|---|---|
| Temperature (T) and Pressure (P) | Molar volume and compressibility factor |
| Temperature (T) and Volume (V) | Pressure |
| Pressure (P) and Volume (V) | Temperature |

### 4. Phase Identification

The software identifies the thermodynamically stable phase based on the Peng–Robinson equation and fugacity coefficient calculations.

Possible phase classifications include:
- Gas
- Liquid
- Vapour
- Supercritical fluid

When three physical roots exist, the software compares the fugacity coefficients of the liquid and vapour roots to identify the stable phase.

### 5. Interactive Graphs

The application provides the following plots:

- Generalised compressibility chart (Z vs reduced pressure).
- P–V isotherms with ideal-gas comparison.
- Compressibility factor versus pressure.
- Enthalpy versus temperature.
- Entropy versus temperature.
- Fugacity coefficient versus pressure.
- Residual enthalpy versus pressure.
- Residual entropy versus pressure.

### 6. PDF Report Generation

Users can export calculated results into a PDF report containing inputs, equations and calculated thermodynamic properties.

### 7. User Interface

- Substance selection.
- Validated numerical inputs.
- Interactive calculation interface.
- Light and dark themes.
- Dedicated guide page.

---

## Supported Substances

The application currently supports the following ten pure components:

| No. | Substance | Formula |
|---:|---|---|
| 1 | Methane | CH₄ |
| 2 | Ethane | C₂H₆ |
| 3 | Ethylene | C₂H₄ |
| 4 | Propane | C₃H₈ |
| 5 | n-Butane | C₄H₁₀ |
| 6 | Carbon Dioxide | CO₂ |
| 7 | Nitrogen | N₂ |
| 8 | Oxygen | O₂ |
| 9 | Ammonia | NH₃ |
| 10 | Hydrogen Sulphide | H₂S |

---

## Theoretical Background

The Peng–Robinson equation of state is expressed as:

```text
P = RT/(V - b) - a(T)/(V² + 2bV - b²)
```

The equation accounts for intermolecular attraction and molecular volume through the parameters a(T) and b.

The parameters are calculated using critical temperature (Tc), critical pressure (Pc) and acentric factor (ω).

The dimensionless parameters are:

```text
A = a(T)P/(RT)²

B = bP/(RT)
```

The resulting cubic equation in compressibility factor Z is:

```text
Z³ - (1-B)Z²
+ (A - 3B² - 2B)Z
- (AB - B² - B³) = 0
```

Only roots satisfying Z > B are considered physically meaningful.

The software further uses the fugacity coefficient to determine phase stability and calculates residual enthalpy and entropy using the corresponding thermodynamic relations.

---

## Software Architecture

The application is developed using Flutter and Dart, with thermodynamic calculations separated from the user interface.

| File | Description |
|---|---|
| `main.dart` | Main application interface, input validation, calculations interface, guide page and themes |
| `pr_eos.dart` | Core Peng–Robinson solver, cubic root calculations, thermodynamic properties and phase identification |
| `substances.dart` | Database of critical properties, acentric factors and molecular weights |
| `chart_data.dart` | Generates datasets for thermodynamic plots and ideal-gas comparisons |
| `chart_painter.dart` | Custom chart rendering and visualisation |
| `pdf_report.dart` | Generates downloadable and shareable PDF reports |

---

## Validation and Results

The software was validated against the textbook benchmark for **n-Butane at 500 K and 50 bar**.

| Property | Reference Value | Software Result |
|---|---:|---:|
| Compressibility factor (Z) | 0.6907 | 0.6909 |
| Residual enthalpy (J/mol) | -4988 | -4985 |
| Residual entropy (J/mol·K) | — | -7.4214 |
| ln(φ) | — | -0.30653 |
| Fugacity (bar) | — | 36.80 |

The compressibility factor and residual enthalpy agree with the textbook benchmark within approximately 0.03% and 0.06%, respectively.

Additional fugacity consistency checks were performed for propane, n-butane, carbon dioxide and ammonia.

---

## Application Screenshots

The following screenshots demonstrate the application interface and its thermodynamic visualisations.

Add your screenshots inside a folder named `screenshots/` and use the following references:

| Application View | Screenshot |
|---|---|
| Input screen and PVT results | `screenshots/input.png` |
| Thermodynamic properties | `screenshots/properties.png` |
| Generalised compressibility chart | `screenshots/compressibility.png` |
| P–V isotherm | `screenshots/pv-isotherm.png` |
| Enthalpy vs temperature | `screenshots/enthalpy.png` |
| Fugacity coefficient vs pressure | `screenshots/fugacity.png` |

---

## Download and Installation

### Android Application (APK)

The Android application is available through the GitHub Releases section.

**[Download Latest APK](https://github.com/shrish-iitd/thermo-project-shrish-yug/blob/main/apk_file.zip)**

Installation:
1. Download the APK on your Android device.
2. Open the downloaded APK.
3. Allow installation from the relevant source if Android requests permission.
4. Complete the installation and launch the application.

### Run from Source

Requirements:
- Flutter SDK
- Dart SDK
- Android Studio or VS Code (optional IDE)

Clone the repository:

```bash
git clone https://github.com/shrish-iitd/thermo-project-shrish-yug.git
```

Navigate into the project:

```bash
cd thermo-project-shrish-yug
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

Build the Android APK:

```bash
flutter build apk --release
```

The generated APK can be found at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Build the web application:

```bash
flutter build web --release
```

---

## Limitations

The current implementation has the following limitations:

1. Near the critical point, the Peng–Robinson equation may overpredict the compressibility factor and provide less accurate liquid volumes.
2. Strongly polar and hydrogen-bonding fluids, such as water and alcohols, are not represented accurately by the standard alpha function.
3. Ideal-gas heat-capacity correlations are fitted from 298.15 K upwards. Predictions significantly below this temperature involve extrapolation.
4. The current software supports pure components only. Mixture calculations would require appropriate mixing rules for the equation-of-state parameters.

---

## References

1. Smith, J. M., Van Ness, H. C., Abbott, M. M., and Swihart, M. T., *Introduction to Chemical Engineering Thermodynamics*, 8th Edition, McGraw-Hill, 2018.
2. Peng, D.-Y., and Robinson, D. B. (1976). A New Two-Constant Equation of State. *Industrial & Engineering Chemistry Fundamentals*, 15, 59–64.

---

## Developers

**Group 02**

- **Yug Bhushan** — 2025CH71601
- **Shrish Kumar** — 2025CH11634

Developed as a Chemical Engineering software project at **Indian Institute of Technology Delhi (IIT Delhi)**.

---

*Built with Flutter and Dart. Applying thermodynamic theory to practical real-gas property prediction.*
