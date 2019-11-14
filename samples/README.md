# Samples for Kbatch

## Base Resources

This defaultresources folder contains a set of base resources that can be used as a starting point for
running BatchJobs with KBatch. The following defaults are provided:

* BatchCostModel: Populated with current public GCE prices in us-central1
* BatchBudget: Populated to use at most 100 currency units per day
* BatchPriority: Three are created (Low, Medium, High)
* BatchJobConstraint: Restricts jobs to a wall time of less than 30 minutes
* BatchQueue: Set up to use the above BatchBudget, BatchPriority (High), and BatchJobConstraint
* BatchUserContext: restricted PSP

## Sample Jobs

We also provide a set of sample jobs that can be run in the folder computepi, imageprocess, and GPUjob.

### ComputePi

Estimates the value of Pi iteratively and prints the result to stdout.

### ImageProcess

A sequence of two image processing jobs, one dependent on the other, where the first job overlays a
checkerboard pattern on the image, and the second makes the image greyscale.

### GPUJob

A job that tests GPU vector addition.
