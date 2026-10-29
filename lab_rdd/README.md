# ECE Big Data - PySpark RDD Lab

## 1. Theoretical Questions & Answers

### What is an RDD?
An RDD (**Resilient Distributed Dataset**) is the fundamental data structure of Apache Spark. It is a distributed collection of items partitioned across the nodes of a cluster that can be processed in parallel. RDDs are immutable (read-only) and fault-tolerant.

### What is the difference between Transformations and Actions?
- **Transformations** (e.g., `map`, `filter`, `repartition`) create a new RDD from an existing one. They are **lazy**, meaning Spark does not compute them immediately. They only build a logical execution plan (lineage graph).
- **Actions** (e.g., `count`, `collect`, `take`, `first`) trigger the actual execution across the cluster to compute results and return data to the driver program.

### What is the difference between `reduceByKey` and `groupByKey`?
- **`reduceByKey`** combines values for each key on each partition *before* shuffling data across the network. It is much more efficient and recommended for large datasets.
- **`groupByKey`** shuffles all values associated with each key across the network to a single reducer node without pre-aggregating. This consumes more memory and network bandwidth.

---

## 2. Lab Implementation Script (`lab_rdd.py`)

Here is the Python script developed during the interactive session:

```python
from pyspark.sql import SparkSession
from operator import add

# 1. Initialize Spark Session and Context
spark = SparkSession.builder.appName("lab-rdd").master("local[*]").getOrCreate()
sc = spark.sparkContext
sc.setLogLevel("ERROR")

# 2. Load text files into RDDs
users_lines = sc.textFile("users.csv")
orders_lines = sc.textFile("orders.csv")

# 3. Filter header and parse orders
header = orders_lines.first()
orders_data = orders_lines.filter(lambda line: line != header and line.strip() != "")

# Parse order lines into dictionaries
parse_order = lambda line: dict(zip(
    ["order_id", "user_id", "date", "quantity", "product"],
    [line.split(",")[0], line.split(",")[1], line.split(",")[2], int(line.split(",")[3]), line.split(",")[4].strip().lower()]
))

orders_rdd = orders_data.map(parse_order).cache()

# 4. Key-Value Aggregation with reduceByKey
user_quantity = orders_rdd.map(lambda o: (o["user_id"], o["quantity"])).reduceByKey(add)
print("reduceByKey result:", user_quantity.collect())

# 5. Join orders with users
def parse_user(line):
    fields = line.split(",")
    return fields[0], fields[1] # user_id, username

users_kv = users_lines.map(parse_user)
orders_kv = orders_rdd.map(lambda o: (o["user_id"], o))

enriched = orders_kv.join(users_kv)
print("Join result:", enriched.collect())

exit()

# 1. Créer le dossier et le fichier README avec les réponses
mkdir -p lab_rdd
cat << 'EOF' > lab_rdd/README.md
# ECE Big Data - PySpark RDD Lab: Theoretical Questions

### What is an RDD?
An RDD (**Resilient Distributed Dataset**) is the fundamental data structure of Apache Spark. It is a distributed collection of items partitioned across the nodes of a cluster that can be processed in parallel. RDDs are immutable (read-only) and fault-tolerant.

### What is the difference between Transformations and Actions?
- **Transformations** (e.g., `map`, `filter`, `repartition`) create a new RDD from an existing one. They are **lazy**, meaning Spark does not compute them immediately. They only build a logical execution plan (lineage graph).
- **Actions** (e.g., `count`, `collect`, `take`, `first`) trigger the actual execution across the cluster to compute results and return data to the driver program.

### What is the difference between `reduceByKey` and `groupByKey`?
- **`reduceByKey`** combines values for each key on each partition *before* shuffling data across the network. It is much more efficient and recommended for large datasets.
- **`groupByKey`** shuffles all values associated with each key across the network to a single reducer node without pre-aggregating. This consumes more memory and network bandwidth.
