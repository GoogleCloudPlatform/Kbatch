## Running the image-process job

### Set up

1. Ensure you have created a Filestore instance in this project.
2. Run the `sample/apply-config.sh` script. It sets up default resources, which are needed for this sample job.
Type "y" when asked if you want to enable user to run as root. Script apply-extra-config.sh sets up the persistent volume resources and storage permissions.
3. Update ksub config to use the persistent volume claim created in step 2. PVC_NAME is the name of PVC created in step 2.
./ksub --config --add-volume fs-volume --volume-source PersistentVolumeClaim --params claimName:[PVC_NAME] --params readOnly:false
4. Run `copy-input.sh` script to copy the provided input image (cloud.png) to the persistent
volume. This image is the input file of this job.

### Running using ksub

`./ksub run_checkerboard_with_ksub.sh`

Take note of the outputted job name (should be checkerboard-<random_string>) and then immediately run the
following command, filling in that job name as the dependency.

`./ksub --dependency Success:<job_name> -- run_grey_with_ksub.sh`

### Running using kubectl

`kubectl apply -f imageprocess-job.yaml`

### Expected result

The imageprocess job will run two BatchJobs (the second dependent on the first). The first transforms the
input image by adding a checkerboard pattern to the image. Once that BatchJob succeeds, the second runs
and transforms the image into greyscale.

### Verifying success

The state of the BatchJobs can be examined by running `kubectl describe batchjob/checkerboard` and `kubectl describe batchjob/grey`.
Note that if examining status with ksub, these job names will have a random string appended to the end of each.
Also, running `kubectl get pods` should show two Pods with a Status of Completed (one starting with `checker-`, and
another starting with `grey-`). The script `copy-output.sh` will copy the final output from the persistent volume
to the local machine.

### Re-running

Before re-running the job using kubectl, both BatchJobs must be deleted from the system, as the names are not randomized.
The job can then be re-run using `kubectl` as shown above.
This step is not necessary if running with `ksub`.

### [Optional] Building the containers

This folder contains two Dockerfiles and the two subfolders contain one Go file each. If you wish to build your own containers rather than
relying on the containers provided in gcr.io, you can do so easily. These Dockerfiles allow you to rebuild the docker images and upload to
a repository of your choice (replace the `image` values in `imageprocess-job.yaml` with the paths of your images)

To build the image, install docker and then run `docker build -f Dockerfile.<extension> -t <image path> .` followed by
`docker push <image_path>`. One example of an `image_path` is `gcr.io/kbatch-images/checkerboardimage/checkerboardimage:latest`
