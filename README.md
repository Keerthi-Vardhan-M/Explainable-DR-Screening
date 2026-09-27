# Explainable AI for Diabetic Retinopathy Screening

MATLAB prototype for the SIH project **"Explainable AI for Diabetic Retinopathy Screening in Rural India."** It processes a retinal fundus image through:

1. image-quality assessment and safe enhancement;
2. retinal structure and lesion-candidate extraction;
3. optional five-class DR severity prediction (grades 0–4);
4. Grad-CAM attention visualization when a compatible classifier is supplied;
5. a doctor-review dashboard, case summary, and PDF report; and
6. a MATLAB/Simulink workflow-capacity demonstration.

> **Research prototype — not a medical device.** Output is for screening support and must be reviewed by an ophthalmologist. The quality thresholds, lesion candidates, model performance, referral threshold, and clinical usefulness require independent validation.

![Application dashboard](docs/application-dashboard.png)

## What is included

| Component | Included | Notes |
| --- | --- | --- |
| Quality gate and adaptive enhancement | Yes | Implemented in the root-level `*.m` files. |
| Classical vessel / MA / haemorrhage / exudate candidates | Yes | Heuristic evidence, not a trained lesion-segmentation claim. |
| Dashboard, reports, and workflow simulation | Yes | Runs after setup. |
| DR classifier and Grad-CAM | Code included | Requires a separate compatible `trainedDRModel.mat`. |
| IDRiD dataset | No | Download it separately; do not commit clinical datasets. |

The repository contains a `repository_files/` subfolder with the classifier, Grad-CAM, calibration, and evaluation helpers. **Do not move those files.** The setup command below adds the whole project tree to the MATLAB path.

## Requirements

- MATLAB **R2020b or newer** (tested target: R2026a)
- **Image Processing Toolbox** — required for all image processing
- **Deep Learning Toolbox** — required only for classifier inference and Grad-CAM
- **Statistics and Machine Learning Toolbox** — required only for the optional lesion-feature branch
- **Simulink** — optional; the MATLAB workflow simulation still runs without it

No GPU is required. The supplied scripts explicitly use CPU inference.

## Get the project

### MATLAB Desktop

Clone the repository with Git, or download **Code → Download ZIP** from GitHub and extract it.

```bash
git clone https://github.com/Keerthi-Vardhan-M/Explainable-DR-Screening.git
```

In MATLAB, replace the path with the folder where you extracted or cloned the project:

```matlab
projectRoot = 'C:\path\to\Explainable-DR-Screening';
cd(projectRoot)
addpath(genpath(projectRoot))
savepath                         % optional: keeps the path after restarting MATLAB
```

On macOS/Linux, use forward slashes, for example:

```matlab
projectRoot = '/home/your-name/Explainable-DR-Screening';
cd(projectRoot)
addpath(genpath(projectRoot))
```

### MATLAB Online

1. Download the repository ZIP from GitHub.
2. Upload it to MATLAB Drive.
3. Run the following in the MATLAB Command Window. Change the ZIP filename if GitHub gave it a different name.

```matlab
driveRoot = matlabdrive;
unzip(fullfile(driveRoot,'Explainable-DR-Screening-main.zip'),driveRoot)
projectRoot = fullfile(driveRoot,'Explainable-DR-Screening-main');
cd(projectRoot)
addpath(genpath(projectRoot))
```

If the extracted folder has another name, run `dir(driveRoot)` and set `projectRoot` to that folder instead.

## First-run checks

Run these commands once after setup:

```matlab
checkFundusEnvironment            % checks Image Processing Toolbox and MATLAB release
checkStage123                     % image-quality and enhancement engineering checks
checkFullDRDemo                   % evidence, report, and workflow smoke checks; no model needed
```

Expected final messages include:

```text
All stage 1-3 engineering regression checks passed.
Full-project smoke checks passed (external model and Simulink not tested by this function).
```

These are software checks, **not** clinical validation or accuracy measurements.

## Run the application

The project can be demonstrated without a classifier: it will show quality, enhancement, retinal evidence, report generation, and clearly withhold the DR grade.

```matlab
c = setupDRDemo(projectRoot);
launchDRDemo(c)
```

In the dashboard, choose a JPG/JPEG/PNG/TIF/TIFF/BMP fundus image and select **Run screening**. Outputs are created in:

```matlab
fullfile(projectRoot,'dr_demo_results')
```

Each case folder includes the original/enhanced previews, retinal field, lesion-candidate masks and CSV, case summary JSON, PDF report, and (by default) a MAT-file audit record.

### Run one image from the Command Window

```matlab
c = setupDRDemo(projectRoot);
imagePath = 'C:\path\to\fundus_image.jpg';
out = runDRCase(imagePath,c);
open(out.outputFolder)
```

Without a model, `out.prediction.available` is `false` by design. This is the correct safe behaviour.

## Enable the trained DR model and Grad-CAM

The trained model is deliberately **not included** in this repository. Place a compatible MATLAB MAT-file anywhere accessible to MATLAB, then set its exact path. A compatible file contains exactly one `DAGNetwork`, `SeriesNetwork`, or `dlnetwork`, accepts RGB `224 × 224 × 3` input, and produces five classes in grade order `0, 1, 2, 3, 4`.

