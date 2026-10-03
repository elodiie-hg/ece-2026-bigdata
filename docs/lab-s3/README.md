# Lab: Object storage with S3

## 1. Setup
- Storage: SeaweedFS, an S3-compatible service (`https://s3.seaweedfs.adm.adaltas.cloud`)
- AWS profile: `default`
- My bucket: `user-e-huang-ece`
- Tools: `aws s3`, `aws s3api` and `s5cmd` (v2.3.0)

## 2. What I did
- **Basic commands**: I uploaded, listed, downloaded, renamed and deleted a file. The downloaded file was identical to the original (checked with `diff`).
- **Metadata**: for a simple upload, the ETag is the MD5 hash of the file (I compared it with `md5sum`). I also added my own metadata (`source`, `version`, `rows`) and read it with `head-object`.
- **Presigned URLs**: I created a download URL that works for 5 minutes. I tested it with `curl` and no credentials. I also generated an upload (PUT) URL with boto3.
- **Multipart upload**: I uploaded a 200 MB file. The ETag ends with `-25`, so the file was sent in 25 parts of 8 MB.
- **Versioning**: after enabling versioning, I had 3 versions of `bronze/users.csv`. One version has the ID `null`: it is the file I uploaded before enabling versioning. After `rm`, S3 only added a delete marker. The old versions were still there and I could download the first one.
- **Lifecycle**: I applied 3 rules: delete objects in `large/` after 30 days, delete old versions after 7 days, and abort incomplete multipart uploads after 7 days.
- **Bucket policy**: I added a policy that denies `s3:DeleteObject` on `bronze/*`. My `rm` command failed with `AccessDenied`, so the policy works. Then I removed the policy.
- **ACL**: I only read the ACL. There is one permission: `FULL_CONTROL` for `admin`.
- **Consistency**: I could read a file right after uploading it. This is strong read-after-write consistency.
- **Cleanup**: I deleted all versions and delete markers, suspended versioning and removed the lifecycle rules.

## 3. Kubernetes Job
A Job uploads the datasets to the bronze layer. The datasets come from a ConfigMap and the credentials come from a Secret. The Job ran successfully. The bucket now contains:
- `bronze/users.csv` (7351 bytes)
- `bronze/orders.csv` (331568 bytes)

The file is `job-upload-bronze.yaml`.

## 4. Problems and solutions
- **`must specify limits.cpu`**: the namespace quota requires a CPU limit. I added `cpu: 200m` to the `limits` section.
- **`field is immutable`**: a Job cannot be changed after creation. I had to delete it and create it again.
- **`InvalidAccessKeyId`**: the Secret contained old temporary credentials that had expired. I created the Secret again with new credentials.
- **Full quota**: after several launches, my namespace quota was full and I could not start a new service. I must keep only one service at a time.

## 5. Answers to the questions
1. **Why use a Secret and not a ConfigMap for credentials?**
   A Secret is made for sensitive data. Access can be restricted with RBAC, it can be encrypted at rest, and its values are hidden in tools. A ConfigMap is plain text and more people can read it.
2. **What happens if the Job runs again tomorrow?**
   The Onyxia credentials are temporary, so they will be expired and the Job will fail. I had this problem (`InvalidAccessKeyId`). In production, we can give an identity to the workload (a service account with an IAM role, for example IRSA) or use a secret manager with automatic rotation (Vault, External Secrets).
3. **How to make a daily ingestion?**
   Replace the Job with a CronJob and add a `schedule`, for example `"0 2 * * *"` to run every day at 2 AM.
