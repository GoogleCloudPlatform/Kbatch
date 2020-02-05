## Running example array jobs
This example of array jobs will run a image processing process on a group of images.
The input files are in array-image-input/ directory, named input_<index>.png.
These files will be copied into the pvc and an array job will be submitted to change each file into its grey image.
The output files are named output_<index>.png. They are copied from the remote to local machine at the end.

### Set up

1. At the parent of ./samples directory run

    `./samples/defaultresources/create.sh`

    This will create the default k8s CRDs that are needed by this example.
1. Ensure you have created a Filestore instance in this project. You will use the filestore IP and volume name in the next steps.
1. Go to arrayjob directory and run setup.sh:

    `./setup.sh`

    Type "y" when asked if you want to enable user to run as root. Script apply-extra-config.sh sets up the persistent volume resources and storage permissions.
1. Update ksub config to use the persistent volume claim created in step 2, in this example, pvc name is "pvc".

    `./ksub --config --add-volume fs-volume --volume-source PersistentVolumeClaim --params claimName:pvc --params readOnly:false`

4. Run copy-array-input.sh script to copy the provided input images (input_<index>.png) to the persistent
volume.

    `./copy-array-input.sh`


### Running the array job

`ksub ./run_array_image_ksub.sh`

### Expected result & Verifying success

The image array jobs will produce a group of results files. Each output file corresponds to the input file with the same array index
(with the env variable name KBATCH_ARRAY_INDEX).
The state of the BatchJobs can be examined by running `kubectl describe batchjob/imagearray`.
Once the the job is done, the output files will be produced under the array-image-data/ directory under the root directory of your pvc.
To copy the results to your local machine, run:

    ./copy-array-output.sh

The result output_<index>.png will be copied into ./array-image-data directory in your local machine.

### Running using kubectl
You can also run array jobs by using kubectl and the array-image.yaml file

`kubectl create -f array-image.yaml`
