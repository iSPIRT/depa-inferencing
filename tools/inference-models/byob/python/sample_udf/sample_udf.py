#!/usr/bin/env python3
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from serdes_utils import read_request_from_fd, write_response_to_fd
import generate_bid_pb2
import sys

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Not enough arguments!\n")
        return -1
    
    fd = int(sys.argv[1])
    # Read the message buffer bytes from the file descriptor
    message_buffer = read_request_from_fd(fd)
    request = generate_bid_pb2.GenerateProtectedAudienceBidRequest()
    request.ParseFromString(message_buffer)
    print(request)

    # Create the response
    response = generate_bid_pb2.GenerateProtectedAudienceBidResponse()
    bid = generate_bid_pb2.ProtectedAudienceBid()
    bid.ad= request.interest_group.name
    bid.bid = 1.0
    bid.render = "https://my-render-url"
    bid.ad_cost= 2.0
    bid.bid_currency='USD'
    
    response.bids.append(bid)
    print(response, "\n")
    # Write the response to the file descriptor
    write_response_to_fd(fd, response)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())