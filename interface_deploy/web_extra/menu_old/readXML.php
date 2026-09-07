<?php

ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);
// Load the XML
$xml=simplexml_load_file("ngt.ecv") or die("Error: Cannot create object");

$needle = $_GET['woord'];

// Define the word to se
// Define the search term you want to find
// Use XPath to select all elements in the XML document
$elements = $xml->xpath('//*');
$matchingElements = [];

// Loop through the selected elements and print them
foreach ($elements as $element) {

    $pattern = '/\b'.$needle.'\b/i';

    // Perform the search using preg_match_all

    
    if($element['CVE_ID'])
    {
        $CVE_ID = $element['CVE_ID'];
    }

    $text = $element[0]." ";
    $text.= $element[0]->attributes();
  
    preg_match_all($pattern, $text, $matches);


   if($matches[0])
   { 
    $matchingElements[] = $CVE_ID;
   }

}

$resultArray = [
    'CVE_ID' => $matchingElements
];

// Encode the result array as JSON
$jsonResult = json_encode($resultArray);

// Set the response content type to JSON
header('Content-Type: application/json');

// Output the JSON result
echo $jsonResult;
?>
