<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check some sample labels
    $sql = "SELECT glos, labels FROM form_data 
            WHERE labels IS NOT NULL AND labels != '[]' AND labels != ''
            LIMIT 10";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Sample labels in database:\n\n";
    
    foreach ($results as $result) {
        echo "Glos: " . $result['glos'] . "\n";
        echo "Labels: " . $result['labels'] . "\n";
        echo "---\n";
    }
    
    // Check for any label containing "1500"
    echo "\nSearching for labels containing '1500':\n";
    $sql = "SELECT glos, labels FROM form_data 
            WHERE labels LIKE '%1500%'
            LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($results as $result) {
        echo "Glos: " . $result['glos'] . "\n";
        echo "Labels: " . $result['labels'] . "\n";
        echo "---\n";
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>