<?
include('../mysql_config.php');

//connect to db and get table CameraRecords
$mysqli = new mysqli($servername, $username, $password, $database);
if ($mysqli->connect_errno) {
    echo "Failed to connect to MySQL: (" . $mysqli->connect_errno . ") " . $mysqli->connect_error;
}

//get all records from CameraRecords
$result = $mysqli->query("SELECT * FROM CameraRecords WHERE stateVideo = 'stopped' AND zOg = 'nmm'");
$records = $result->fetch_all(MYSQLI_ASSOC);

//forloop and put in array
$glosses_cr = array();
foreach($records as $record){
    $glosses_cr[] = $record['glos'];
}

//get all records from nmm_data
$result = $mysqli->query("SELECT * FROM nmm_data WHERE type = 'ready'");
$records = $result->fetch_all(MYSQLI_ASSOC);
$nmm_data = array();
foreach($records as $record){
    $nmm_data[] = $record;
}


//get liteGlos.json
$filename = "liteGlos.json";
$handle = fopen($filename, "r");
$contents = fread($handle, filesize($filename));
fclose($handle);

//convert json to array
$glosses = json_decode($contents, true);

//get key summary
$summary = $glosses['summary']['glosses_with_empty_matched_transcriptions_and_nme_videos'];

//limit to 5 items of $summary
// $summary = array_slice($summary, 0, 5);
// Create an array to hold the glosses
$output = array();
$output_mg = array();
// Add glosses to the output
foreach($summary as $key => $value){
    // Check if the gloss is in the CameraRecords
    // echo $value;
    if(!in_array($value, $glosses_cr)){
        //we want to add ID, signbank, type and nmmId to the output
        $nmmfound = false;
        foreach($nmm_data as $nmm){
            if($nmm['glos'] == $value){
                $value = array();
                $value['id'] = $nmm['id'];
                $value['signbank'] = $nmm['signbank_id'];
                $value['type'] = $nmm['type'];
                $value['nmmId'] = $nmm['id'];
                $value['glos'] = $nmm['glos'];
                $value['thema'] = "ALLES";
                $value['zelfopname'] = $nmm['zelfopname'];
                $output[] = $value;
                $nmmfound = true;
            }
        }
        if($nmmfound)
        {
            if(!in_array($value, $output))
            {
                $output[] = $value;
            }
        }
        else
        {
            //we are going to add new row to nmm_data table
            $sql = "INSERT INTO nmm_data (glos, type, thema) VALUES ('$value', 'ready', 'ALLES')";
            $mysqli->query($sql);
            $nmmId = $mysqli->insert_id;
            $value = array();
            $value['id'] = $nmmId;
            $value['signbank'] = "";
            $value['type'] = "ready";
            $value['nmmId'] = $nmmId;
            $value['glos'] = $value;
            $value['thema'] = "ALLES";
            $output[] = $value;
        }
    }
    else
    {
        foreach($nmm_data as $nmm){
            if($nmm['glos'] == $value){
                $value = array();
                $value['ID'] = $nmm['id'];
                $value['signbank'] = $nmm['signbank_id'];
                $value['type'] = $nmm['type'];
                $value['nmmId'] = $nmm['id'];
                $value['glos'] = $nmm['glos'];
                $value['thema'] = "ALLES";
                $output_mg[] = $value;
                $nmmfound = true;
            }
        }
    }
}
//count output
$count_rows = count($output);

//echo output with count_rows
echo json_encode(array('unmatchedGloss' => $output, 'matchedGlosses' => $output_mg, 'matchedCount' => $count_rows, 'unmatchedCount' => count($output_mg)));


?>