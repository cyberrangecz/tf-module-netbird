#!/bin/sh
# Bootstrap the NetBird first owner user (once) and rotate its Personal Access
# Token (PAT). Run by the chart's post-install/upgrade hook Job (bootstrap) and
# by the rotation CronJob (periodic rotation) — the logic is identical, except
# that only the Job sets NETWORK_RANGE.
#
# The current PAT is persisted in a Kubernetes Secret ($PAT_SECRET_NAME) in the
# pod namespace, which acts as the durable rotation store:
#   * first run  -> POST /api/setup creates the owner + an initial PAT
#   * later runs -> use the stored PAT to create a fresh PAT and revoke the old
#
# Required env:
#   NB_API_URL        base URL of the NetBird management API (e.g. http://netbird-server.netbird.svc.cluster.local)
#   PAT_SECRET_NAME   name of the Secret used as the rotation store
#   POD_NAMESPACE     namespace the Secret lives in
#   OWNER_EMAIL       first owner email (used only for the one-time bootstrap)
#   OWNER_NAME        first owner display name
#   OWNER_PASSWORD    first owner password
#   PAT_TOKEN_NAME    name assigned to the rotated PAT
#   PAT_EXPIRE_DAYS   PAT lifetime in days (1-365)
#   SERVER_DEPLOYMENT name of the netbird-server Deployment (bootstrap restart target)
#   SERVER_NAMESPACE  namespace of the netbird-server Deployment
# Optional env:
#   NETWORK_RANGE     IPv4 CIDR the account gives peer addresses from
set -eu

API="${NB_API_URL%/}"
KUBE="https://kubernetes.default.svc"
SA_TOKEN="$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)"
CACERT="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
SECRET_URL="$KUBE/api/v1/namespaces/$POD_NAMESPACE/secrets"

b64enc() { printf '%s' "$1" | base64 | tr -d '\n'; }
b64dec() { printf '%s' "$1" | base64 -d 2>/dev/null || true; }

# --- rotation store (Kubernetes Secret) helpers ---------------------------
read_store() {
  code="$(curl -sS -o /tmp/store.json -w '%{http_code}' --cacert "$CACERT" \
    -H "Authorization: Bearer $SA_TOKEN" "$SECRET_URL/$PAT_SECRET_NAME")"
  if [ "$code" = "200" ]; then
    PAT="$(b64dec "$(jq -r '.data.pat // ""' /tmp/store.json)")"
    USER_ID="$(b64dec "$(jq -r '.data.user_id // ""' /tmp/store.json)")"
  else
    PAT=""; USER_ID=""
  fi
}

write_store() { # pat user_id
  payload="$(jq -n --arg p "$(b64enc "$1")" --arg u "$(b64enc "$2")" \
    '{data: {pat: $p, user_id: $u}}')"
  code="$(curl -sS -o /dev/null -w '%{http_code}' --cacert "$CACERT" \
    -H "Authorization: Bearer $SA_TOKEN" -H "Content-Type: application/merge-patch+json" \
    -X PATCH "$SECRET_URL/$PAT_SECRET_NAME" -d "$payload")"
  if [ "$code" = "404" ]; then
    create="$(jq -n --arg n "$PAT_SECRET_NAME" --arg ns "$POD_NAMESPACE" \
      --arg p "$(b64enc "$1")" --arg u "$(b64enc "$2")" \
      '{apiVersion:"v1",kind:"Secret",metadata:{name:$n,namespace:$ns},type:"Opaque",data:{pat:$p,user_id:$u}}')"
    curl -fsS -o /dev/null --cacert "$CACERT" -H "Authorization: Bearer $SA_TOKEN" \
      -H "Content-Type: application/json" -X POST "$SECRET_URL" -d "$create"
  elif [ "$code" != "200" ]; then
    echo "failed to persist rotation store (HTTP $code)" >&2; exit 1
  fi
}

