proto-py:
	protoc -I=../protodefs --python_out=. generate_bid.proto --experimental_allow_proto3_optional && \
	protoc -I=../protodefs --python_out=. options.proto 

json-proto: proto-py
	rm -rf ./samples/get_bid_request.proto
	python3 gen_protobuf_data.py ./sample_req_data/get_bid_request.pbtxt ./sample_req_data/get_bid_request.proto

run-udf: json-proto
	./run_udf.sh

gen-udf: proto-py
	python -m nuitka --standalone sample_udf.py	

run-udf-binary: json-proto
	cd sample_udf.dist && exec 3<>../sample_req_data/get_bid_request.proto \
	&& ./sample_udf.bin 3 

gen-archive:
	cd sample_udf.dist && \
	mv sample_udf.bin bin.exe && \
	cp --dereference /lib/x86_64-linux-gnu/libz* . && \
	zip -r ../sample_udf.bin.zip . && \
	cd ..
