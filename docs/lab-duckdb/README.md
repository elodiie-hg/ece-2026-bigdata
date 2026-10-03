# Lab: SQL analytics with DuckDB

## 1. Setup
- Tool: DuckDB CLI v1.5.5, with a persistent S3 secret created by Onyxia
- Data: `bronze/users.csv` (50 users) and `bronze/orders.csv` (2829 orders) in my bucket `user-e-huang-ece`
- An `init.sql` file sets a `bucket` variable and the UTC time zone

## 2. What I did
- **Read CSV on S3**: `read_csv`, `sniff_csv`, `DESCRIBE` and `SUMMARIZE` without loading the file.
- **Tables**: loaded `users` (50 rows) and `orders` (2829 rows) from 2020-01-01 to 2020-04-27.
- **Quality checks**: 0 orphan orders, 0 inactive users, 0 duplicated order IDs (ANTI JOIN and GROUP BY).
- **Analytics**: aggregations by product and month, top 5 customers, age groups, cumulative sum and 7-day moving average, best product per month (`QUALIFY`), and a `PIVOT`.
- **Exercises**: average orders per user (about 56.6), first/last order per user, best hour, month-over-month change with `lag`, and users who ordered all products (45 of 50).
- **Parquet**: exported `orders` to Parquet and read the metadata in the footer.
- **Hive partitioning**: one folder per product. A filter on `product = 'cookie'` read 1 file out of 6.
- **CSV vs Parquet**: see the table below.
- **Python**: `orders_report.py` runs a DuckDB query with a query parameter (no SQL injection) and prints monthly orders. Command: `uv run orders-report`.

## 3. CSV vs Parquet (my results)
| | CSV | Parquet |
|---|---|---|
| File size | 28.2 MiB | 11 MiB |
| Data read for `GROUP BY product` | 28.2 MiB | 203.5 KiB |
| Time for this query | 1.24 s | 0.30 s |
| Data read with filter `date >= '2100-01-01'` | n/a | 16 KiB |

The Parquet file has 3 row groups. The filter skips all 3, because the maximum date of each one is before 2100.

## 4. Problems and solutions
- **`InvalidAccessKeyId` in DuckDB**: the S3 secret was created when the service started and the temporary credentials had expired. I restarted the service to get new credentials.
- **Pasting several queries**: the terminal merged them on one line. I pasted one query at a time.
- **`s5cmd` not found**: the new service did not have it. I used `aws s3 cp` instead.
- **Smaller large file**: my file had about 252,000 rows (29 MB), so my numbers are smaller than the numbers in the lab.

## 5. Answers to the questions
1. **Risks of a persistent secret in the home directory?** Any process running as my user can read it, and it can leak in backups or a copied folder. On Onyxia the risk is limited because the credentials are temporary and only give access to my own bucket.
2. **Restrict S3 access for a Kubernetes Job?** Give the Job its own identity (service account with a minimal IAM role) or a dedicated Secret with a read-only access limited to the needed prefix.
3. **Why 40 and 3167 for `approx_unique`?** It is an estimate (HyperLogLog): fast and light in memory, but not exact. The real values are 50 and 2829.
4. **Issue with a large file whose first rows are not typical?** DuckDB guesses the types from a sample. It may choose a wrong type (for example integer instead of text) and fail later in the file.
5. **Why is `uuid` barely compressed?** The IDs are random and all different, so there is no repetition to compress.
6. **Why are some columns bigger after compression?** On small data, the format overhead is bigger than the gain.
7. **Why not partition by `uuid`?** It creates one file per order: thousands of tiny files, and each file costs a request on object storage.
8. **Which partition column for orders growing every day?** The date (for example year and month, or day).
9. **If orders were shuffled?** Each row group would contain dates from the whole period, so no row group could be skipped.
10. **CSV vs Parquet time?** Parquet is about 4 times faster. Part of the gap is the network (28 MiB vs 200 KiB), part is CSV parsing (text converted row by row, while Parquet columns are typed and compressed).
