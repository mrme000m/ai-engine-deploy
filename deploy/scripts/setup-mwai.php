<?php
/**
 * setup-mwai.php - Configure AI Engine with OpenRouter free models
 *
 * Usage: wp eval-file setup-mwai.php --allow-root
 */

$api_key = getenv('OPENROUTER_API_KEY');
if ( empty( $api_key ) ) {
    die( "ERROR: OPENROUTER_API_KEY environment variable is required.\n" );
}

echo "=== AI Engine Setup ===\n";
echo "Fetching free models from OpenRouter...\n\n";

// Fetch models from OpenRouter
$response = wp_remote_get( 'https://openrouter.ai/api/v1/models', [
    'headers' => [
        'Authorization' => 'Bearer ' . $api_key,
    ],
    'timeout' => 30,
] );

if ( is_wp_error( $response ) ) {
    die( "ERROR: Failed to fetch models: " . $response->get_error_message() . "\n" );
}

$body = json_decode( wp_remote_retrieve_body( $response ), true );
$all_models = $body['data'] ?? [];

// Filter free models
$free_models = [];
foreach ( $all_models as $m ) {
    $pricing = $m['pricing'] ?? [];
    $is_free = !empty( $pricing ) && array_reduce( $pricing, fn( $carry, $v ) => $carry && (float) $v === 0, true );
    if ( $is_free ) {
        $free_models[] = [
            'id'            => $m['id'],
            'name'          => $m['name'] ?? $m['id'],
            'context_length' => $m['context_length'] ?? 0,
            'pricing'       => $pricing,
        ];
    }
}

sort( $free_models );

echo "Found " . count( $free_models ) . " free models\n\n";

// Build environment and model arrays
$env_id = 'openrouter-' . time();

$ai_envs = [
    [
        'id'           => $env_id,
        'name'         => 'OpenRouter (Free)',
        'type'         => 'openrouter',
        'apikey'       => $api_key,
        'models'       => [],
        'customModels' => [],
        'deployments'  => [],
    ],
];

$ai_models = [];
$free_model_ids = [];
foreach ( $free_models as $m ) {
    $ai_models[] = [
        'id'             => $m['id'],
        'name'           => $m['name'],
        'type'           => 'openrouter',
        'envId'          => $env_id,
        'tags'           => [ 'core', 'chat' ],
        'context_length' => $m['context_length'],
    ];
    $free_model_ids[] = $m['id'];
}

$default_model = 'openrouter/free';

// Save to database
$options = [
    'version'               => '3.5.3',
    'ai_envs'               => $ai_envs,
    'ai_models'             => $ai_models,
    'ai_allowed_models'     => $free_model_ids,
    'ai_default_env'        => $env_id,
    'ai_default_model'      => $default_model,
    'ai_model_fallback'     => $default_model,
    'ai_env_guardrails'     => true,
    'ai_models_guardrails'  => true,
];

update_option( 'mwai_options', $options );

echo "=== Configuration Complete ===\n";
echo "Environment: OpenRouter (Free)\n";
echo "Default model: $default_model\n";
echo "Free models configured: " . count( $free_models ) . "\n\n";
echo "Available free models:\n";
foreach ( $free_models as $i => $m ) {
    printf( "  %d. %s\n", $i + 1, $m['id'] );
}
echo "\nDone!\n";