# --- NetBird API helpers --------------------------------------------------
nb() { # method path [auth] [data]  -> body in /tmp/nb.json, prints status code
  m="$1"; p="$2"; auth="${3:-}"; data="${4:-}"
  # curl leaves the file untouched when no body arrives; an error message must
  # not print the previous response, which may hold the setup PAT.
  : > /tmp/nb.json
  set -- -sS -o /tmp/nb.json -w '%{http_code}' -X "$m" "$API$p"
  [ -n "$auth" ] && set -- "$@" -H "Authorization: Token $auth"
  [ -n "$data" ] && set -- "$@" -H "Content-Type: application/json" -d "$data"
  curl "$@"
}

# Roll the server Deployment (like `kubectl rollout restart`). Used once after
# the bootstrap so the single-account-anchor init container re-runs against the
# freshly created setup account and the server reloads its account cache with
# the now-claimed domain. Best-effort: a failure here is logged, not fatal —
# the anchor still applies on the next natural server restart.
restart_server() {
  [ -n "${SERVER_DEPLOYMENT:-}" ] && [ -n "${SERVER_NAMESPACE:-}" ] || return 0
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  patch="$(jq -n --arg t "$ts" \
    '{spec:{template:{metadata:{annotations:{"kubectl.kubernetes.io/restartedAt":$t}}}}}')"
  url="$KUBE/apis/apps/v1/namespaces/$SERVER_NAMESPACE/deployments/$SERVER_DEPLOYMENT"
  code="$(curl -sS -o /dev/null -w '%{http_code}' --cacert "$CACERT" \
    -H "Authorization: Bearer $SA_TOKEN" \
    -H "Content-Type: application/strategic-merge-patch+json" \
    -X PATCH "$url" -d "$patch")"
  if [ "$code" = "200" ]; then
    echo "Triggered rollout restart of deployment/$SERVER_DEPLOYMENT."
  else
    echo "warning: could not restart deployment/$SERVER_DEPLOYMENT (HTTP $code);" >&2
    echo "the single-account anchor will apply on the next server restart." >&2
  fi
}

# Changing the range re-addresses every peer, so skip the update when it matches.
apply_network_range() { # pat
  [ -n "${NETWORK_RANGE:-}" ] || return 0
  code="$(nb GET /api/accounts "$1")"
  [ "$code" = "200" ] || { echo "reading the account failed (HTTP $code): $(cat /tmp/nb.json)" >&2; return 1; }
  current="$(jq -r '.[0].settings.network_range // empty' /tmp/nb.json)"
  if [ "$current" = "$NETWORK_RANGE" ]; then
    echo "Network range is already $NETWORK_RANGE."
    return 0
  fi
  account_id="$(jq -r '.[0].id // empty' /tmp/nb.json)"
  [ -n "$account_id" ] || { echo "could not determine the account id: $(cat /tmp/nb.json)" >&2; return 1; }
  # The PUT replaces every setting, so send the current ones back. Without
  # `extra` the server keeps its stored extra settings, including fields the API
  # does not expose.
  body="$(jq -c --arg r "$NETWORK_RANGE" \
    '{settings: (.[0].settings | del(.extra) | .network_range = $r)}' /tmp/nb.json)"
  code="$(nb PUT "/api/accounts/$account_id" "$1" "$body")"
  [ "$code" = "200" ] || { echo "updating the account settings to network range $NETWORK_RANGE failed (HTTP $code): $(cat /tmp/nb.json)" >&2; return 1; }
  # The server masks the range, so a value with host bits set changes nothing.
  applied="$(jq -r '.settings.network_range // empty' /tmp/nb.json)"
  if [ "$applied" = "$current" ]; then
    echo "Network range is already $applied (configured as $NETWORK_RANGE)."
  else
    echo "Network range changed from ${current:-unset} to $applied; every peer was re-addressed."
  fi
}

# Wait until the management API answers (any HTTP response means it is up).
echo "Waiting for NetBird API at $API ..."
i=0
until curl -sS -o /dev/null "$API/api/users" 2>/dev/null; do
  i=$((i + 1))
  if [ "$i" -gt 60 ]; then echo "NetBird API not reachable" >&2; exit 1; fi
  sleep 5
done

