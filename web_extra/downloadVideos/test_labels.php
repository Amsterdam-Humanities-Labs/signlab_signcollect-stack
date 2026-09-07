<?php
// Test script to debug label filtering issue

// Simulate the exact same API call as the main script
$apiUrl = "/fetch_all2.php?extern=1&limit=10000&status=StudioOpname&handle=statusFilter";
$jsonData = file_get_contents($apiUrl);

if ($jsonData === false) {
    echo "Failed to fetch data from API\n";
    exit;
}

$data = json_decode($jsonData, true);

if (!isset($data['data']) || empty($data['data'])) {
    echo "No data found\n";
    exit;
}

$searchLabel = "1500Gebaren";
$foundCount = 0;
$totalCount = 0;

echo "Searching for label: $searchLabel\n";
echo "Total items to check: " . count($data['data']) . "\n\n";

foreach ($data['data'] as $item) {
    $totalCount++;
    $glos = $item['glos'];
    
    if (!empty($item['form_data'])) {
        $formData = json_decode($item['form_data'], true);
        if (is_array($formData)) {
            // Check if this item has the search label
            if (in_array($searchLabel, $formData)) {
                $foundCount++;
                echo "FOUND #$foundCount: $glos\n";
                echo "  Labels: " . json_encode($formData) . "\n";
                echo "  Raw form_data: " . $item['form_data'] . "\n\n";
                
                // Stop after finding 5 examples
                if ($foundCount >= 5) {
                    break;
                }
            }
        }
    }
}

echo "=== SUMMARY ===\n";
echo "Total items checked: $totalCount\n";
echo "Items with '$searchLabel' label: $foundCount\n";

// Also check first 3 items to see what labels look like
echo "\n=== FIRST 3 ITEMS SAMPLE ===\n";
for ($i = 0; $i < min(3, count($data['data'])); $i++) {
    $item = $data['data'][$i];
    echo "Item " . ($i + 1) . ": " . $item['glos'] . "\n";
    echo "  form_data: " . ($item['form_data'] ?? 'NULL') . "\n";
    if (!empty($item['form_data'])) {
        $formData = json_decode($item['form_data'], true);
        if (is_array($formData)) {
            echo "  Parsed labels: " . json_encode($formData) . "\n";
        }
    }
    echo "\n";
}
?>