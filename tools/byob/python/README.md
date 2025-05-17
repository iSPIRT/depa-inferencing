# BYOB for Python

Privacy sandbox supports BYOB natively for compiled languages - c++, go, rust. This tool helps to enhance the support for Python. We have used [Nuitka](https://nuitka.net/) to compile python project into executable. Please follow the following instructions to set up the build env and build python binary.

## Build Environment Setup

1. Bring up host environment with Ubuntu-20.04 or 22.04
2. Install Python 3.11
3. Install python venv & Enable venv

4. Install protoc compiler (30.2)

   ```
   PB_REL="https://github.com/protocolbuffers/protobuf/releases"
   curl -LO $PB_REL/download/v30.2/protoc-30.2-linux-x86_64.zip
   unzip protoc-30.2-linux-x86_64.zip -d $HOME/.local
   export PATH=$HOME/.local/bin:$PATH
   ```

5. Install protobuf 

   ```
   pip install protobuf>=6.30
   ```

6. Install Nuitka 

   ```
   python -m pip install nuitka
   sudo apt-get install python3-dev
   apt install patchelf
   ```


## Steps to generate binary (With Generate Bid UDF Example)

### 1. Compile Protobuf definition to generate python proto files

```
protoc -I=./protodefs --python_out=. generate_bid.proto --experimental_allow_proto3_optional 
```

### 2. Run sample python code(Optional test step for python code)

```
make run-udf
```

### 3. Generate python binary(generates object files and binary in dist folder)

```
python -m nuitka --standalone sample_udf.py 

```

### 3. Run the generated binary

```
make run-udf-binary
```

### 4. zip the generated binary

```
make gen-archive
```


## Upload the generated zip file to the target location(Azure blob, GCS, etc)

1. Use the appropriate command to upload the binary to your desired location.
2. For Azure Blob Storage:
   ```
   az storage blob upload --account-name <your_account_name> --container-name <your_container_name> --name <your_binary_name> --file <path_to_your_binary>
   ```
3. For Google Cloud Storage:
   ```
   gsutil cp <path_to_your_binary> gs://<your_bucket_name>/
   ```
4. For AWS S3:
   ```
   aws s3 cp <path_to_your_binary> s3://<your_bucket_name>/
   ```