<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Check table structure
    $stmt = $pdo->query("DESCRIBE matched_transcriptions");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Columns in matched_transcriptions table:\n";
    foreach ($columns as $column) {
        echo "- " . $column['Field'] . " (" . $column['Type'] . ")\n";
    }
    
    // Check some sample data
    echo "\nSample data from matched_transcriptions:\n";
    $stmt = $pdo->query("SELECT * FROM matched_transcriptions LIMIT 3");
    $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    foreach ($samples as $index => $sample) {
        echo "\nRecord " . ($index + 1) . ":\n";
        foreach ($sample as $key => $value) {
            echo "  $key: " . (is_null($value) ? 'NULL' : $value) . "\n";
        }
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>