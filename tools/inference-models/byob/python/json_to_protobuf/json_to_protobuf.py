import json
import sys
from serdes_utils import gen_protobuf_payload

def json_to_protobuf(json_file_path, output_file_path, request):
    # Load JSON data
    with open(json_file_path, 'r') as f:
        json_data = json.load(f)
    
    # Fill interest group
    if 'interest_groups' in json_data:
        ig = json_data['interest_groups']
        for group in ig:
            interest_group = request.interest_group
            interest_group.name = group.get('name', '')
            interest_group.trusted_bidding_signals_keys.extend(
                group.get('bidding_signals_keys', []))
            interest_group.ad_render_ids.extend(
                group.get('ad_render_ids', []))
            interest_group.ad_component_render_ids.extend(
                group.get('ad_component_render_ids', []))
            interest_group.user_bidding_signals = group.get('user_bidding_signals', '')
    
    # Set string fields
    request.auction_signals = json_data.get('auction_signals', '')
    request.per_buyer_signals = json_data.get('per_buyer_signals', '')
    request.trusted_bidding_signals = json_data.get('trusted_bidding_signals', '')
    
    # Set browser signals
    if 'browser_signals' in json_data:
        bs = json_data['browser_signals']
        request.browser_signals.top_window_hostname = bs.get('top_window_hostname', '')
        request.browser_signals.seller = bs.get('seller', '')
        request.browser_signals.top_level_seller = bs.get('top_level_seller', '')
        request.browser_signals.join_count = bs.get('join_count', 0)
        request.browser_signals.bid_count = bs.get('bid_count', 0)
        request.browser_signals.recency = bs.get('recency', 0)
        request.browser_signals.prev_wins = bs.get('prev_wins', '')
        request.browser_signals.multi_bid_limit = bs.get('multi_bid_limit', 0)
        request.browser_signals.prev_wins_ms = bs.get('prev_wins_ms', '')
    
    # Set server metadata
    if 'server_metadata' in json_data:
        sm = json_data['server_metadata']
        request.server_metadata.debug_reporting_enabled = sm.get('debug_reporting_enabled', False)
        request.server_metadata.logging_enabled = sm.get('logging_enabled', False)

    # Serialize to binary
    binary_data = request.SerializeToString()
    # Generate protobuf payload
    payload = gen_protobuf_payload(binary_data)
    
    # Write to file
    with open(output_file_path, 'wb') as f:
        f.write(payload)
    
    print(f"Serialized protobuf message written to {output_file_path}")
    print(f"Size: {len(binary_data)} bytes")