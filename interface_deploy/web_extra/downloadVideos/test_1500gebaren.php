<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Test query for 1500Gebaren
    $sql = "SELECT id, glos, thema, videoCenter, labels FROM form_data 
            WHERE studioOpnameStatus = 'StudioOpname' 
            AND JSON_CONTAINS(labels, JSON_QUOTE('1500Gebaren'))
            LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($results) . " videos with '1500Gebaren' label:\n\n";
    
    foreach ($results as $result) {
        echo "ID: " . $result['id'] . "\n";
        echo "Glos: " . $result['glos'] . "\n";
        echo "Thema: " . $result['thema'] . "\n";
        echo "Labels: " . $result['labels'] . "\n";
        echo "Has video: " . (!empty($result['videoCenter']) ? 'Yes' : 'No') . "\n";
        echo "---\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>