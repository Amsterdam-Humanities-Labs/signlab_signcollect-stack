<?php
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    // Show all tables
    $stmt = $pdo->query("SHOW TABLES");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    echo "Available tables:\n";
    foreach ($tables as $table) {
        echo "- $table\n";
    }
    
    // Look for tables that might contain our data
    echo "\nLooking for tables with 'glos' column:\n";
    foreach ($tables as $table) {
        try {
            $stmt = $pdo->query("DESCRIBE `$table`");
            $columns = $stmt->fetchAll(PDO::FETCH_COLUMN);
            
            if (in_array('glos', $columns)) {
                echo "Table '$table' has 'glos' column\n";
                echo "Columns: " . implode(', ', $columns) . "\n";
                
                // Check if it has form_data
                if (in_array('form_data', $columns)) {
                    echo "  -> This table has form_data column!\n";
                    
                    // Sample a few rows
                    $stmt = $pdo->query("SELECT glos, form_data FROM `$table` WHERE form_data IS NOT NULL LIMIT 3");
                    $samples = $stmt->fetchAll(PDO::FETCH_ASSOC);
                    
                    if (!empty($samples)) {
                        echo "  -> Sample form_data entries:\n";
                        foreach ($samples as $sample) {
                            echo "    " . $sample['glos'] . ": " . $sample['form_data'] . "\n";
                        }
                    }
                }
                echo "\n";
            }
        } catch (Exception $e) {
            // Skip tables we can't access
        }
    }
    
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>