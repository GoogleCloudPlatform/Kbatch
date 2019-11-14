## Running the gpu job

To run any GPU jobs, you must ensure that you have at least one node pool attached to the cluster that has enabled
GPU support--this option can be chosen when setting up the cluster using the Kbatch scripts.
You must also ensure that you run
`kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/container-engine-accelerators/stable/nvidia-driver-installer/cos/daemonset-preloaded.yaml`
so that GPU device drivers are installed whenever a new node that supports GPU is brought up.
As with the other samples, the `defaultresources/create.sh` script will set up default resources, which are needed for this sample job.

### Running using ksub

`./ksub run_gpu_with_ksub.sh`

ksub supports listing a specific GPU, so ensure the GPU shown in the .sh file matches a GPU type that you set up
in your cluster.

### Running using kubectl

`kubectl create -f gpu-job.yaml`

Ensure the GPU shown in the .yaml file matches a GPU type that is available in your autoscaler zone.

### Timing notes

Note that in some cases, it may take several minutes before the job runs, as scaling up the GPU node pool
involves not only initializing the node, but also installing the nVidia drivers on the node (per the kubectl apply command
in the first section of this file).

### Verifying success

The state of the BatchJob can be examined by running `kubectl describe batchjob/<job>` where the job name is shown when
calling create above. Once the BatchJob Phase says "Succeeded", then the job has correctly run. To further verify, look
at the logs of the Pod that was created by the BatchJob (should be named with the same prefix as the BatchJob).

To view logs:

Using ksub, get the task name from the job name using -Ga, and then use that task name to view the logs.
  1. `./ksub -Ga <job_name>`
  1. `./ksub -L <task_name>`
  
Using kubectl:
  1. `kubectl logs pod/<name of pod>`

The output should look similar to this:

```
[Vector addition of 50000 elements]
 Copy input data from the host memory to the CUDA device
 CUDA kernel launch with 196 blocks of 256 threads
 Copy output data from the CUDA device to the host memory
 Test PASSED
 Done
```

### Re-running

The job can be re-run as desired. A randomized suffix is added to the name of the BatchJob each time.

### [Optional] Building the containers

This folder contains a Dockerfile. If you wish to build your own container rather than
relying on the containers provided in gcr.io, you can do so easily. The Dockerfile allows you to rebuild the docker image and upload to
a repository of your choice (replace the `image` value in `gpu-job.yaml` with the path of your image).

To build the image, install docker and then run `docker build -f Dockerfile -t <image path> .` followed by
`docker push <image_path>`. One example of an `image_path` is `gcr.io/kbatch-images/cuda-vector-add/cuda-vector-add:latest`
