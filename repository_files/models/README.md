# Trained network

Place the trained model here with this exact name:

`trainedDRModel.mat`

The supplied project expects a MATLAB `DAGNetwork`, `SeriesNetwork`, or
`dlnetwork` with RGB input size 224 x 224 and five output classes ordered
0, 1, 2, 3, 4. The team's current model stores a `DAGNetwork` in the variable
`trainedNet` and uses the `zero_255` adapter with the network's stored
`zerocenter` input normalization.

The model is about 95 MB. GitHub's normal browser uploader cannot add a file
of this size to the repository. For a website-only upload:

```text
Repository → Releases → Draft a new release
Tag: v1.0.0
Compress the MAT file as: trainedDRModel.zip
Attach: trainedDRModel.zip
Publish release
```

After downloading the release asset, extract it and place
`trainedDRModel.mat` in this `models` folder before running `startHere`.

If the project is later maintained using GitHub Desktop or Git, the included
`.gitattributes` file is already configured for Git LFS.

The model file is intentionally absent from this generated package because
the original attachment is no longer present on the packaging machine. Copy
it from MATLAB Drive before pushing the repository.
