#!/bin/bash

# This script is used to run a UDF in to send and receive on File Descriptor 3
exec 3<>./sample_req_data/get_bid_request.proto
python3 credit_card_inference.py 3
exec 3>&-