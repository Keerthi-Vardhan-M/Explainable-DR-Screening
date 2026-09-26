# MATLAB fundus pipeline: diagram stages 1, 2 and 3

This package implements **fundus image input → image quality gate → adaptive enhancement**, as numbered in your architecture. It supplies images and quality metadata to your team's later lesion analysis stage. MATLAB R2020b or newer and **Image Processing Toolbox** are required. MATLAB Online works; desktop installation and GPU are unnecessary.

## MATLAB Online quick start

Upload `matlab_stage123.zip` into MATLAB Drive. In the Command Window:

```matlab
unzip('matlab_stage123.zip');
cd('matlab_stage123');
startHere                  % dependency check + engineering regression checks
```

For one uploaded image:

```matlab
r = demoStage123('/MATLAB Drive/my_images/IDRiD_01.jpg');
```

For an entire dataset:

```matlab
[summary,runDir] = runStage123('/MATLAB Drive/my_images');
disp(summary(:,{'ImageID','Status','RouteToAnalysis','Feedback'}));
```

Paths are examples: replace them with your actual MATLAB Drive locations. Single-image file selection also works with `demoStage123` without arguments.

## IDRiD

Download and extract the dataset from its official repository. Upload the extracted original-image folders, or upload an archive and extract it in MATLAB Drive:

```matlab
unzip('/MATLAB Drive/A. Segmentation.zip','/MATLAB Drive/datasets/IDRiD');
c = fundusConfig();
c.datasetMode = 'idrid';
files = discoverFundus('/MATLAB Drive/datasets/IDRiD',c);
disp(files(1:min(5,height(files)),:));
[summary,runDir] = runStage123('/MATLAB Drive/datasets/IDRiD', ...
    '/MATLAB Drive/stage123_results',c);
```

The archive filename is an example. `A. Segmentation`, `B. Disease Grading`, and `C. Localization` original-image folders are supported without requiring labels. Nested folders and spaces in folder names are handled. Folder discovery selects `Original Images` subtrees in auto/IDRiD mode and excludes ground truth folders and known lesion-mask suffixes. Training/testing folders remain identified in the input manifest; this package does not train a model or merge datasets for training. Duplicate filenames in different folders receive different numbered output folders.

If you select only an original-image training/testing folder, it also works. With `datasetMode='idrid'`, inputs in layouts without `Original Images` must have names matching `IDRiD_<number>` (optional copy suffixes such as `(1)` are accepted). Use generic mode or an explicit file list for custom names. Content duplicates are not silently removed; preserve the input manifest and remove duplicate patient/image copies before later model training or validation.

## Other datasets and camera frames

Supported file formats: JPG/JPEG, PNG, TIF/TIFF and BMP, subject to MATLAB's decoder. Accepted arrays: uint8/uint16 RGB, or single/double RGB already normalized to [0,1]. No assumption is made about DR labels or image dimensions. Camera input means an RGB frame supplied by your camera's driver/SDK; hardware capture requires the camera-specific integration.

```matlab
c = fundusConfig();
c.datasetMode = 'generic';
files = discoverFundus('/MATLAB Drive/another_dataset',c);
[summary,runDir] = runStage123(files.ImagePath,'stage123_results',c);

% imageDatastore:
imds = imageDatastore('/MATLAB Drive/another_dataset', ...
    'IncludeSubfolders',true);
[summary,runDir] = runStage123(imds,'stage123_results',c);

% One camera frame or file:
r = processFundus(cameraRGBFrame,c);
r = processFundus('image.jpg',c);
```

A CSV/table with an `ImagePath` column is also accepted. CSV manifests use comma delimiters and a header in the first row, including single-column files. Quote paths containing commas. Relative CSV paths are resolved against the CSV's folder; relative table/file-list paths use the current MATLAB folder. Explicit lists, datastores and manifests bypass folder/name exclusion filters. Review `discoverFundus` output before starting a large run. Set exclusion patterns to `{}` if a generic dataset uses names the defaults would exclude. Use a dedicated output folder named `stage123_results` outside the input folder to avoid processing earlier exports.

Indexed PNGs are decoded to RGB. Fully opaque alpha channels are accepted. Non-opaque images, multipage files, invalid arrays and unsupported encodings fail explicitly. Grayscale is disabled by default; `c.allowGrayscale=true` permits conversion for review and withholds automatic downstream routing. DICOM, ZIP files passed directly as input, videos and proprietary camera containers require export/frame extraction first. EXIF orientation is not applied; export correctly oriented pixels when orientation matters.

## Behavior of each stage

