# Lab: Govern Iceberg tables with Polaris

This README contains my answers to the questions of the Polaris lab. I ran all the commands on the Onyxia platform. The results below come from my own outputs.

## 1. SparkSession with the Polaris catalog

**Which component answered each `SHOW NAMESPACES` command? How can you tell?**

- `SHOW NAMESPACES IN lab` was answered by the Iceberg Hadoop catalog. Spark read the table folders directly in the S3 bucket. The result was one namespace: `silver`.
- `SHOW NAMESPACES IN polaris` was answered by Polaris, through the Iceberg REST API. The result was empty, because no table was registered in Polaris yet.
- I can tell the difference because the two catalogs are configured differently (`type = hadoop` for `lab`, `type = rest` with the Polaris URI for `polaris`). Also, the two answers are different, so they come from two different places.

**Where is the credential used: in the Spark session, in the bucket, or in a request to Polaris?**

The Polaris credential (`clientId:clientSecret`) is used in the requests to Polaris. Spark sends it to the Polaris token endpoint and gets an access token. The token is then sent with every REST call. The credential is not used for the bucket. The bucket uses the separate S3 keys (`AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`) that are set in the Spark session.

## 2. Register the Silver table in Polaris

The current metadata file was `v3.metadata.json` (the file `version-hint.text` contained `3`). I registered it with `register_table` as the `dev` principal.

Results:

| Check                                 | Result |
| ------------------------------------- | ------ |
| `count(*)` on `lab.silver.orders`     | 2830   |
| `count(*)` on `polaris.silver.orders` | 2830   |

The lab says 5,000 orders, but my table has 2,830 orders. Both catalogs give the same number, so the registration is correct.

**What did `register_table` write, in Polaris and in the bucket?**

- In Polaris: a new table entry that points to `v3.metadata.json`.
- In the bucket: nothing. There were 13 objects under `warehouse/silver/orders/` before the registration and 13 after.

**Why is it dangerous to keep writing to this table through the `lab` catalog?**

The two catalogs keep their own pointer to the table metadata. If I write through `lab`, the Hadoop catalog creates a new metadata version and moves only its own pointer. Polaris still points to the old version (`v3`). Then the two catalogs show different data for the same table. This is why I should write only through Polaris after the registration.

## 3. Create tables as `dev`

The `polaris.silver.orders` table has 3 snapshots: two `overwrite` and one `append`. I created `polaris.silver.users` from `lab.silver.users`. It has 50 users.

**Where did Polaris store the files for `silver.users`, and why?**

Polaris stored them in `s3://<bucket>/warehouse/silver/users/`. Polaris builds the path from the base location of the catalog (`s3://<bucket>/warehouse/`), the namespace (`silver`) and the table name (`users`). This is the same folder as the `lab.silver.users` table from the Spark lab. In this folder I can see:

- `v1.metadata.json`: from the Hadoop catalog (Spark lab).
- `00000-...metadata.json` and `00001-...metadata.json`: from Polaris.
- two parquet files in `data/`: one for each catalog.

**What is the difference between "registered" and "created through Polaris" for the data files?**

- A registered table keeps its files where they already are. Polaris only stores a pointer to the metadata file. It does not create any file.
- A table created through Polaris is built by Polaris. The metadata and the data files are written at the location that Polaris chooses.

## 4. Schema change as `dev`

I ran `ALTER TABLE polaris.silver.users ADD COLUMN country STRING`. The `DESCRIBE` command shows the new `country` column.

**Which metadata file records the change? Is it the same file that `register_table` pointed to?**

The change is recorded in a new metadata file: `00001-2f5d2894-...metadata.json`, created at 12:48:38. It is not the file that `register_table` pointed to. `register_table` pointed to `v3.metadata.json` of the `orders` table, which is another table. Each commit creates a new metadata file, and Polaris moves its pointer to it.

The `lab` catalog does not see the new column, because it still points to `v1.metadata.json`.

**Which privilege does Polaris check for this statement?**

Spark sends a commit request to Polaris. Polaris checks the operation `ADD_TABLE_SCHEMA`, which needs a write privilege on the table. The `dev` principal has this right through `CATALOG_MANAGE_CONTENT` in the `catalog_contributor` role.

## 5. Read as the analyst

With the `analyst` principal:

- `SHOW TABLES IN polaris.silver` works and lists `orders` and `users`.
- The `GROUP BY product` query on `orders` works. The counts add up to 2,830 rows.
- `INSERT INTO polaris.silver.orders ...` fails with `ForbiddenException`. The error says that the principal is not authorized for the operation `ADD_TABLE_SNAPSHOT`.
- `ALTER TABLE polaris.silver.users ADD COLUMN phone STRING` fails with `ForbiddenException`. The error says that the principal is not authorized for the operation `ADD_TABLE_SCHEMA`.

The error messages also show that `analyst` only has the grants from `data_analyst` and `catalog_reader`.

**Which privilege is missing for the `INSERT`? Which privileges does `catalog_reader` provide?**

The missing privilege is the right to write data to the table (`TABLE_WRITE_DATA`). The `catalog_reader` role provides:

- `TABLE_READ_DATA`
- `TABLE_READ_PROPERTIES`
- `CATALOG_READ_PROPERTIES`

**Did the failed `INSERT` create a snapshot?**

No. I checked as `dev` after the failure. `polaris.silver.orders` still has the same 3 snapshots with the same ids. Polaris refused the commit, so no new snapshot was created.

## 6. What Polaris enforces, and what it cannot enforce

- Polaris enforces the rules on catalog operations: listing tables, reading metadata, and committing changes. When `analyst` tried to write, Polaris refused the commit.
- Polaris cannot control direct access to the files in S3. In this lab, Spark reads and writes the files with the shared S3 keys (there is no credential vending). Anyone who has these keys can read or change the files in the bucket without asking Polaris.
- So the permissions in Polaris are useful, but they do not replace the security of the storage.

## 7. Commit the Iceberg metadata

I downloaded only the metadata files from the bucket with `aws s3 sync`, using `--include "*/metadata/*"`. Then I committed the metadata of `silver/orders` and `silver/users` to the Git repository.

## Summary of the results

| Item                                                             | Value                              |
| ---------------------------------------------------------------- | ---------------------------------- |
| Orders in `lab` and `polaris`                                    | 2830 (same)                        |
| Users in `polaris.silver.users`                                  | 50                                 |
| Snapshots of `silver.orders`                                     | 3 (before and after failed insert) |
| Objects under `silver/orders/` before and after `register_table` | 13 and 13                          |
| `analyst` read                                                   | allowed                            |
| `analyst` insert and alter                                       | `Forbidden`                        |
