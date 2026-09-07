<?php
// Set the JSON content type header
header('Content-Type: application/json');

//disable php warning
error_reporting(E_ERROR | E_PARSE);
$id = strtoupper($_GET['id']); //we zoeken eerst naar woordvorm

// Function to return "no" for False and "yes" for True
function getYesNoString($value) {
    if($value == "False")
    {
        return "no";
    }
    elseif($value == "True")
    {
        return "yes";
    }
    else
    {
        return $value;
    }
}

$glosses = file_get_contents('glosses_transformed.json');
$glosses = json_decode($glosses, true);

$flattenedArray = [];
foreach ($glosses as $entry) {
    foreach ($entry as $key => $value) {
        $flattenedArray[$key] = $value;
    }
}

//then we look for the signbank id in the JSON
if(isset($flattenedArray[$id]))
{
    $entry = $flattenedArray[$id];
    $output = [
        'glos' => $entry['Annotation ID Gloss: Dutch'] ?? '',
        'Handeness' => $entry['Handedness'] ?? '',
        'strongHand' => $entry['Strong Hand'] ?? '',
        'weakHand' => $entry['Weak Hand'] ?? '',
        'HandshapeChange' => $entry['Handshape Change'] ?? '',
        'RelationArticulators' => $entry['Relation Between Articulators'] ?? '',
        'handLocation' => $entry['Location'] ?? '',
        'ContactType' => $entry['Contact Type'] ?? '',
        'MovementShape' => $entry['Movement Shape'] ?? '',
        'MovementDirection' => $entry['Movement Direction'] ?? '',
        'relativeOrienationMovement' => $entry['Relative Orientation: Movement'] ?? '',
        'relativeOrienationLocation' => $entry['Relative Orientation: Location'] ?? '',        
        'orientationChange' => $entry['Orientation Change'] ?? '',
        'RepeatedMovement' => getYesNoString($entry['Repeated Movement']) ?? '',
        'AlternatingMovement' => getYesNoString($entry['Alternating Movement']) ?? '',
        'virtualObjectt' => $entry['Virtual Object'] ?? '',
        'phonologyOther' => $entry['Phonology Other'] ?? '',
        'mouthGesture' => $entry['Mouth Gesture'] ?? '',
        'mouthing' => $entry['Mouthing'] ?? '',
        'phoneticVariation' => $entry['Phonetic Variation'] ?? '',
        'status' => 'success'
    ];

    echo json_encode($output);
}
else
{
    echo json_encode([
        'status' => 'error',
    ]);
}
        




?>