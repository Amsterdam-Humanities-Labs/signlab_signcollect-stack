<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Include database configuration
require_once('../mysql_config.php');

try {
    // Connect to database
    $pdo = new PDO("mysql:host=$servername;dbname=$database", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    
    echo "<h2>Database Examination Results</h2>\n";
    echo "<hr>\n";
    
    // 1. DESCRIBE form_data table
    echo "<h3>1. Table Structure (DESCRIBE form_data)</h3>\n";
    $stmt = $pdo->query("DESCRIBE form_data");
    $columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<table border='1' cellpadding='5' cellspacing='0'>\n";
    echo "<tr><th>Field</th><th>Type</th><th>Null</th><th>Key</th><th>Default</th><th>Extra</th></tr>\n";
    foreach ($columns as $column) {
        echo "<tr>";
        echo "<td>{$column['Field']}</td>";
        echo "<td>{$column['Type']}</td>";
        echo "<td>{$column['Null']}</td>";
        echo "<td>{$column['Key']}</td>";
        echo "<td>{$column['Default']}</td>";
        echo "<td>{$column['Extra']}</td>";
        echo "</tr>\n";
    }
    echo "</table>\n";
    echo "<hr>\n";
    
    // 2. Sample rows with labels containing "1500Gebaren"
    echo "<h3>2. Sample Rows with '1500Gebaren' Label</h3>\n";
    $stmt = $pdo->prepare("SELECT id, glos, thema, labels FROM form_data WHERE labels LIKE '%1500Gebaren%' LIMIT 5");
    $stmt->execute();
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($results)) {
        echo "<table border='1' cellpadding='5' cellspacing='0'>\n";
        echo "<tr><th>ID</th><th>Glos</th><th>Thema</th><th>Labels</th></tr>\n";
        foreach ($results as $row) {
            echo "<tr>";
            echo "<td>{$row['id']}</td>";
            echo "<td>{$row['glos']}</td>";
            echo "<td>{$row['thema']}</td>";
            echo "<td>" . htmlspecialchars($row['labels']) . "</td>";
            echo "</tr>\n";
        }
        echo "</table>\n";
    } else {
        echo "<p><strong>No rows found with '1500Gebaren' label.</strong></p>\n";
    }
    echo "<hr>\n";
    
    // 3. Count of rows with "1500Gebaren" label
    echo "<h3>3. Count of Rows with '1500Gebaren' Label</h3>\n";
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM form_data WHERE labels LIKE '%1500Gebaren%'");
    $stmt->execute();
    $count = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p><strong>Total rows with '1500Gebaren' label: {$count['count']}</strong></p>\n";
    echo "<hr>\n";
    
    // 4. Sample rows with any labels (to see format)
    echo "<h3>4. Sample Rows with Labels (to see format)</h3>\n";
    $stmt = $pdo->prepare("SELECT id, glos, thema, labels FROM form_data WHERE labels IS NOT NULL AND labels != '' LIMIT 10");
    $stmt->execute();
    $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (!empty($results)) {
        echo "<table border='1' cellpadding='5' cellspacing='0'>\n";
        echo "<tr><th>ID</th><th>Glos</th><th>Thema</th><th>Labels</th></tr>\n";
        foreach ($results as $row) {
            echo "<tr>";
            echo "<td>{$row['id']}</td>";
            echo "<td>{$row['glos']}</td>";
            echo "<td>{$row['thema']}</td>";
            echo "<td>" . htmlspecialchars($row['labels']) . "</td>";
            echo "</tr>\n";
        }
        echo "</table>\n";
    } else {
        echo "<p><strong>No rows found with labels.</strong></p>\n";
    }
    echo "<hr>\n";
    
    // 5. Additional analysis - different label search patterns
    echo "<h3>5. Different Search Pattern Tests</h3>\n";
    
    // Test exact match with quotes
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM form_data WHERE labels LIKE '%\"1500Gebaren\"%'");
    $stmt->execute();
    $count1 = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p><strong>Pattern '%\"1500Gebaren\"%': {$count1['count']} rows</strong></p>\n";
    
    // Test case insensitive
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM form_data WHERE labels LIKE '%1500gebaren%'");
    $stmt->execute();
    $count2 = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p><strong>Pattern '%1500gebaren%' (lowercase): {$count2['count']} rows</strong></p>\n";
    
    // Test just the number part
    $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM form_data WHERE labels LIKE '%1500%'");
    $stmt->execute();
    $count3 = $stmt->fetch(PDO::FETCH_ASSOC);
    echo "<p><strong>Pattern '%1500%' (number only): {$count3['count']} rows</strong></p>\n";
    
    // Check unique labels to see what's available
    echo "<h3>6. Unique Labels Analysis</h3>\n";
    $stmt = $pdo->query("SELECT DISTINCT labels FROM form_data WHERE labels IS NOT NULL AND labels != '' AND labels != '[]' LIMIT 20");
    $uniqueLabels = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "<p><strong>Sample unique labels (first 20):</strong></p>\n";
    echo "<ul>\n";
    foreach ($uniqueLabels as $label) {
        echo "<li>" . htmlspecialchars($label['labels']) . "</li>\n";
    }
    echo "</ul>\n";
    
    // 7. Total statistics
    echo "<h3>7. General Statistics</h3>\n";
    $stmt = $pdo->query("SELECT COUNT(*) as total FROM form_data");
    $total = $stmt->fetch(PDO::FETCH_ASSOC);
    
    $stmt = $pdo->query("SELECT COUNT(*) as with_labels FROM form_data WHERE labels IS NOT NULL AND labels != '' AND labels != '[]'");
    $withLabels = $stmt->fetch(PDO::FETCH_ASSOC);
    
    echo "<p><strong>Total rows in form_data: {$total['total']}</strong></p>\n";
    echo "<p><strong>Rows with labels: {$withLabels['with_labels']}</strong></p>\n";
    
} catch (Exception $e) {
    echo "<p><strong>Error: " . htmlspecialchars($e->getMessage()) . "</strong></p>\n";
}
?>