<?php
require_once('../mysql_config.php');

header('Content-Type: application/json');

// Test the exact query used in fetch_videos_with_labels.php
$labels = ['1500Gebaren'];

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Build the same query as in fetch_videos_with_labels.php
    $sql = "SELECT f.id, f.glos, f.thema, f.labels, m.m_file as video_file 
            FROM form_data f 
            INNER JOIN matched_transcriptions m ON f.glos = m.definitive_outcome 
            WHERE m.m_file IS NOT NULL AND m.m_file != ''";
    $params = [];
    
    // Add label filter exactly as in the main code
    if (!empty($labels)) {
        $labelConditions = [];
        foreach ($labels as $index => $label) {
            $paramName = ":label$index";
            $labelConditions[] = "f.labels LIKE $paramName";
            $params[$paramName] = '%"' . $label . '"%';
        }
        if (!empty($labelConditions)) {
            // Use AND to require ALL selected labels
            $sql .= " AND (" . implode(' AND ', $labelConditions) . ")";
        }
    }
    
    $sql .= " ORDER BY glos LIMIT 10";
    
    echo "Query: " . $sql . "\n";
    echo "Params: " . json_encode($params) . "\n\n";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute($params);
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Results count: " . count($results) . "\n";
    echo "Sample results:\n";
    foreach ($results as $result) {
        echo "- " . $result['glos'] . " (labels: " . $result['labels'] . ")\n";
    }
    
    // Also test without the video file join to see if the issue is there
    echo "\n--- Testing without video file requirement ---\n";
    $sql2 = "SELECT f.id, f.glos, f.thema, f.labels 
            FROM form_data f 
            WHERE f.labels LIKE :label0
            ORDER BY glos LIMIT 10";
    
    $stmt2 = $pdo->prepare($sql2);
    $stmt2->execute($params);
    
    $results2 = $stmt2->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Results without video requirement: " . count($results2) . "\n";
    foreach ($results2 as $result) {
        echo "- " . $result['glos'] . " (labels: " . $result['labels'] . ")\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>