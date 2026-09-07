<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check what status values exist
    $sql = "SELECT DISTINCT studioOpnameStatus, COUNT(*) as count FROM form_data GROUP BY studioOpnameStatus";
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Studio opname status values:\n";
    foreach ($results as $result) {
        echo "- '" . $result['studioOpnameStatus'] . "': " . $result['count'] . " records\n";
    }
    
    // Now test with any status for 1500Gebaren
    echo "\nTesting 1500Gebaren without status filter:\n";
    $sql = "SELECT id, glos, thema, studioOpnameStatus, labels FROM form_data 
            WHERE labels LIKE :label0
            ORDER BY glos LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':label0' => '%"1500Gebaren"%']);
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($results) . " videos with '1500Gebaren' label:\n\n";
    
    foreach ($results as $result) {
        echo "ID: " . $result['id'] . "\n";
        echo "Glos: " . $result['glos'] . "\n";
        echo "Thema: " . $result['thema'] . "\n";
        echo "Status: " . $result['studioOpnameStatus'] . "\n";
        echo "Labels: " . $result['labels'] . "\n";
        echo "---\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>