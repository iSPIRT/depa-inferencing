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

import json
import numpy as np
import sys
import os
import pickle
from serdes_utils import read_request_from_fd, write_response_to_fd
import generate_bid_pb2
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler

def determine_card_tier_and_limit(credit_score):
    """Determine card tier and credit limit based on credit score"""
    if credit_score < 40:
        # Round the last 3 digits to the nearest thousand
        raw_limit = 100000 + (credit_score / 40) * 100000
        rounded_limit = round(raw_limit / 1000) * 1000
        return "silver", int(rounded_limit)
    elif credit_score < 70:
        # Round the last 3 digits to the nearest thousand
        raw_limit = 200000 + ((credit_score - 40) / 30) * 100000
        rounded_limit = round(raw_limit / 1000) * 1000
        return "gold", int(rounded_limit)
    else:
        # Round the last 3 digits to the nearest thousand
        raw_limit = 300000 + ((credit_score - 70) / 30) * 200000
        rounded_limit = round(raw_limit / 1000) * 1000
        return "platinum", int(rounded_limit)

def load_model(model_dir):
    """Load the trained model and scaler"""
    base_path = os.path.dirname(os.path.abspath(__file__))
    model_dir = os.path.join(base_path, model_dir)
    try:
        with open(os.path.join(model_dir, 'credit_card_model.pkl'), 'rb') as f:
            try:
                print(f"Loading model from {os.path.join(model_dir, 'credit_card_model.pkl')}")
                model = pickle.load(f)
            except ImportError as e:
                print(f"Import Error loading model: {e}")
                sys.exit(1)
    except FileNotFoundError as e:        
        print(f"Model file not found: {e}")
        sys.exit(1) 
    
    try:
        with open(os.path.join(model_dir, 'credit_card_scaler.pkl'), 'rb') as f:
            try:
                print(f"Loading scaler from {os.path.join(model_dir, 'credit_card_scaler.pkl')}")
                scaler = pickle.load(f)
            except ImportError as e:
                print(f"Import Error loading scaler: {e}")
                sys.exit(1)
    except FileNotFoundError as e:
        print(f"Scaler file not found: {e}")
        sys.exit(1)
        
    return model, scaler

def main():
    if len(sys.argv) < 2:
        sys.stderr.write("Not enough arguments!\n")
        return -1
    
    fd = int(sys.argv[1])
    model_dir = 'models'
    if len(sys.argv) > 2:
        model_dir = sys.argv[2]
    
    # Read the message buffer bytes from the file descriptor
    message_buffer = read_request_from_fd(fd)
    request = generate_bid_pb2.GenerateProtectedAudienceBidRequest()
    request.ParseFromString(message_buffer)
    print(f"Received request: {request}")
    
    # Load the trained model
    model, scaler = load_model(model_dir)
    
    # Process each interest group
    response = generate_bid_pb2.GenerateProtectedAudienceBidResponse()
    
    #for interest_group in request.interest_groups:
    try:
        interest_group = request.interest_group
        # Parse user bidding signals to extract features
        user_signals = json.loads(interest_group.user_bidding_signals)
        age = float(user_signals.get("age", 30))
        avg_amount_spent = float(user_signals.get("avg_amount_spent", 20000))
        total_spent = float(user_signals.get("total_spent", 100000))
        
        # Prepare features for prediction
        features = np.array([[age, avg_amount_spent, total_spent]])
        features_scaled = scaler.transform(features)
        
        # Predict credit score
        credit_score = model.predict(features_scaled)[0]
        
        # Determine card tier and credit limit
        card_tier, credit_limit = determine_card_tier_and_limit(credit_score)
        
        # Create bid response
        bid = generate_bid_pb2.ProtectedAudienceBid()
        bid.ad = f"Credit Card Offer: {card_tier.upper()} - Limit: {credit_limit}"
        bid.bid = float(credit_score)  # Use credit score as bid amount
        bid.render = f"https://creditcard/offers/{card_tier}?limit={credit_limit}"
        bid.ad_cost = 1.0
        bid.bid_currency = 'Rupees'
        
        # Add metadata with details about the offer
        # metadata = {
        #     "card_tier": card_tier,
        #     "credit_limit": credit_limit,
        #     "customer_name": interest_group.name,
        #     "credit_score": float(credit_score)
        # }
        # bid.metadata = json.dumps(metadata)
        
        response.bids.append(bid)
        
        print(f"Generated offer for {interest_group.name}: {card_tier.upper()} card with limit ${credit_limit}")
    
    except Exception as e:
        print(f"Error processing interest group {interest_group.name}: {str(e)}")
    
    print(f"Response: {response}")
    # Write the response to the file descriptor
    write_response_to_fd(fd, response)
    
    return 0

if __name__ == "__main__":
    sys.exit(main())