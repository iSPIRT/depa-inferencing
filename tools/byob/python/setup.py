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

from setuptools import setup, find_packages

setup(
    name="serdes_utils",
    version="0.1.0",
    description="Protobuf serialization and deserialization utilities for BYOB Python",
    author="pavan adukuri",
    author_email="pavan.adukuri@ispirt.in",
    packages=find_packages(include=["serdes_utils", "json_to_protobuf"]),
    python_requires=">=3.10",
    install_requires=[
        "protobuf>=6.30.0",
    ],
    # classifiers=[
    #     "Development Status :: 3 - Alpha",
    #     "Intended Audience :: Developers",
    #     "License :: OSI Approved :: Apache Software License",
    #     "Programming Language :: Python :: 3",
    #     "Programming Language :: Python :: 3.6",
    #     "Programming Language :: Python :: 3.7",
    #     "Programming Language :: Python :: 3.8",
    #     "Programming Language :: Python :: 3.9",
    #     "Programming Language :: Python :: 3.10",
    #     "Programming Language :: Python :: 3.11",
    # ],
)