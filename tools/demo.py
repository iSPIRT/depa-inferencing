# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

import streamlit as st
import pandas as pd
import jwt
import subprocess
import os
import time
import json
import requests
import asyncio
import re
import urllib3
from kubernetes import client, config

base_path = os.getcwd()

urllib3.disable_warnings()

async def secure_invoke(kms_url, buyer_host, request):
  result = subprocess.run(["bash", "secure_invoke_test.sh"],
      cwd=base_path + "/secure-invoke", 
      capture_output=True)
  return result.stdout

async def get_pod(v1, namespace, prefix):
    # List all pods in the specified namespace
    pods = v1.list_namespaced_pod(namespace)

    # Find the first pod that starts with the given name prefix
    for pod in pods.items:
        if pod.metadata.name.startswith(prefix):
            return pod.metadata.name
            
async def get_pod_logs(v1, pod):
  try:
      # Get the logs of the specified pod
      pod_logs = v1.read_namespaced_pod_log(name=pod, namespace="default", tail_lines=173, pretty=True)
      return pod_logs
  except client.exceptions.ApiException as e:
      print(f"Exception when calling CoreV1Api->read_namespaced_pod_log: {e}")
      
  
async def main():  
  config.load_kube_config()
  v1 = client.CoreV1Api()
  namespace = 'default'
  
  st.set_page_config (layout="wide")
  st.title('DEPA Inferencing Demo')
  request_file_path = base_path + "/requests/get_bids_request.json"

  pdp,pdc=st.columns(2)
  
  pdp.header("Personal data provider")
  kms_url = pdp.text_input("KMS", value="https://depa-inferencing-kms.centralindia.cloudapp.azure.com")
  buyer_host = pdp.text_input("PDC endpoint", value="4.209.24.251:51052/v1/getbids")
  customer_name = pdp.text_input("Customer name", value="Rajni Kausalya")
  customer_id = pdp.text_input("Customer ID", value="9999999990")
  request = {}
  if pdp.button("Show Request"):
    with open(request_file_path, "r") as fp:
      request = json.loads(fp.read())
    request['buyerInput']['interestGroups'][0]['name'] = customer_name
    request['buyerInput']['interestGroups'][0]['biddingSignalsKeys'][0] = customer_id
    with open(request_file_path, "w+") as fp:
      json.dump(request, fp)
    pdp.json(request)

  if pdp.button("Generate Offer"):
    response = await secure_invoke(kms_url=kms_url, buyer_host=buyer_host, request=request)
    response = response.decode('utf-8', errors='ignore')
    key_id = re.search(r'-key_id=(\d+)', response).group(1)
    public_key = re.search(r'-public_key=([^\s]+)', response).group(1)
    request_ciphertext = re.search(r'\"requestCiphertext\":\"([^\s]+)\"', response).group(1)
    response_ciphertext = re.search(r'\"responseCiphertext\": \"([^\s]+)\"', response).group(1)
    ad = re.search(r'string_value: ([^\s]+)', response).group(1)
    pdp.write("Encrypting with " + key_id + " and " + public_key)
    pdp.subheader("Request ciphertext")
    pdp.write(request_ciphertext)
    pdp.subheader("Response ciphertext")
    pdp.write(response_ciphertext)
    pdp.subheader("Offer")
    pdp.write(ad)

  pdc.header("Personal data consumer")
  pdc.write("Key/Value data")
  df = pd.read_csv(base_path + "/key-value-service/data.csv")
  pdc.dataframe(df)
  if pdc.button("Show logs"):
    pod_name = await get_pod(v1, "default", "ofe")
    pdc.text("Printing logs from " + pod_name)
    response = await get_pod_logs(v1, pod_name)
    pdc.text(response)
    
if __name__ == "__main__":
    asyncio.run(main())