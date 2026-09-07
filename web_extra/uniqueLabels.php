<?php
// Include database configuration
include('mysql_config.php');

// Create connection
$conn = new mysqli($servername, $username, $password, $database);

// Check connection
if ($conn->connect_error) {
    header('Content-Type: application/json');
    die(json_encode(["error" => "Connection failed: " . $conn->connect_error]));
}

// Set charset
$conn->set_charset("utf8");

// Initialize parameters
$extern = null;
$whereConditions = [];
$params = [];
$types = "";

// Handle 'extern' filter if provided
if (isset($_GET['extern'])) {
    $extern = intval($_GET['extern']);
    $whereConditions[] = "extern = ?";
    $params[] = $extern;
    $types .= "i";
}

// Build the base query - Now including color field
$sql = "SELECT DISTINCT label, color FROM labels WHERE label IS NOT NULL AND label != ''";

// Add any where conditions
if (!empty($whereConditions)) {
    $sql .= " AND " . implode(" AND ", $whereConditions);
}

// Add ordering
$sql .= " ORDER BY label ASC";

// Prepare and execute statement
$stmt = $conn->prepare($sql);

// Bind parameters if any
if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
}

$stmt->execute();
$result = $stmt->get_result();

// Process results into an array of label objects with name and color
$labels = array();
while ($row = $result->fetch_assoc()) {
    $rowLabels = explode(',', $row['label']);
    foreach ($rowLabels as $label) {
        $trimmedLabel = trim($label);
        if (!empty($trimmedLabel)) {
            // Check if this label is already in our array
            $labelExists = false;
            foreach ($labels as $existingLabel) {
                if ($existingLabel['name'] === $trimmedLabel) {
                    $labelExists = true;
                    break;
                }
            }
            
            // If label doesn't exist yet, add it with its color
            if (!$labelExists) {
                $labels[] = [
                    'name' => $trimmedLabel,
                    'color' => $row['color'] ?? '#e9ecef' // Default color if null
                ];
            }
        }
    }
}

// Sort labels by name
usort($labels, function($a, $b) {
    return strcmp($a['name'], $b['name']);
});

// Return as JSON
header('Content-Type: application/json');
echo json_encode($labels);

// Close connections
$stmt->close();
$conn->close();
?>
