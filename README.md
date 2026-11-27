# CC–CV and Mamdani charging benchmark

This package contains the executable models and data for the manuscript in `InformeBaterias/ingles.tex`.

## Reproduce the manuscript

1. In MATLAB R2023b Update 11 with Simulink, Fuzzy Logic Toolbox, Simscape and Simscape Electrical Specialized Power Systems, open the package root as the current folder.
2. Run `run_benchmark`. It executes 35 benchmark cases plus the Eisto comparison. It regenerates the signal CSVs and configuration JSONs in `results/`, the figures in `InformeBaterias/images/`, and the generated LaTeX tables and values.
3. From `InformeBaterias/`, run `latexmk -pdf ingles.tex` or run pdfLaTeX twice. The package includes a compiled PDF and generated data for inspection.

To regenerate the benchmark graphics from the included CSVs, run `build_paper_assets(fullfile(pwd,'results'),fullfile(pwd,'InformeBaterias'))` from the package root. The Eisto validation under `Validacion_Eisto/` has a separate MATLAB entry point, `ejecutar_comparacion`, and contains its source chart, digitization, simulation, and error metrics.

## Models, cases and outputs

- `SIMULINK_CCCV.slx` and `SIMULINK_Fuzzy.slx` are the benchmark models. The Mamdani model opens with the nominal `Fuzzy_2_2A.fis`. The runner selects `Fuzzy_1_8A.fis` for the three `output180_*` cases. `write_output_variant.m` generates the variant by rescaling the output membership functions.
- `results/summary.csv` lists the model, FIS, current ceiling, initial mean SOC and spread, threshold event, voltage spread, and other case results. Each signal CSV contains time-stamped signals aligned to the cell-voltage records. The two JSON files record model settings, connections and compiled sample times. The models log to memory during execution.
- The output-range comparison pairs `output180_baseline`, `output180_mean20` and `output180_spread30` with `baseline`, `mean20` and `spread30`. Each pair has a fixed 2.2 A downstream ceiling. The reported outcomes are the time to the first 4.2 V crossing and the maximum-minus-minimum cell voltage at that sample.
- The published thermal comparison uses CC–CV and the nominal Mamdani FIS at a uniform initial SOC of 2.5% and a 2.2 A ceiling. The three `output180_*` cases report electrical outcomes only.

The 1.8 and 2.2 A settings are simulation scenarios. The Eisto reference charge current is 1.1 A.
