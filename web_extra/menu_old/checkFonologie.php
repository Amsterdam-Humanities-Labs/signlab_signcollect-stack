<?php
// Replace these variables with your actual database credentials
include('/web/mysql_config.php');

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Set the JSON content type header
header('Content-Type: application/json');

// Disable PHP warnings
error_reporting(E_ERROR | E_PARSE);

// Check the connection
if ($conn->connect_error) {
    $output = [
        'error' => '',
        'reason' => 'No MySQL connection'
    ];
    echo json_encode($output);
    exit(); // Exit if there's no connection
}

// Extracting parameters from $_GET
$jsonStr = file_get_contents("php://input");

// Decode the JSON string into an associative array
$data = json_decode($jsonStr, true);

$handedness = '';
$strongHand = '';
$weakHand = '';
$location = '';
$handshapeChange = '';
$relationArticulators = '';
$handLocation = '';
$relOrientationMove = '';
$relOrientationLoc = '';
$orientationChange = '';
$contactType = '';
$movementShape = '';
$movementDirection = '';
$repeatedMovement = '';
$alternatingMovement = '';

// Iterate over the array to extract the values
foreach ($data as $item) {
    switch ($item['id']) {
        case 'Handeness':
            $handedness = $item['value'];
            break;
        case 'strongHand':
            $strongHand = $item['value'];
            break;
        case 'handLocation':
            $handLocation = $item['value'];
            break;
        // Uncomment and adjust these cases if needed
        // case 'weakHand':
        //     $weakHand = $item['value'];
        //     break;
        // case 'HandshapeChange':
        //     $handshapeChange = $item['value'];
        //     break;
        // case 'RelationArticulators':
        //     $relationArticulators = $item['value'];
        //     break;
        // case 'relativeOrienationMovement':
        //     $relOrientationMove = $item['value'];
        //     break;
        // case 'relativeOrienationLocation':
        //     $relOrientationLoc = $item['value'];
        //     break;
        // case 'orientationChange':
        //     $orientationChange = $item['value'];
        //     break;
        // case 'ContactType':
        //     $contactType = $item['value'];
        //     break;
        // case 'MovementShape':
        //     $movementShape = $item['value'];
        //     break;
        // case 'MovementDirection':
        //     $movementDirection = $item['value'];
        //     break;
        // case 'RepeatedMovement':
        //     if($item['value'] == "yes"){
        //         $repeatedMovement = "True";
        //     } elseif($item['value'] == "no"){
        //         $repeatedMovement = "False";
        //     } else {
        //         $repeatedMovement = '';
        //     }
        //     break;
        // case 'AlternatingMovement':
        //     if($item['value'] == "yes"){
        //         $alternatingMovement = "True";
        //     } elseif($item['value'] == "no"){
        //         $alternatingMovement = "False";
        //     } else {
        //         $alternatingMovement = '';
        //     }
        //     break;
    }
}

// Load and decode the Signbank JSON file
$signbankJson = "glosses_transformed.json";
$signbank = file_get_contents($signbankJson);
$decodedData = json_decode($signbank, true); // Decode as an associative array

