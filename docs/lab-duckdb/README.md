# Lab: SQL analytics with DuckDB - Answers

## S3 configuration

**1. What are the risks of a persistent secret in the home directory? Why are they limited on Onyxia?**
The secret is saved in a file in my home directory. Any program running as my user can read it. It can also leak in a backup. On Onyxia, the risk is small. The credentials are temporary and only give access to my own bucket.

**2. How would you restrict the S3 access for a Kubernetes Job?**
I would give the Job its own identity, for example a service account with a minimal role. The role would allow only what the Job needs, like read-only access to `bronze/`.

## Query the bronze layer

**3. Why does `approx_unique` return 40 and 3167?**
It is an estimate, not an exact count. DuckDB uses an algorithm that is fast and light, but not exact. The real values are 50 and 2829.

**4. Which issue may occur with a large file whose first rows are not representative?**
DuckDB guesses the types from a sample of the file. If the sample is not typical, it can choose a wrong type. The query then fails later in the file.

## Parquet export

**5. Why is the `uuid` column barely compressed?**
The identifiers are random and all different. There is no repetition, so the compression cannot reduce the size.

**6. Why is the compressed size of some columns larger than the uncompressed size?**
The data is very small. The compression adds a small overhead. When the data has no pattern, the overhead is bigger than the gain.

## Hive partitioning

**7. Why is partitioning by `uuid` a bad idea?**
Each `uuid` is unique. We would get one file per order, so thousands of tiny files. On object storage, each file needs a request, and requests are slow. The queries would be very slow.

**8. Which partition column for orders growing every day?**
I would choose the date, for example year and month. New data goes into new partitions. Most queries filter on a period, so DuckDB can skip the other partitions.

## CSV vs. Parquet at scale

**9. How many row groups are there, and how many are skipped by the filter `date >= '2100-01-01'`?**
My file has 3 row groups. The filter skips all 3. The latest date in the file is in 2048, so no row group can match.

**10. What if the orders were shuffled?**
Each row group would contain dates from the whole period. No row group could be skipped. DuckDB would have to read all of them.

**11. Compare the execution time of CSV and Parquet. What is due to the network, and what to the CSV parsing?**
The CSV query took 1.24 s and the Parquet query 0.30 s. Parquet is about 4 times faster. For the network, CSV downloads 28.2 MiB, but Parquet only 203.5 KiB. For the parsing, DuckDB must read the CSV text and convert every value. Parquet columns are already typed and compressed.