1. `readFundus`: reads exported images or camera RGB arrays, checks encoding/range, retains original pixel data, and normalizes working data to single precision [0,1]. No geometry change or automatic rescaling of float input.
2. `assessFundusQuality`: isolates an estimated retinal field from dark background; measures field coverage/shape/centering, smoothed Laplacian focus, exposure/clipping, percentile contrast, low-frequency illumination variation, and a residual noise estimate. QA uses a maximum dimension of 768 pixels without upscaling. `gateFundusQuality` returns acceptable, borderline, or rejected with reason codes and capture feedback.
3. `enhanceFundus`: attempts only operations indicated by borderline measurements: blended bilateral luminance denoising, bounded illumination normalization, and blended CLAHE on LAB luminance. It preserves native size, feathers the field boundary and retains outside-field pixels. Reassessment uses the original field mask. Enhancement that increases clipping or leaves unresolved quality issues is withheld. Original borderline focus remains review-required; no sharpening is used to turn blur into a pass.

Passing images bypass enhancement. Rejected images receive recapture feedback. Borderline images retain a candidate even when it is unsuitable for automatic analysis. A low-resolution image is rejected rather than enlarged.

## Output contract for your team's stage 4

`r.status` is `acceptable`, `enhanced`, `rejected`, or `review_required`. Batch input/output failures are recorded as `error` rows.

```matlab
r = processFundus('image.jpg');
if r.routeToAnalysis
    imageForStage4 = r.image;     % native H x W x 3, single RGB [0,1]
    retinalField = r.mask;       % native H x W logical estimated field
    % Call your later lesion extraction module here.
else
    disp(r.message);             % recapture/review feedback
end
```

`r.original` retains supplied pixels (indexed files retain decoded RGB). `r.candidate` retains attempted enhancement for comparison. `r.before`/`r.after` hold quality measurements, gate states, reasons and reason codes. `r.operations`, `r.inputMetadata`, `r.config`, and `r.version` support auditing. `r.enhanced` means enhancement passed all provisional checks. `r.clinicalReady` is always false: this prototype has not undergone clinical validation.

Each run creates a new directory with `input_manifest.csv`, `configuration.mat`, and `summary.csv`. Progress is written after each image. Individual result folders contain:

- `quality.json`: measurements, routing, feedback, operation list, configuration.
- `retinal_mask.png`: estimated retinal field.
- `comparison.png`: original | field mask | candidate (or unchanged original); preview only.
- `analysis_image.png`: only for acceptable/enhanced images, native-size 16-bit RGB by default.
- `enhancement_candidate.png`: when enhancement was attempted, for review.
- `result.mat`: complete `r`, including original pixels and floating outputs.

JSON null means an unavailable/nonfinite metric, not zero. PNG export quantizes to the configured bit depth; MAT preserves the working numeric arrays. For large runs, `c.writeMAT=false` reduces storage, and `c.writePreview=false` reduces preview work. Do not disable MAT if you need originals preserved within result folders. Source files are never modified. Batch processing loads one image at a time; native high-resolution enhancement still needs sufficient memory.

## Validation and limitations

All quality cutoffs are provisional engineering defaults. Successful processing of an IDRiD image establishes software compatibility, not clinical quality accuracy. IDRiD disease grades and lesion masks are not labels for quality adequacy. Obtain reviewer labels for acceptable/borderline/ungradeable images, including portable-camera captures. Tune on patient/session-separated development data, freeze thresholds, then evaluate false acceptance of ungradeable images and unnecessary recapture on an independent test set.

Framing is a geometric proxy. It does not verify optic disc/fovea visibility, correct fixation, camera viewing angle or fundus authenticity. Noise and focus estimates depend on retinal texture, lesions, image scale and acquisition settings; downsampled QA can miss localized or very fine defects. A crop may pass, and an otherwise valid atypical camera field may fail. Later anatomical localization and acquisition metadata are needed to establish anatomical field of view. No automatic image-only quality gate can guarantee compatibility with every camera/domain without validation.

Enhancement changes pixel evidence. Native geometry is preserved, but lesion visibility, color and tiny-lesion contrast can change; no lesion-preservation claim is made. Compare the original and candidate, and evaluate downstream lesion performance before adopting enhancement. The >90% sensitivity / >85% specificity targets belong to later DR grading and are not claimed by this package.

`checkStage123` checks black/blurred inputs, routing, all three enhancement operations, native geometry/background preservation, invalid ranges, grayscale/indexed/alpha handling, uint16 input, IDRiD folder exclusions, manifests/datastores, duplicate names, corrupt-file handling, JSON/PNG/MAT persistence, and rejected-output withholding. Its temporary fixtures are removed after the run. `validateIDRiD` runs additional checks on your real extracted dataset and records measurements without assigning clinical ground truth.

See `VALIDATION.md` for tests actually completed in the authoring session.

## Sources

- [Official IDRiD data description](https://idrid.grand-challenge.org/Data/)
- [IDRiD repository](https://ieee-dataport.org/open-access/indian-diabetic-retinopathy-image-dataset-idrid)
- [MATLAB CLAHE](https://www.mathworks.com/help/images/ref/adapthisteq.html)
- [MATLAB bilateral filtering](https://www.mathworks.com/help/images/ref/imbilatfilt.html)
- [MATLAB Gaussian filtering](https://www.mathworks.com/help/images/ref/imgaussfilt.html)
