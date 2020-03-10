### Example of image processing job using gcs as input/output

1. Create a test gcs bucket in your project, replace [BUCKET_NAME] with a name that is unique.

    <pre>
    gsutil mb gs://[BUCKET_NAME]/
    </pre>

1. Copy the input file to this gcs bucket

    <pre>
    gsutil cp ./cloud.png gs://[BUCKET_NAME]/
    </pre>
    check if the file has been uploaded successfully.

1. Create a kubernetes service account in default name space

    <pre>
    kubectl create serviceaccount --namespace default kbatch-gcs-example-k8s-sa
    </pre>

1. [If you are the cluster admin, you can skip this step] Set up RBACS to use this service account

    First edit the gcs-example-rbac.yaml file, replace [your_alias] and [your_domain] with your information; then
    <pre>
    kubectl apply -f gcs-example-rbac.yaml
    </pre>
    Check that the role and role bindings has been created by using:
    <pre>
    role.rbac.authorization.k8s.io/kbatch-gcs-example-role created
    rolebinding.rbac.authorization.k8s.io/kbatch-gcs-example-rb created
    </pre>

1. Create a gcp service account and prepare the permissions

   <pre>
   gcloud iam service-accounts create kbatch-gcs-example-sa --display-name \
    kbatch-gcs-example-serviceaccount

    gcloud projects add-iam-policy-binding [PROJECT_ID] \
    --member serviceAccount:kbatch-gcs-example-sa@[PROJECT_ID].iam.gserviceaccount.com \
    --role=roles/storage.objectCreator

    gcloud projects add-iam-policy-binding [PROJECT_ID] \
    --member serviceAccount:kbatch-gcs-example-sa@[PROJECT_ID].iam.gserviceaccount.com \
    --role=roles/storage.objectViewer

    gcloud projects add-iam-policy-binding [PROJECT_ID] \
    --member serviceAccount:kbatch-gcs-example-sa@[PROJECT_ID].iam.gserviceaccount.com \
    --role=roles/iam.serviceAccountUser

    gcloud iam service-accounts add-iam-policy-binding \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:[PROJECT_ID].svc.id.goog[defaullt/kbatch-gcs-example-k8s-sa]" kbatch-gcs-example-sa@[PROJECT_ID].iam.gserviceaccount.com
   </pre>

1. Annotate the kubernetes service account

    <pre>
    kubectl annotate serviceaccount --namespace default kbatch-gcs-example-k8s-sa \
    iam.gke.io/gcp-service-account=kbatch-gcs-example-sa@[PROJECT_ID].iam.gserviceaccount.com
    </pre>

1. Change the imageprocess-gcs-job.yaml file, replace [test-gcs-bucket] with the gcs bucket just created

    <pre>
    command: ["./gcs-example.sh", "[test-gcs-bucket]"]
    example: ["./gcs-example.sh", "my-test-bucket"]
    </pre>

1. Submit the job

   <pre>
   kubectl apply -f imageprocess-gcs-job.yaml
   </pre>

1. Check the gcs bucket again, a file named checker-xxx.png should appear if job is successful.

1. Don't forget to clean up after this test

   delete rbacs:
   <pre>
   kubectl delete -f gcs-example-role.yaml
   </pre>
   delete gcp service account:
   <pre>
   gcloud iam service-accounts delete kbatch-gcs-example-sa@[your-project].iam.gserviceaccount.com
   </pre>
   delete the gcs bucket:
   <pre>
   gsutil rm -r gs://[BUCKET_NAME]
   </pre>