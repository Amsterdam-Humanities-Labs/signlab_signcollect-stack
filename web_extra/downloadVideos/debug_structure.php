<?php
// Debug script to examine the data structure

$apiUrl = "/fetch_all2.php?extern=1&limit=10&status=StudioOpname&handle=statusFilter";
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

echo "=== EXAMINING FIRST ITEM STRUCTURE ===\n";
$firstItem = $data['data'][0];
echo "All available fields:\n";
foreach ($firstItem as $key => $value) {
    echo "  $key: ";
    if (is_string($value)) {
        echo "\"$value\"\n";
    } else {
        echo json_encode($value) . "\n";
    }
}

echo "\n=== SEARCHING FOR ITEMS WITH NON-NULL form_data ===\n";
$foundWithFormData = 0;
foreach ($data['data'] as $index => $item) {
    if (!empty($item['form_data'])) {
        $foundWithFormData++;
        echo "Item $index: " . $item['glos'] . "\n";
        echo "  form_data: " . $item['form_data'] . "\n";
        
        if ($foundWithFormData >= 3) {
            break;
        }
    }
}

if ($foundWithFormData === 0) {
    echo "No items found with form_data! Let's check if there's a different field name...\n";
    
    // Check if there are other fields that might contain labels
    echo "\n=== CHECKING FOR POSSIBLE LABEL FIELDS ===\n";
    foreach ($firstItem as $key => $value) {
        if (stripos($key, 'label') !== false || 
            stripos($key, 'form') !== false || 
            stripos($key, 'tag') !== false ||
            stripos($key, 'category') !== false) {
            echo "Possible label field: $key = " . json_encode($value) . "\n";
        }
    }
}
?>