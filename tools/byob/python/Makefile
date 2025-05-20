json-proto:
	rm -rf ./samples/get_bid_req.proto
	python3 json_to_protobuf.py ./sample_req_data/get_bid_request.pbtxt ./sample_req_data/get_bid_req.proto

run-udf: json-proto
	./run_udf.sh

run-udf-binary: json-proto
	cd sample_udf.dist && exec 3<>../sample_req_data/get_bid_req.proto \
	&& ./sample_udf.bin 3 

gen-udf:
	python -m nuitka --standalone sample_udf.py	

gen-archive:
	cd sample_udf.dist && \
	cp sample_udf.bin bin.exe && \
	zip -r ../sample_udf.bin.zip . && \
	cd ..
