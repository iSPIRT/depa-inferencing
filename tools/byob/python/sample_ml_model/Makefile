json-proto:
	rm -rf ./samples/get_bid_req.proto
	python3 gen_protobuf_data.py ./sample_req_data/get_bid_req.pbtxt ./sample_req_data/get_bid_req.proto

run-udf: json-proto
	./run_udf.sh

run-udf-binary: json-proto
	cd credit_card_inference.dist && exec 3<>../sample_req_data/get_bid_req.proto \
	&& ./credit_card_inference.bin 3 

gen-udf:
	python -m nuitka --standalone credit_card_inference.py	--include-package=sklearn --include-data-dir=./models=models 

gen-archive:
	cd credit_card_inference.dist && \
	mv credit_card_inference.bin bin.exe && \
	zip -r ../credit_card_inference.bin.zip . && \
	cd ..
	
train-model:
	python3 train_credit_card_model.py