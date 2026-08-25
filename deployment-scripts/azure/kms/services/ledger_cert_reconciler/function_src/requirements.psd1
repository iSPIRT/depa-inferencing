# Modules installed by the Functions host (managed dependencies).
# Kept minimal to reduce cold-start time: only Accounts (auth) + Network (App Gateway).
@{
  'Az.Accounts' = '3.*'
  'Az.Network'  = '7.*'
}
