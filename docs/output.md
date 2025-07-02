# Australian-Structural-Biology-Computing/bindflow: Output

## Introduction

This document describes the output produced by the pipeline. <!-- Most of the plots are taken from the MultiQC report, which summarises results at the end of the pipeline. -->

The directories listed below will be created in the results directory after the pipeline has finished. All paths are relative to the top-level results directory.

<!-- TODO nf-core: Write this documentation describing your workflow's output -->

```
{outdir}
├── bindcraft
│   └── <id>_<batch>_output
│       ├── Accepted
│       │   ├── Animation
│       │   ├── Pickle
│       │   ├── Plots
│       │   └── Ranked
│       ├── MPNN
│       │   ├── Binder
│       │   ├── Relaxed
│       │   └── Sequences
│       ├── Rejected
│       └── Trajectory
│           ├── Animation
│           ├── Clashing
│           ├── LowConfidence
│           ├── Plots
│           └── Relaxed
├── jsonmanager
├── pipeline_info
└── ranker
    └── <id>_Ranked
```

## Pipeline overview

The pipeline is built using [Nextflow](https://www.nextflow.io/) and processes data using the following steps:

- [jsonmanager](#jsonmanager) - Split input based on number of parallel batches
- [bindcraft](#bindcraft) - Generate target number of protein binders
- [ranker](#ranker) - Combine bindcraft results from multiple batches
<!-- - [MultiQC](#multiqc) - Aggregate report describing results and QC from the whole pipeline -->
- [Pipeline information](#pipeline-information) - Report metrics generated during the workflow execution


### jsonmanager

jsonmanager takes the user samplesheet and constructs batches of json input in the format expected by bindcraft.

<details markdown="1">
<summary>Output files</summary>

- `jsonmanager/`
  - `<id>-<batch>.json`: Input JSON files for bindcraft split by `<id>` and `<batch>`

</details>

### bindcraft

[bindcraft](https://github.com/martinpacesa/BindCraft) is an end-to-end tool to design protein binders to hotspots on a target protein.
An initial sequence/coordinate trajectory is produced by backpropagating through the AlphaFold multimer network based on a loss function comprising 
confidence metrics and protein structural properties (such as helical content and radius of gyration).

<details markdown="1">
<summary>Output files</summary>

- `bindcraft/`
  - `<id>-<batch>_final_design_stats.csv`: QC metrics for accepted designs.
  - `<id>-<batch>_output/`
    - `Accepted/` 
      - `Animation/`: Animation of initial trajectories for accepted designs.
      - `Pickle/`: Pickle file of initial trajectories for accepted designs.
      - `Plots/`: Plots of loss measures during initial trajectories for accepted designs.
      - `Ranked/`: Ranked structure files for accepted designs.
      - `*.pdb`: Structure files for accepted designs.
    - `MPNN/`
      - `Binder/`: Predicted structures of MPNN designs (deleted for space by default - 'remove_binder_monomer').
      - `Relaxed/`: Predicted structures of MPNN designs relaxed by PyRosetta.
      - `Sequences/`: MPNN sequences for trajectories that pass initial QC (not saved by default - 'save_mpnn_fasta`)
    - `Rejected/`: Rejected MPNN design structures.
    - `Trajectory/`
      - `Animation/`: Animation of completed initial trajectories.
      - `Clashing/`: Initial trajectory structures rejected for structural clashes (non-neighbour CA distance <2.5A).
      - `LowConfidence/`: Initial trajectory structures rejected for low confidence (pLDDT<0.7) or low number of binder contacts (n<3).
      - `Plots/`: Plots of loss measures during initial trajectories.
      - `Relaxed/`: Structures from initial trajectories relaxed by PyRosetta.
    - `failure_csv.csv`: Summary statistics for designs rejected at any stage of pipeline.
    - `mpnn_design_stats.csv`: QC metrics for MPNN designs (ie multiple designs for each trajectory that passes initial trajectory QC).
    - `trajectory_stats.csv`: Initial trajectory QC metrics.

</details>

### ranker

ranker combines the results of different bindcraft batches for the same design job to produce a combined output

<details markdown="1">
<summary>Output files</summary>

- `ranker/`
  - `<id>_Ranked/`: Ranked structure files for accepted designs for `<id>` aggregated over batches.
  - `<id>_final_design_stats.csv`: QC metrics for accepted designs for `<id>` aggregated over batches.

</details>

<!--
### MultiQC

<details markdown="1">
<summary>Output files</summary>

- `multiqc/`
  - `multiqc_report.html`: a standalone HTML file that can be viewed in your web browser.
  - `multiqc_data/`: directory containing parsed statistics from the different tools used in the pipeline.
  - `multiqc_plots/`: directory containing static images from the report in various formats.

</details>

[MultiQC](http://multiqc.info) is a visualization tool that generates a single HTML report summarising all samples in your project. Most of the pipeline QC results are visualised in the report and further statistics are available in the report data directory.

Results generated by MultiQC collate pipeline QC from supported tools e.g. FastQC. The pipeline has special steps which also allow the software versions to be reported in the MultiQC output for future traceability. For more information about how to use MultiQC reports, see <http://multiqc.info>.
-->

### Pipeline information

<details markdown="1">
<summary>Output files</summary>

- `pipeline_info/`
  - Reports generated by Nextflow: `execution_report.html`, `execution_timeline.html`, `execution_trace.txt` and `pipeline_dag.dot`/`pipeline_dag.svg`.
  - Reports generated by the pipeline: `pipeline_report.html`, `pipeline_report.txt` and `software_versions.yml`. The `pipeline_report*` files will only be present if the `--email` / `--email_on_fail` parameter's are used when running the pipeline.
  - Reformatted samplesheet files used as input to the pipeline: `samplesheet.valid.csv`.
  - Parameters used by the pipeline run: `params.json`.

</details>

[Nextflow](https://www.nextflow.io/docs/latest/tracing.html) provides excellent functionality for generating various reports relevant to the running and execution of the pipeline. This will allow you to troubleshoot errors with the running of the pipeline, and also provide you with other information such as launch commands, run times and resource usage.
