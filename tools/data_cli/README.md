# Loading data into the Key/Value server

There are two ways to populate data in the server.

-   The standard path is by uploading files to a cloud file storage service. The standard upload is
    the authoritative, high bandwidth and persistent source of truth.
-   The other way is via a low latency path. To apply such an update, you should send an update to a
    dedicated broadcast topic.
    
# Using the CLI tool to generate delta and snapshot files 

Run the following to see a list of all available commands and their input arguments:


## Prerequisites
- Docker must be installed and running.
- Make the script executable:
  ```sh
  chmod +x data_cli.sh
  ```

## Usage
Run the script with one of the following commands:

### 1. Display Help
To display available commands and options:
```sh
./data_cli.sh help
```

### 2. Format Data
To convert a CSV file into a DELTA format:
```sh
./data_cli.sh format <input_file> <output_file>
```
Example:
```sh
./data_cli.sh format_delta /path/to/data.csv /path/to/DELTA_0000000000000001
```

#### Note: **Delta File Naming Format**
```
DELTA_<16-digit-sequence-number>
```

#### **Example Delta Files**
```
DELTA_0000000000000001
DELTA_0000000000000002
DELTA_0000000000000003
...
DELTA_0000000000010000
```

#### CSV Examples
##### Simple String Values
The following CSV example demonstrates a CSV with simple string values:

```csv
key,mutation_type,logical_commit_time,value,value_type
key1,UPDATE,1680815895468055,value1,string
key2,UPDATE,1680815895468056,value2,string
key1,UPDATE,1680815895468057,value11,string
key2,DELETE,1680815895468058,,string
```

##### Set Values
The following CSV example demonstrates a CSV with set values. By default:
- **Column delimiter** = `,`
- **Value delimiter** = `|`

```csv
key,mutation_type,logical_commit_time,value,value_type
key1,UPDATE,1680815895468055,elem1|elem2,string_set
key2,UPDATE,1680815895468056,elem3|elem4,string_set
key1,UPDATE,1680815895468057,elem6|elem7|elem8,string_set
key2,DELETE,1680815895468058,elem10,string_set
```



### 3. Generate Snapshot
To generate a snapshot file from delta files:
```sh
./data_cli.sh snapshot <data_dir> <starting_file> <ending_file> <snapshot_file>
```
Example:
```sh
./data_cli.sh snapshot /path/to/data_dir DELTA_0000000000000001 DELTA_0000000000000010 SNAPSHOT_0000000000000001
```