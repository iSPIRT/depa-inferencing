import json
import csv
import subprocess

def read_csv_and_map_to_json(csv_file, json_file):
    mapped_data = []
    
    with open(csv_file, "r") as file:
        reader = csv.DictReader(file)
        for row in reader:
            json_object = {
                "client_type": row["client_type"],
                "buyer_input": {
                    "interest_groups": 
                        {
                            "name": row["interest_group"],
                            "bidding_signals_keys": [row["key"]],
                            "ad_render_ids": [row["ad_render_ids"]],
                            "user_bidding_signals": row["User signals"],
                            "browser_signals": {
                                "join_count": "",
                                "bid_count": "",
                                "prev_wins": "[]"
                            }
                        }
                    ]
                },
                "publisher_name": "example.com",
                "buyer_signals": "{}",
                "auction_signals": "{}",
                "seller": "",
                "log_context": {
                    "generation_id": "",
                    "adtech_debug_id": ""
                },
                "consented_debug_config": {
                    "is_consented": True,
                    "token": "123456"
                }
            }
    
            with open(json_file, "w") as file:
                json.dump(mapped_data, file, indent=4)

def call_tool(json_file):
    with open(json_file, "r") as file:
        data = json.load(file)
    
    for item in data["interest_groups"]:
        subprocess.run(["bash", "tool.sh", json.dumps(item)])

def main():
    csv_file = "/workspaces/requests/data.csv"
    json_file = "/workspaces/requests/get_bids_request.json"
    
    read_csv_and_map_to_json(csv_file, json_file)
    call_tool(json_file)

if __name__ == "__main__":
    main()
