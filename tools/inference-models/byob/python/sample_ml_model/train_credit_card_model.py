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

import numpy as np
import pickle
import os
from sklearn.linear_model import LinearRegression
from sklearn.preprocessing import StandardScaler
import argparse

def create_training_data():
    """Create synthetic training data for the linear regression model"""
    # Create synthetic data based on the provided ranges
    np.random.seed(42)  # For reproducibility
    
    # Generate 100 samples with age between 20-90, avg_amount_spent between 10000-100000, 
    # and total_spent between 50000-1000000
    ages = np.random.randint(20, 91, size=100)
    avg_amounts = np.random.randint(10000, 100001, size=100)
    total_spents = np.random.randint(50000, 1000001, size=100)
    
    # Features matrix
    X = np.column_stack((ages, avg_amounts, total_spents))
    
    # Generate target values (credit score from 1-100, higher is better)
    # This is a simplistic model where:
    # - Age contributes moderately (older = slightly better score up to a point)
    # - Average spending contributes significantly
    # - Total spent contributes significantly
    credit_scores = (
        (ages - 20) / 70 * 20 +  # Age contribution (max 20 points)
        avg_amounts / 100000 * 40 +  # Avg amount contribution (max 40 points)
        total_spents / 1000000 * 40  # Total spent contribution (max 40 points)
    )
    
    return X, credit_scores

def train_model(output_dir='./models'):
    """Train and save the linear regression model and scaler"""
    print("Generating training data...")
    X, y = create_training_data()
    
    # Standardize features
    print("Training model...")
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    # Train the model
    model = LinearRegression()
    model.fit(X_scaled, y)
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Save the model and scaler
    print(f"Saving model to {output_dir}...")
    with open(os.path.join(output_dir, 'credit_card_model.pkl'), 'wb') as f:
        pickle.dump(model, f)
    
    with open(os.path.join(output_dir, 'credit_card_scaler.pkl'), 'wb') as f:
        pickle.dump(scaler, f)
    
    print("Model training and saving complete.")
    return model, scaler

def main():
    parser = argparse.ArgumentParser(description='Train a linear regression model for credit card offers')
    parser.add_argument('--output-dir', type=str, default='./models',
                        help='Directory to save the trained model (default: ./models)')
    args = parser.parse_args()
    
    train_model(args.output_dir)
    return 0

if __name__ == "__main__":
    main()