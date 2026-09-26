# Validation record — 17 September 2026

## Completed locally

- Inspected the downloaded IDRiD segmentation archive and its nested `Original Images`, training/testing, and ground truth layout.
- Decoded every original JPEG: 83 files (56 training-folder entries, 27 testing-folder entries), all RGB at 4288 × 2848 pixels.
- Compared file hashes: 81 unique originals. `IDRiD_23(1).jpg` and `IDRiD_25(1).jpg` are duplicate copies in this download. No source files were changed.
- Reviewed MATLAB entry points, helper dependencies, configuration schema, native-size routing, exception handling and output contract.
- Verified packaged-file integrity and documented entry points with local static checks (see the accompanying audit below).

## User-run regression and manifest fix (v1.0.1)

The user's MATLAB Online R2026a run reached the single-column CSV manifest
test at checkStage123 line 81, then failed because automatic CSV import did
not produce an ImagePath variable. Assertions before that line completed in
that run; later assertions and real-dataset processing were not reached.

The manifest reader now specifies text input, comma delimiter, first-row
variable names, zero skipped header lines, preserved names, and string text.
Added regressions check the exact path after a single-column/single-row import,
multirow single-column import, extra CSV columns, and quoted commas in paths.
This change has been statically checked and packaged but has not yet been
rerun in MATLAB. Run startHere again after installing the updated files.

## Not executed by the author

The user requested files to execute in MATLAB themselves. No MATLAB regression, live-image pipeline, batch run, or clinical quality validation is claimed as completed. MATLAB Online was visible as R2026a, but no test commands were successfully executed through browser control. No desktop MATLAB installation was found.

## Run these in MATLAB Online

```matlab
unzip('matlab_stage123.zip');
cd('matlab_stage123');
startHere
```

`startHere` checks dependencies and runs `checkStage123`. The expected last test message is:

```
All stage 1-3 engineering regression checks passed.
```

Next run:

```matlab
[audit,summary,runDir] = validateIDRiD('/MATLAB Drive/datasets/IDRiD');
```

This processes five original images by default. Run all originals with:

```matlab
[audit,summary,runDir] = validateIDRiD( ...
    '/MATLAB Drive/datasets/IDRiD', ...
    '/MATLAB Drive/stage123_results',Inf);
```

The dataset path must refer to your actual extracted folder. Compatibility success means input decoding, output dimensions/ranges, routing invariants and file persistence work. Rejection or review-required status can be a valid pipeline result; it is not an execution failure or proof of clinical inadequacy.

## Clinical validation still required

Quality thresholds, retinal framing proxies, enhancement, and downstream lesion preservation require reviewer-labeled camera-specific development and independent test data. Software regression checks and successful IDRiD loading do not establish clinical gradability, safety, DR sensitivity/specificity, or clinical deployment readiness.