Before enabling inference, confirm the original model's preprocessing. The current team model uses `zero_255` input with its stored `zerocenter` input normalization. Do **not** set `preprocessingConfirmed` to `true` unless this has been checked against the training/export configuration.

```matlab
c = setupDRDemo(projectRoot);
c.modelPath = 'C:\path\to\trainedDRModel.mat';
c.modelInputRange = 'zero_255';       % use 'zero_one' only if that matches training
c.preprocessingConfirmed = true;

inspectDRModel(c.modelPath)
model = loadDRModel(c.modelPath,c);

imagePath = 'C:\path\to\fundus_image.jpg';
out = runDRCase(imagePath,c,model);
disp(out.prediction)
open(out.outputFolder)
```

To use the dashboard with this model:

```matlab
launchDRDemo(c)
```

Then select the MAT-file in **Choose MAT model**, keep the matching scaling option, tick **Scaling verified**, and run screening. Grad-CAM is saved as `gradcam.png` when the network and selected feature layer support it.

## Process a folder of images (quality gate)

Use this for stage 1–3 batch processing. The original input files are never modified.

```matlab
inputFolder = 'C:\path\to\fundus_images';
outputFolder = 'C:\path\to\stage123_results';

c = fundusConfig();
c.datasetMode = 'generic';
[summary,runDir] = runStage123(inputFolder,outputFolder,c);
disp(summary(:,{'ImageID','Status','RouteToAnalysis','Feedback'}))
open(runDir)
```

For an IDRiD extraction, point to its extracted parent folder:

```matlab
idridRoot = 'C:\path\to\IDRiD';
c = fundusConfig();
c.datasetMode = 'idrid';
[summary,runDir] = runStage123(idridRoot,'C:\path\to\stage123_results',c);
```

For one image, use:

```matlab
r = demoStage123('C:\path\to\fundus_image.jpg');
```

Only pass `r.image` downstream when `r.routeToAnalysis` is true:

```matlab
r = processFundus('C:\path\to\fundus_image.jpg');
if r.routeToAnalysis
    imageForNextStage = r.image;      % native-size single RGB image in [0,1]
    retinalFieldMask = r.mask;
else
    disp(r.message)                   % capture/review feedback
end
```

## IDRiD validation and optional model utilities

Download IDRiD yourself and extract it under a local folder such as `datasets/IDRiD`. Do not use synthetic demo images to report performance.

```matlab
c = setupDRDemo(projectRoot);
c.datasetRoot = 'C:\path\to\IDRiD';

% Checks five originals by default. Use Inf only when you intend a full run.
[audit,summary,runDir] = validateIDRiD(c.datasetRoot);

% Verify one of the two documented input scaling adapters on training data.
c.modelPath = 'C:\path\to\trainedDRModel.mat';
[c,preprocessAudit] = verifyDRPreprocessing(c,20);

% Evaluate only on the official testing split after configuration is frozen.
[results,rows,resultFolder] = validateDRDemo(c);
```

`verifyDRPreprocessing`, calibration, and validation require the trained model, Deep Learning Toolbox, and an IDRiD grading extraction containing the official label CSVs. Keep the official testing split untouched while selecting preprocessing, model fusion, or thresholds.

## Workflow capacity and Simulink demo

The MATLAB workflow model runs without Simulink:

```matlab
workflowDemo(fullfile(projectRoot,'workflow_results'))
```

If Simulink is installed, generate and run the connected queue model:

```matlab
checkSimulinkDemo(fullfile(projectRoot,'workflow_results'))
```

The resulting plots, PDFs, MAT-files, and (when available) `.slx` file are saved under `workflow_results`.

## Key entry points

| Goal | Command |
| --- | --- |
| Check required image-processing support | `checkFundusEnvironment` |
| Run stage 1–3 regression checks | `checkStage123` |
| Run full non-model smoke checks | `checkFullDRDemo` |
| Open the screening dashboard | `c = setupDRDemo(projectRoot); launchDRDemo(c)` |
| Process one complete case | `out = runDRCase(imagePath,c,model)` |
| Batch quality/enhancement run | `[summary,runDir] = runStage123(inputFolder,outputFolder,c)` |
| Generate a PDF case report | `exportDRReport(out)` |
| Run MATLAB/Simulink capacity workflow | `workflowDemo(folder)` |

## Important limitations

- Quality assessment is a provisional engineering gate, not a clinical gradability certification.
- The included MA/haemorrhage/exudate overlays are heuristic candidates, not validated lesion masks.
- Grad-CAM visualizes the classifier's attention; it is not a lesion segmentation.
- A prediction can be withheld for poor-quality images, unknown preprocessing, missing model, or low-confidence/error conditions.
- No sensitivity, specificity, or accuracy claim should be made until measured on a locked, independent test set and reported with its coverage and exclusions.

## References

- [IDRiD data description](https://idrid.grand-challenge.org/Data/)
- [MATLAB Image Processing Toolbox](https://www.mathworks.com/products/image.html)
- [MATLAB Grad-CAM documentation](https://www.mathworks.com/help/deeplearning/ref/gradcam.html)
