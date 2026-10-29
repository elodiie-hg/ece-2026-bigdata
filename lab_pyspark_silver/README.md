# ECE Big Data - PySpark & Iceberg Silver Layer Lab

## Overview
This lab covers the transition from the bronze layer (raw CSVs on S3) to the silver layer using **PySpark DataFrames**, **Spark SQL**, and **Apache Iceberg**, comparing its approach with the previous dbt lab.

## Key Concepts & Answers
- **Spark Session & S3 Access:** Uses temporary STS credentials via `TemporaryAWSCredentialsProvider`.
- **DataFrames vs Spark SQL:** Both compile down to the same Catalyst execution plan. Window functions handle deduplication robustly.
- **Parquet vs Iceberg:** Parquet writes as a directory of part-files without atomic guarantees for concurrent readers, whereas Iceberg adds metadata snapshots for ACID transactions.