// Filter the data based on the criteria
$filteredResults = array_filter($decodedData, function ($entry) use ($orientationChange, $handedness, $strongHand, $weakHand, $handLocation, $handshapeChange, $relationArticulators, $contactType, $movementShape, $movementDirection, $repeatedMovement, $alternatingMovement) {
    if (is_string($entry)) {
        $entry = json_decode($entry, true);
    }
    if (!is_array($entry)) {
        return false;
    }
    $details = current($entry);

    $matchesHandedness = empty($handedness) || $details['Handedness'] === $handedness;
    $matchesStrongHand = empty($strongHand) || $details['Strong Hand'] === $strongHand;
    $matchesWeakHand = empty($weakHand) || $details['Weak Hand'] === $weakHand;
    $matchesHandshapeChange = empty($handshapeChange) || $details['Handshape Change'] === $handshapeChange;
    $matchesRelationArticulators = empty($relationArticulators) || $details['Relation Between Articulators'] === $relationArticulators;
    $matchesHandLocation = empty($handLocation) || $details['Location'] === $handLocation;
    $matchesContactType = empty($contactType) || $details['Contact Type'] === $contactType;
    $matchesMovementShape = empty($movementShape) || $details['Movement Shape'] === $movementShape;
    $matchesMovementDirection = empty($movementDirection) || $details['Movement Direction'] === $movementDirection;
    $matchesRepeatedMovement = empty($repeatedMovement) || $details['Repeated Movement'] === $repeatedMovement;
    $matchesAlternatingMovement = empty($alternatingMovement) || $details['Alternating Movement'] === $alternatingMovement;
    $matchesOrientationChange = empty($orientationChange) || $details['Orientation Change'] === $orientationChange;

    return $matchesHandedness && $matchesStrongHand && $matchesWeakHand && $matchesHandshapeChange && $matchesRelationArticulators && $matchesHandLocation && $matchesContactType && $matchesMovementShape && $matchesMovementDirection && $matchesRepeatedMovement && $matchesAlternatingMovement && $matchesOrientationChange;
});

// Extract data from filtered results
$extractedData = [];
foreach ($filteredResults as $item) {
    foreach ($item as $id => $details) {
        $senses = [];
        foreach ($details['Senses: Dutch'] as $skey => $svalue) {
            $senses[] = $svalue;
        }
        $extractedData[] = [
            'glos' => $details['Annotation ID Gloss: Dutch'],
            'video' => $details['Video'],
            'source' => 'Signbank',
            'reason' => $senses,
            'link' => $details['Link'],
            'glosID' => $id,
            'glosZoekInput' => $details['Annotation ID Gloss: Dutch'],
            'Handeness' => $details['Handedness'],
            'strongHand' => $details['Strong Hand'],
            'weakHand' => $details['Weak Hand'],
            'HandshapeChange' => $details['Handshape Change'],
            'RelationArticulators' => $details['Relation Between Articulators'],
            'handLocation' => $details['Location'],
            'ContactType' => $details['Contact Type'],
            'MovementShape' => $details['Movement Shape'],
            'MovementDirection' => $details['Movement Direction'],
            'relativeOrienationMovement' => $details['Relative Orientation Movement'],
            'relativeOrienationLocation' => $details['Relative Orientation Location'],
            'orientationChange' => $details['Orientation Change'],
            'RepeatedMovement' => $details['Repeated Movement'],
            'AlternatingMovement' => $details['Alternating Movement'],
            'virtualObjectt' => $details['Virtual Object'],
            'phonologyOther' => $details['Phonology Other'],
            'mouthGesture' => $details['Mouth Gesture'],
            'mouthing' => $details['Mouthing'],
            'phoneticVariation' => $details['Phonetic Variation'],
            'senses' => $senses
        ];
    }
}

// Query form_data database for phonology information
$query = "SELECT * FROM form_data WHERE glosZichtbaar = '0'";
$stmt = $conn->prepare($query);
$stmt->execute();
$result = $stmt->get_result();

$foundArray = [];
while ($row = $result->fetch_assoc()) {
    $matchesHandedness = empty($handedness) || $row['Handeness'] === $handedness;
    $matchesStrongHand = empty($strongHand) || $row['strongHand'] === $strongHand;
    $matchesWeakHand = empty($weakHand) || $row['weakHand'] === $weakHand;
    $matchesHandLocation = empty($handLocation) || $row['handLocation'] === $handLocation;
    // Add other matching conditions if needed

    if ($matchesHandedness && $matchesStrongHand && $matchesWeakHand && $matchesHandLocation) {
        $foundArray[] = $row;
        //we want to add ""source" signCollect to the foundArray of the same key
        $foundArray[count($foundArray) - 1]['source'] = 'SignCollect';
    }
}

// Merge the foundArray with the extractedData
$extractedData = array_merge($extractedData, $foundArray);

// Output the final extracted data
echo json_encode($extractedData);
?>
