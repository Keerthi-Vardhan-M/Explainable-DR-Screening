# Authoring record

## Confirmed evidence

- The user ran the stage-1–3 regression checks successfully in MATLAB Online R2026a.
- The user processed five actual IDRiD originals: four passed after illumination normalization and one was review-held for original borderline focus.
- The attached `trainedDRModel (1).mat` was read as MATLAB MAT v5 metadata: it contains an MCOS DAGNetwork stored as `trainedNet`. Numerical forward inference was not executed locally.
- The local IDRiD B archive has 517 original-image file entries. Training/testing grading CSVs use Image name and Retinopathy grade columns and reset image IDs across splits.
- Full-project files were checked for entry-point names, helper/config references, and ZIP content integrity locally.

## Not yet confirmed

The newly added full-project MATLAB code, interface rendering, model inference,
Grad-CAM, PDF layout, random-forest training/calibration/validation, and generated
Simulink compilation/execution have NOT been run by the author. The user prefers
to execute files themselves in MATLAB. Run checkFullDRDemo, a real model case,
and checkSimulinkDemo before relying on the demonstration.

The model's exact training preprocessing and held-out APTOS performance were
not provided. Use the empirical adapter comparison or recover training code.
No clinical segmentation/quality/explainability validation is claimed.

## Required rehearsal checks

1. setupDRDemo prints DAGNetwork, 224 x 224 x 3 input and classes 0–4.
2. checkFullDRDemo completes all smoke checks and creates valid PDFs internally.
3. verifyDRPreprocessing completes the declared adapter comparison on training labels.
4. runDRCase on an acceptable original returns a real prediction and a Grad-CAM map, or a specific actionable explanation if Grad-CAM is unsupported.
5. launchDRDemo renders all six panels; save review and export PDF complete.
6. Open the generated PDF and inspect both pages, including text legibility.
7. checkSimulinkDemo generates, compiles and runs the four-queue model.
8. Prepare saved cases and a backup workflow figure for the presentation.
