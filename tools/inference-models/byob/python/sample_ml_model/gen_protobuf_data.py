import generate_bid_pb2
from json_to_protobuf import json_to_protobuf
import sys

def main():
    if len(sys.argv) != 3:
        print("Usage: serialize_request.py <input_json_file> <output_protobuf_file>")
        sys.exit(1)
    
    json_file_path = sys.argv[1]
    output_file_path = sys.argv[2]
    request = generate_bid_pb2.GenerateProtectedAudienceBidRequest()
    json_to_protobuf(json_file_path, output_file_path, request)

if __name__ == "__main__":
    main()
