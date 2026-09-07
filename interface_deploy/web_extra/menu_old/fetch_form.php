<?php
include('/web/mysql_config.php');

// Disable PHP warnings
error_reporting(E_ERROR | E_PARSE);

// Create a connection to the database
$conn = new mysqli($servername, $username, $password, $database);

// Check the connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Fetch data based on provided parameters
$id = $_GET['id'] ?? "660";
$glos = $_GET['glos'] ?? null;

if ($id || $glos) {
    $stmt = null;
    if ($id) {
        $stmt = $conn->prepare("SELECT * FROM form_data WHERE id = ?");
        $stmt->bind_param("i", $id);
    } else if ($glos) {
        $stmt = $conn->prepare("SELECT * FROM form_data WHERE glos = ?");
        $stmt->bind_param("s", $glos);
    }

    $stmt->execute();
    $result = $stmt->get_result();





    // Check if a record is found
    if ($result->num_rows > 0) {

        $row = $result->fetch_assoc();



        //we are going to look in CameraRecords for videoTop
        
        $videoTop = [];
        $videoLabel = [];
        $videoCategory = [];
        $cameraRecordsSql = "
        SELECT * 
        FROM CameraRecords 
        WHERE glosId = '" . $id . "' 
        AND (zOg NOT LIKE 'Zin') 
        AND (stateVideo IS NULL OR stateVideo NOT LIKE 'DELETE')
    ";
            $cameraRecordsResult = $conn->query($cameraRecordsSql);
        if ($cameraRecordsResult->num_rows > 0) {
            // echo "cameraRecordsResult";
            while ($cameraRecordRow = $cameraRecordsResult->fetch_assoc()) {
                $videoTop[] = array("file" => $cameraRecordRow["videoTop"]);
                $videoLabel[] = $cameraRecordRow['videoLabel'];
                $videoCategory[] = $cameraRecordRow['videoCategory'];
                // echo $cameraRecordRow["videoLabel"];
            }
            $videoTop = json_encode($videoTop);

        }
        else
        {            //we are going to convert videoTop to file and only output file in array
            $videoTopData = json_decode($row["videoTop"], true);

            if (!empty($videoTopData)) {
                // Check if videoTop is a valid array
                foreach ($videoTopData as $video) {
                    // Check if 'videoTop' key exists in each item
                    if (isset($video['videoTop'])) {
                        #block out userid 14 and 15 (henrianne and diego)
                        if($video['userid'] == "14" || $video['userid'] == "15")
                        {
                            continue;
                        }
                        $videoTop[] = array("file" => $video['videoTop']);

                    }
                }
                $videoTop = json_encode($videoTop);
                $videoLabel = json_encode($videoLabel);
                $videoCategory = json_encode($videoCategory);

            }
            
        }

        //if $videotop is still empty then convert to json
        if (empty($videoTop)) {
            $videoTop = json_encode($videoTop);
            $videoLabel = json_encode($videoLabel);
            $videoCategory = json_encode($videoCategory);
        }
    




        // Create an array to hold the data to return
        $data = array(
            "woord" => $row["woord"],
            "signbank" => $row["signbank"],
            "actie" => $row["actie"],
            "entry" => $row["entry"], 
            "glos" => htmlspecialchars($row["glos"], ENT_QUOTES, 'UTF-8'),
            "wanneer" => $row["wanneer"],
            "control_nodig" => $row["control_nodig"],
            "fonologie_fase1" => $row["fonologie_fase1"],
            "fonologie_fase2" => $row["fonologie_fase2"],
            "senses" => $row["senses"],
            "sensesEngels" => $row["sensesEngels"],
            "linkSignbank" => $row["linkSignbank"],
            "logboek" => $row["logboek"],
            "gbc" => $row["gbc"],
            "wie" => json_decode($row["wie"]),
            "wie_snel_opname" => json_decode($row["wie_snel_opname"]),
            "videoLeft" => $row["videoLeft"],
            "videoCenter" => $row["videoCenter"],
            "videoRight" => $row["videoRight"],
            "studioOpnameStatus" => $row["studioOpnameStatus"],
            "studioOpnameWie" => $row["studioOpnameWie"],
            "glosZichtbaar" => $row["glosZichtbaar"],
            "zelfopname" => $row["zelfopname"],
            "signbank_opname" => $row["signbank_opname"],
            "thema" => $row["thema"],
            "woord" => $row["woord"],
            "glos_engels" => $row["glos_engels"],
            "Handeness" => $row["Handeness"],
            "strongHand" => $row["strongHand"],
            "weakHand" => $row["weakHand"],
            "HandshapeChange" => $row["HandshapeChange"],
            "handLocation" => $row["handLocation"],
            "RelationArticulators" => $row["RelationArticulators"],
            "relativeOrienationMovement" => $row["relativeOrienationMovement"],
            "relativeOrienationLocation" => $row["relativeOrienationLocation"],
            "orientationChange" => $row["orientationChange"],
            "ContactType" => $row["ContactType"],
            "MovementShape" => $row["MovementShape"],
            "MovementDirection" => $row["MovementDirection"],
            "RepeatedMovement" => $row["RepeatedMovement"],
            "AlternatingMovement" => $row["AlternatingMovement"],
            "virtualObjectt" => $row["virtualObjectt"],
            "phonologyOther" => $row["phonologyOther"],
            "mouthGesture" => $row["mouthGesture"],
            "mouthing" => $row["mouthing"],
            "phoneticVariation" => $row["phoneticVariation"],
            "status" => "success",
            "processed" => "",
            "id" => $row["id"],
            "morfologie" => $row["morfologie"],
            "videoA" => $row["videoA"],
            "videoB" => $row["videoB"],        
            "videoTop" => $videoTop,
            "freemocap" => [],
            "videoLabel" => $videoLabel,
            "videoCategory" => $videoCategory,
            "werkwoord" => $row["werkwoord"]
        );

        // Add videos from matched_transcriptions table
        $stmt = $conn->prepare("SELECT * FROM matched_transcriptions WHERE definitive_outcome = ? AND (zOg = 'Glos' OR zOg = '' OR zOg = 'glos' OR zOg = 'extern' OR zOg = 'labels') AND added != 'DELETE' ORDER BY date DESC, time DESC");
        $stmt->bind_param("s", $row["id"]);
        $stmt->execute();
        $result = $stmt->get_result();

        // //we are going to look for videotop from CameraRecords
        // $stmt = $conn->prepare("SELECT * FROM CameraRecords WHERE (zOg = 'Glos' OR zOg IS NULL) AND glosId = ?");
        // $stmt->bind_param("s", $id);
        // $stmt->execute();
        // $resulta = $stmt->get_result();

        
        $videoLeft = [];
        $videoCenter = [];
        $videoRight = [];
        $videoA = [];
        $videoB = [];
        
        while ($transcription_row = $result->fetch_assoc()) {
            $videoLeft[] = array("file" => str_replace(".wav", ".mp4", $transcription_row["l_file"]));
            $videoCenter[] = array("file" => str_replace(".wav", ".mp4", $transcription_row["m_file"]), "id" => $transcription_row["id"], "added" => $transcription_row["added"], "post_processed" => $transcription_row["post_processed"]);
            $videoRight[] = array("file" => str_replace(".wav", ".mp4", $transcription_row["r_file"]));
            $videoA[] = array("file" => str_replace(".wav", ".mp4", $transcription_row["a_file"]));
            $videoB[] = array("file" => str_replace(".wav", ".mp4", $transcription_row["b_file"]));
            // $videoLabel[] = array("file" => $transcription_row["videoLabel"]);
            // $videoCategory[] = array("file" => $transcription_row["videoCategory"]);

            if($transcription_row["post_processed"] == "1") {
                $data["processed"] = "2";
            }
        }


     
        // while($asd = $resulta->fetch_assoc()){
        //     $videoTop[] = array("file" => $asd["videoTop"]);

        // }

        // if ($resulta->num_rows > 0) {
        //     $data["videoTop"] = json_encode($videoTop);
        // }
        // else
        // {
        //     $data["videoTop"] = json_encode($videoTop);
        // }

        if ($result->num_rows > 0) {
            $data["videoLeft"] = json_encode($videoLeft);
            $data["videoCenter"] = json_encode($videoCenter);
            $data["videoRight"] = json_encode($videoRight);
            $data["videoA"] = json_encode($videoA);
            $data["videoB"] = json_encode($videoB);
            $data["videoLabel"] = json_encode($videoLabel);
            $data["videoCategory"] = json_encode($videoCategory);

            $lala = str_replace(".mp4", "", $videoCenter[0]["file"]);
            $lala = str_replace(".wav", "", $lala);

            $searchPattern = '%' . $lala . '%'; // Use a separate variable for the pattern

            // echo $searchPattern;
            // print_r($data);

            $stmt = $conn->prepare("SELECT * FROM freemocap_data WHERE m_file LIKE ?");
            $stmt->bind_param("s", $searchPattern); // Pass the variable by reference
            $stmt->execute();
            $result = $stmt->get_result();

            while ($freemocap_row = $result->fetch_assoc()) {
                $data["freemocap"] = array("file" => str_replace("M2024", "2024", str_replace(".mp4", "", $freemocap_row["m_file"])));

            }
        } else {
            // For the old video formats, add the video from form_data to matched_transcriptions
            // $videoLeft = json_decode($data["videoLeft"], true); // true to decode as an array
            // $videoCenter = json_decode($data["videoCenter"], true); // true to decode as an array
            // $videoRight = json_decode($data["videoRight"], true); // true to decode as an array

            // function processVideos($videos) {
            //     $videos = array_filter($videos, function($file) {
            //         return strpos($file["file"], ".MP4") !== false;
            //     });
            
            //     return array_map(function($file) {
            //         $filename = basename($file["file"], ".MP4") . ".wav";
            //         $file["file"] = $filename;
            //         return $file;
            //     }, $videos);
            // }
       


            // if ((is_array($videoLeft) && count($videoLeft) > 0) || (is_array($videoCenter) && count($videoCenter) > 0) || (is_array($videoRight) && count($videoRight) > 0)) {

            //     $videoLeft = processVideos($videoLeft);
            //     $videoCenter = processVideos($videoCenter);
            //     $videoRight = processVideos($videoRight);

            //     $stmt = $conn->prepare("
            //         INSERT INTO matched_transcriptions (l_file, m_file, r_file, definitive_outcome, l_transcription, m_transcription, r_transcription, added)
            //         VALUES (?, ?, ?, ?, ?, ?, ?, '1')
            //     ");
            //     $stmt->bind_param("sssssss", $videoLeft[0]["file"], $videoCenter[0]["file"], $videoRight[0]["file"], $data["id"], $data["id"], $data["id"], $data["id"]);
            //     $stmt->execute();
            // }
        }
        //convert special chars in JSON to unicode
        // $data = json_encode($data, JSON_UNESCAPED_UNICODE);
        // Return the data as JSON
        header("Content-Type: application/json");
        echo json_encode($data);
    } else {
        $response = array("status" => "notfound", "message" => "No record found for given parameter.");
        header("Content-Type: application/json");
        echo json_encode($response);
    }
} else {
    $response = array("status" => "error", "message" => "No ID or gloss provided.");
    header("Content-Type: application/json");
    echo json_encode($response);
}

// Close the database connection
$conn->close();
?>
