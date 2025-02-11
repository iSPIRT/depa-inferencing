# Loading data into the Key/Value server

-   The standard path is by uploading files to a cloud file storage service, which are pulled by kv service at the start of service and periodically for updates. 
- These are typically csv files that need to be converted to delta or snapshot format before uploading to cloud storage, **data_cli** tool will help create these files. Refer [here](https://github.com/privacysandbox/protected-auction-key-value-service/blob/db6a0b8593867d1d33fcfa116ee77d893d2b71fa/docs/data_loading/loading_data.md) for more details.
-  In some cases, you may need a custom UDF function to interact with KV service. UDF code needs to be converted to delta format and loaded into cloud storage, **udf_delta_file_generator.sh** tool will help you with that. Refer [here](https://github.com/privacysandbox/protected-auction-key-value-service/blob/db6a0b8593867d1d33fcfa116ee77d893d2b71fa/docs/generating_udf_files.md) for more details
  - In order to make sure UDF is working on the data as expected, **udf_tester.sh** will help with testing the UDF function on the sample data before deployment. Refer [here](https://github.com/privacysandbox/protected-auction-key-value-service/blob/db6a0b8593867d1d33fcfa116ee77d893d2b71fa/tools/udf/udf_tester/README.md)
for more details.


  


# Prerequisites
- Docker must be installed and running.
- **.config** file should have the tool's image location. It is prepopullated with latest version available on ispirt repo and publicly accessible(anonymous pull)
    
# data_cli tool to generate delta and snapshot files 

Run the script with following options

### 1. Display Help
To display all available options:
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
#  UDF Delta File Generator 

The `udf_delta_file_generator.sh` script converts UDF function written in javascript into delta file

  ```sh
 ./udf_delta_file_generator.sh <output_dir> <udf_file_path>
  ```

Example:
```sh
 ./udf_delta_file_generator.sh  /path/to/output_dir /path/to/udf.js
```
# UDF Tester
The udf_tester.sh script is used to test the udf function converted into delta file format on the sample data generated using "data_cli" tool.
  ```sh
./udf_tester.sh <kv_delta_file_path> <udf_delta_file_path> <input_arguments>
  ```

  Example:
```sh
 ./udf_tester.sh  /path/to/DELTA_0000000000000001 /path/to/DELTA_1739309043767697 '[{"data":["a"]}]'
```