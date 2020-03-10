## Running the compute-pi job

The `defaultresources/create.sh` script will set up default resources, which are needed for this sample job.

### Preemptible option

There is both a regular version and a preemptible version of this example. The preemptible
version will be run on preemptible virtual machines. To use the preemptible version, replace
run_pi_with_ksub.sh with run_pi_preemptible_with_ksub.sh below (or, if using kubectl, replace
pi-job.yaml with pi-job-preemptible.yaml)

### Running using ksub
`./ksub run_pi_with_ksub.sh`

### Running using kubectl
`kubectl create -f pi-job.yaml`

## Expected result

The compute-pi job will compute an approximate value of Pi and write it the Pod's log (each BatchJob has
an associated Pod).

## Verifying success

To examine the log to verify success, one can look at the Pod associated with the BatchJob.
This pod is named with a prefix of the BatchJob. Running
`kubectl get pods | grep <name of BatchJob from output of create command above>` will provide the name
of the Pod.

To view logs:

Using ksub, get the task name from the job name using -Ga, and then use that task name to view the logs.
  1. `./ksub -Ga <job_name>`
  1. `./ksub -L <task_name>`
  
Using kubectl:
  1. `kubectl logs pod/<name of pod>`

For example, if the BatchJob created by the `kubectl create` command was `batchjob.kbatch.k8s.io/pi-dsqdr` then
one should run `kubectl get pods | grep pi-dsqdr`. This will return a Pod named similarly to
`pi-dsqdr.task-default-0.0-abcde`. Then, the correct command to view the Pod logs would be
`kubectl logs pod/pi-dsqdr.task-default-0.0-abcde`.

## Re-running

The job can be re-run using either `ksub` or `kubectl` as shown above as many times as desired. The system
will pick a new random suffix to add to the name of the BatchJob each time.

## [Optional] Building the container

This folder contains `Dockerfile` and `pi.go`. If you wish to build your own container rather than
relying on the container provided in gcr.io, you can do so easily. These allow you to rebuild the docker image and upload to
a repository of your choice (replace the `image` value in `pi-job.yaml` with the path of your image)

To build the image, install docker and then run `docker build -t <image path> .` followed by
`docker push <image_path>`. One example of an `image_path` is `gcr.io/kbatch-images/generate-pi/generate-pi:latest`
