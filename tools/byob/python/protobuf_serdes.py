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

import os
import logging

# Change to ERROR->DEBUG to see logs
log_level_name = os.environ.get('LOG_LEVEL', 'ERROR')
# In debug env, there is no PAYLOAD_LENGTH_INDICATOR, set this to False
PAYLOAD_LENGTH_INDICATOR = False

log_level = getattr(logging, log_level_name.upper(), logging.INFO)
# Configure logging
logging.basicConfig(
    level=log_level,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('protobuf_serdes')


def read_request_from_fd(fd):    
    # Create a buffer to store all parts of the message
    message_buffer = bytearray()
    
    # Payload length is carried in multiple bytes, read until MSB is 0 in the byte
    # For example, if payload length > 7f, length will be represented by > 1 byte
    def read_payload_length_indicator():
        while True:
            b = os.read(fd, 1)
            logger.debug(f"len byte: {b}")
            byte = b[0]
            if not (byte & 0x80):
                break
    
    #Parse the tag byte to verify wire type and field number
    def parse_tag_byte(tag_byte):
        if not tag_byte:
            logger.error("EOFError: Unexpected EOF while reading tag byte")
            raise EOFError("Unexpected EOF while reading tag byte")

        # Add tag byte to message buffer
        message_buffer.extend(tag_byte)
        # Parse tag byte
        tag_value = tag_byte[0]
        field_number = tag_value >> 3
        wire_type = tag_value & 0x7
        logger.debug(f"Tag byte: {tag_value:02x}, Field number: {field_number}, Wire type: {wire_type}")

        # Check if this is a length-delimited field (wire type 2)
        if wire_type != 2:
            logger.error(f"Expected wire type 2 (length-delimited), got {wire_type}")
            raise ValueError(f"Expected wire type 2 (length-delimited), got {wire_type}")
        
    #Decode Variant for the length of message    
    def read_varint():
        shift = 0
        result = 0
        varint_buffer = bytearray()
        
        while True:
            b = os.read(fd, 1)
            if not b:
                logger.error("EOFError: Unexpected EOF while reading varint")
                raise EOFError("Unexpected EOF while reading varint")
     
            # Add to our buffer
            varint_buffer.extend(b)
            message_buffer.extend(b)
            
            byte = b[0]
            result |= (byte & 0x7F) << shift
            if not (byte & 0x80):
                break
            shift += 7
        
        return int(result), varint_buffer
    
    # Read and Parse the Protobuf payload in the below steps

    # 1.Read payload length bytes and discard
    if PAYLOAD_LENGTH_INDICATOR == True:
        read_payload_length_indicator()
    # 2.Read tag byte
    tag_byte = os.read(fd, 1)
    #tag_byte = first_byte
    parse_tag_byte(tag_byte)
    # 3.Decode the message length from varint
    msg_len, length_buffer = read_varint()
    logger.debug(f"Message length: {msg_len} bytes (encoded in {len(length_buffer)} bytes)")
    #4. Read the message data of msg_len bytes
    msg_data = os.read(fd, msg_len)
    if len(msg_data) < msg_len:
        logger.error(f"EOFError: Truncated message: expected {msg_len} bytes, got {len(msg_data)} bytes")
        raise EOFError(f"Truncated message: expected {msg_len} bytes, got {len(msg_data)} bytes")
    # 5.Add message data to message buffer
    message_buffer.extend(msg_data)
    return message_buffer
  

def write_response_to_fd(fd, response):
    """Write a response to a file descriptor."""
    payload = bytearray()
    
    #Construct protobuf payload in following steps
    # 1. Serialize the response
    serialized_response = response.SerializeToString()
    # 2. Calculate the size of the data
    data_size = len(serialized_response)
    # 3. Encode the size as a varint
    size_bytes = bytearray()
    temp_size = data_size
    while True:
        byte = temp_size & 0x7F
        temp_size >>= 7
        if temp_size:
            byte |= 0x80  # Set the MSB to indicate more bytes follow
        size_bytes.append(byte)
        if not temp_size:
            break
    # 4. Add size bytes to payload
    payload.extend(size_bytes)  
    # 5. Add the serialized response to the payload
    payload.extend(serialized_response)

    logger.debug(f"Payload size bytes: {bytes(size_bytes).hex()}, Data size: {data_size} bytes")
    logger.debug(f"Total message size: {len(payload)} bytes")
    
    # 6. Write the complete message to the file descriptor
    os.write(fd, payload)