read_store

if [ -z "$PAT" ]; then
  # First run: create the owner and an initial PAT via the setup endpoint.
  echo "No stored PAT found, bootstrapping first owner via /api/setup ..."
  body="$(jq -n --arg e "$OWNER_EMAIL" --arg n "$OWNER_NAME" --arg p "$OWNER_PASSWORD" \
    --argjson d "$PAT_EXPIRE_DAYS" \
    '{email:$e, name:$n, password:$p, create_pat:true, pat_expire_in:$d}')"
  code="$(nb POST /api/setup "" "$body")"
  if [ "$code" != "200" ] && [ "$code" != "201" ]; then
    echo "setup failed (HTTP $code): $(cat /tmp/nb.json)" >&2
    echo "If an account already exists but the rotation store was lost, the PAT" >&2
    echo "cannot be recovered automatically — create one in the dashboard." >&2
    exit 1
  fi
  PAT="$(jq -r '.personal_access_token // empty' /tmp/nb.json)"
  USER_ID="$(jq -r '.user_id // empty' /tmp/nb.json)"
  [ -n "$PAT" ] || { echo "setup did not return a PAT: $(cat /tmp/nb.json)" >&2; exit 1; }
  write_store "$PAT" "$USER_ID"
  echo "Bootstrap complete (user $USER_ID)."
  # A failure must not skip the restart: the Job's retry takes the rotation path,
  # which applies the range again but never restarts the server.
  status=0
  apply_network_range "$PAT" || status=1
  # The setup account was created with an empty domain; roll the server so the
  # anchor init container claims it and single-account mode stays enabled.
  restart_server
  exit "$status"
fi

# Subsequent run: resolve the owner, mint a new PAT, revoke the others.
if [ -z "$USER_ID" ]; then
  code="$(nb GET /api/users "$PAT")"
  [ "$code" = "200" ] || { echo "listing users failed (HTTP $code): $(cat /tmp/nb.json)" >&2; exit 1; }
  USER_ID="$(jq -r '[.[] | select(.role=="owner")][0].id // empty' /tmp/nb.json)"
  [ -n "$USER_ID" ] || { echo "could not determine owner user id" >&2; exit 1; }
fi

echo "Rotating PAT for user $USER_ID ..."
new="$(jq -n --arg n "$PAT_TOKEN_NAME" --argjson d "$PAT_EXPIRE_DAYS" \
  '{name:$n, expires_in:$d}')"
code="$(nb POST "/api/users/$USER_ID/tokens" "$PAT" "$new")"
if [ "$code" = "401" ] || [ "$code" = "403" ]; then
  echo "stored PAT is no longer valid (HTTP $code) — likely expired between runs." >&2
  echo "Delete secret $PAT_SECRET_NAME and re-run only if no account exists yet," >&2
  echo "otherwise create a fresh PAT in the dashboard and seed the secret." >&2
  exit 1
fi
[ "$code" = "200" ] || [ "$code" = "201" ] || { echo "token creation failed (HTTP $code): $(cat /tmp/nb.json)" >&2; exit 1; }
NEW_PAT="$(jq -r '.plain_token // empty' /tmp/nb.json)"
NEW_ID="$(jq -r '.personal_access_token.id // empty' /tmp/nb.json)"
[ -n "$NEW_PAT" ] || { echo "token creation did not return a plain token: $(cat /tmp/nb.json)" >&2; exit 1; }

# Persist the new PAT first so a failure mid-cleanup never loses the credential.
write_store "$NEW_PAT" "$USER_ID"

# Revoke every other token for this user, authenticating with the new PAT.
nb GET "/api/users/$USER_ID/tokens" "$NEW_PAT" >/dev/null
for tid in $(jq -r '.[].id' /tmp/nb.json); do
  [ "$tid" = "$NEW_ID" ] && continue
  nb DELETE "/api/users/$USER_ID/tokens/$tid" "$NEW_PAT" >/dev/null || true
done

echo "Rotation complete (new token $NEW_ID)."

apply_network_range "$NEW_PAT" || exit 1
