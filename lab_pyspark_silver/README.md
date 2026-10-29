# Lab: Bronze to Silver with Spark DataFrames & Iceberg

This repository contains the complete implementation and theoretical answers for the PySpark, Iceberg, and S3 lab.

---

## Theoretical Questions & Answers

### 1. SparkSession with S3 access

* **The credentials are temporary. What happens to a running Spark job if the service is restarted mid-lab, and why?**
  If the service restarts, the temporary STS credentials expire. A running Spark job will fail because it loses access to S3, as the authentication tokens are no longer valid.
* **Why does a plain `SimpleAWSCredentialsProvider` fail here, while it worked in setups without a session token?**
  A standard provider only looks for an Access Key and Secret Key. Because Onyxia uses temporary credentials that require an `AWS_SESSION_TOKEN`, we must use the `TemporaryAWSCredentialsProvider` to handle all three security parameters.

---

### 2. Silver layer

* **Explain the output of the code that was just run.**
  The SQL query aggregates user data by state, counts the total number of users per state, and counts how many users have a missing (null) city name.
* **Compare the DataFrame and SQL cells above. Which one would you choose for a one-off exploration, and which for a model reused by several colleagues? Why?**
  For a quick one-off exploration, Spark SQL is often easier and more readable. For a reusable production model, the DataFrame API is better because it is easier to modularize, test, and integrate into a robust object-oriented pipeline.
* **`regexp_extract()` returned an empty string instead of `NULL` on no match. Where else in this notebook could that same behavior silently produce a wrong result if left unhandled?**
  Any string manipulation or parsing function that returns empty strings instead of nulls can distort `GROUP BY` counts or aggregations, because empty strings are treated as valid groups rather than missing values.

---

### 3. Write the silver layer as Parquet

* **List the objects written under `silver/users.parquet/`. How many part-files are there, and why?**
  There are multiple part-files (one per Spark partition) because Spark writes data in parallel across multiple executors to scale performance.
* **`coalesce(1)` before `.write` would produce a single file. What do you lose by doing that on a larger dataset?**
  Using `coalesce(1)` forces all data to be processed by a single node, which destroys parallelism, creates a massive performance bottleneck, and can cause memory overflow errors on large datasets.

---

### 4. Write the silver layer as Iceberg tables

* **Compare `silver/orders.parquet/` and `warehouse/silver/orders/`. Which files hold the data, and which ones describe the table?**
  The `.parquet` files inside the `data/` folder hold the actual data, while the files inside the `metadata/` folder describe the schema, snapshots, and table structure.
* **A second job overwrites the Parquet directory while a query is reading it. What does the reader see? What changes with an Iceberg table?**
  With plain Parquet, a reader might see partial or corrupted data if files are modified mid-read. With Iceberg, transactions are atomic; readers continue to see the old valid snapshot until the new write is fully committed.
* **With this catalog, the pointer to the current version of a table is a file in the bucket. What can go wrong if two jobs commit at the same time, and what would a catalog service add?**
  Concurrent writes can cause race conditions and file conflicts. A catalog service adds centralized lock management and atomic pointer updates to prevent conflicts.

---

### 5. Compare with the dbt lab

* **What differs between the two schemas? Spark has no UUID type: what did you do about it, and what is the consequence for the consumers of the silver layer?**
  We cast UUIDs to standard `string` types. The consequence is that downstream consumers lose native UUID validation constraints and must handle them as regular text.
* **Compare the output layout: one object per model with dbt, one directory of part-files with Spark. Which one is easier for a consumer to read? Which one scales?**
  dbt's single file is easier for a human consumer to read directly. However, Spark's directory of part-files scales much better for massive distributed workloads.
* **The dbt lab validates the silver layer with tests. What did this lab use instead, and what would you need to write to get the same guarantees?**
  This lab used explicit Python assertions (`assert`) and manual counts. To get dbt-like guarantees, we would need to write dedicated data validation scripts or testing tools like Great Expectations.
* **`ref()` and `source()` give dbt the dependency graph. What plays this role in the notebook?**
  The sequential execution order of the cells in the notebook defines the dependency order.
* **Compare the build time between dbt and Spark. Why are they not directly comparable?**
  Spark includes heavy overhead from initializing the Java Virtual Machine (JVM) and loading external packages, which penalizes small datasets compared to a lightweight engine like DuckDB.
* **When to choose dbt with DuckDB vs Spark?**
  * *Daily batch of 10 GB:* dbt with DuckDB (simple, fast, single-node).
  * *Daily batch of 10 TB:* Spark (requires distributed processing).
  * *Team of analysts who only know SQL:* dbt with an SQL-based data warehouse.
