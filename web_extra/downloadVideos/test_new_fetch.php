<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Test the same query as our fetch script
    $sql = "SELECT id, glos, thema, videoCenter, labels FROM form_data 
            WHERE studioOpnameStatus = 'StudioOpname' 
            AND labels LIKE :label0
            ORDER BY glos LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([':label0' => '%"1500Gebaren"%']);
    
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