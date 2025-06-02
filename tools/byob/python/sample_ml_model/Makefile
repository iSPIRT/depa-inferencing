proto-py:
	protoc -I=../protodefs --python_out=. generate_bid.proto --experimental_allow_proto3_optional && \
	protoc -I=../protodefs --python_out=. options.proto 

json-proto: proto-py
	rm -rf ./samples/get_bid_request.proto
	python3 gen_protobuf_data.py ./sample_req_data/get_bid_request.pbtxt ./sample_req_data/get_bid_request.proto

run-udf: json-proto
	./run_udf.sh

gen-udf:
	python -m nuitka --standalone credit_card_inference.py	--include-package=sklearn --include-data-dir=./models=models 

run-udf-binary: json-proto
	cd credit_card_inference.dist && exec 3<>../sample_req_data/get_bid_request.proto \
	&& ./credit_card_inference.bin 3 

gen-archive:
	cd credit_card_inference.dist && \
	mv credit_card_inference.bin bin.exe && \
	cp --dereference /lib/x86_64-linux-gnu/libz* . && \
	zip -r ../credit_card_inference.bin.zip . && \
	cd ..
	
train-model:
	python3 train_credit_card_model.py