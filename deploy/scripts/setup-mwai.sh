#!/bin/bash
# setup-mwai.sh: Configure AI Engine with OpenRouter free models only
# Runs inside the WordPress container via WP-CLI

set -e

OPENROUTER_API_KEY="${1:?Usage: setup-mwai.sh <OPENROUTER_API_KEY>}"

echo "=== AI Engine Setup ==="
echo "Fetching free models from OpenRouter..."

# Fetch free models
FREE_MODELS_JSON=$(curl -s "https://openrouter.ai/api/v1/models" \
  -H "Authorization: Bearer $OPENROUTER_API_KEY" | python3 -c "
import json, sys
data = json.load(sys.stdin)
models = data.get('data', [])
free_models = []
for m in models:
    pricing = m.get('pricing', {})
    is_free = all(float(v) == 0 for v in pricing.values()) if pricing else False
    if is_free:
        free_models.append({
            'id': m['id'],
            'name': m.get('name', m['id']),
            'context_length': m.get('context_length', 0),
            'pricing': pricing
        })
free_models.sort(key=lambda x: x['id'])
print(json.dumps(free_models))
")

FREE_COUNT=$(echo "$FREE_MODELS_JSON" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
echo "Found $FREE_COUNT free models"

# Generate unique environment ID
ENV_ID="openrouter-$(date +%s)"

# Get the free model IDs as a JSON array
FREE_MODEL_IDS=$(echo "$FREE_MODELS_JSON" | python3 -c "
import json, sys
models = json.load(sys.stdin)
print(json.dumps([m['id'] for m in models]))
")

# Build the ai_models array (models fetched from OpenRouter, tagged)
AI_MODELS=$(echo "$FREE_MODELS_JSON" | python3 -c "
import json, sys
models = json.load(sys.stdin)
result = []
for m in models:
    result.append({
        'id': m['id'],
        'name': m['name'],
        'type': 'openrouter',
        'envId': '$ENV_ID',
        'tags': ['core', 'chat'],
        'context_length': m['context_length']
    })
print(json.dumps(result))
")

# Build the ai_envs array
AI_ENVS=$(python3 -c "
import json
envs = [{
    'id': '$ENV_ID',
    'name': 'OpenRouter (Free)',
    'type': 'openrouter',
    'apikey': '$OPENROUTER_API_KEY',
    'models': [],
    'customModels': [],
    'deployments': []
}]
print(json.dumps(envs))
")

# Set the default model to the free router
DEFAULT_MODEL="openrouter/free"

# Write the full mwai_options
echo "Writing AI Engine configuration..."
php wp-cli.phar option set mwai_options "
{
  \"version\": \"3.5.3\",
  \"ai_envs\": $AI_ENVS,
  \"ai_models\": $AI_MODELS,
  \"ai_allowed_models\": $FREE_MODEL_IDS,
  \"ai_default_env\": \"$ENV_ID\",
  \"ai_default_model\": \"$DEFAULT_MODEL\",
  \"ai_model_fallback\": \"$DEFAULT_MODEL\",
  \"ai_env_guardrails\": true,
  \"ai_models_guardrails\": true
}
" --format=json

echo ""
echo "=== Configuration Complete ==="
echo "Environment: OpenRouter (Free)"
echo "Default model: $DEFAULT_MODEL"
echo "Free models configured: $FREE_COUNT"
echo ""
echo "Available free models:"
echo "$FREE_MODEL_IDS" | python3 -c "
import json, sys
models = json.load(sys.stdin)
for i, m in enumerate(models, 1):
    print(f'  {i}. {m}')
"
