function generateBid(interest_group, auction_signals, buyer_signals,
                     trusted_bidding_signals, device_signals) {
  return {
    render: interest_group.adRenderIds[0],
    ad: {"arbitraryMetadataField": 1},
    bid: 10,
    bidCurrency: "USD",
    allowComponentAuction: false
  };
}