import json
import sys
import os
import mysql.connector
from mysql.connector import Error

def get_db_connection(db_config):
    """
    Establishes a connection to the MySQL database.

    Parameters:
        db_config (dict): A dictionary containing database connection parameters.

    Returns:
        mysql.connector.connection.MySQLConnection: The database connection object.
    """
    try:
        connection = mysql.connector.connect(**db_config)
        if connection.is_connected():
            print("Successfully connected to the database.")
            return connection
    except Error as e:
        print(f"Error connecting to MySQL: {e}", file=sys.stderr)
    return None

def fetch_gloss_to_id(connection):
    """
    Fetches glosses and their corresponding IDs from the nmm_data table.

    Parameters:
        connection (mysql.connector.connection.MySQLConnection): The database connection object.

    Returns:
        dict: A dictionary mapping glosses to their list of IDs.
    """
    gloss_to_id = {}
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT id, glos FROM nmm_data")
        results = cursor.fetchall()
        for row in results:
            gloss = row.get('glos', '')
            gloss_id = row.get('id')
            if gloss and gloss_id:
                if gloss in gloss_to_id:
                    gloss_to_id[gloss].append(gloss_id)
                else:
                    gloss_to_id[gloss] = [gloss_id]
        cursor.close()
        print(f"Fetched {len(gloss_to_id)} unique glosses from nmm_data.")
    except Error as e:
        print(f"Error fetching data from nmm_data: {e}", file=sys.stderr)
    return gloss_to_id

def fetch_id_to_m_files(connection):
    """
    Fetches transcription files associated with each gloss ID from the matched_transcriptions table.
    Determines the base_video_url based on the 'post_processed' field.

    Parameters:
        connection (mysql.connector.connection.MySQLConnection): The database connection object.

    Returns:
        dict: A dictionary mapping gloss IDs to lists of transcription file links.
    """
    id_to_m_files = {}
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute("""
            SELECT m_transcription, m_file, post_processed, zOg 
            FROM matched_transcriptions 
            WHERE zOg LIKE '%nmm%' AND added='1' AND signbank_upload = '1'
        """)
        results = cursor.fetchall()
        for row in results:
            m_transcription = row.get('m_transcription')
            m_file = row.get('m_file', '').strip()
            post_processed = row.get('post_processed')  # Could be None or "1"

            # Skip entries without necessary fields
            if not m_transcription or not m_file:
                continue

            # Determine base_video_url based on 'post_processed'
            if post_processed is None:
                base_video_url = "https://signcollect.nl/gebarenoverleg_media/studioFilesMini/raw"
            elif post_processed == "1":
                base_video_url = "https://signcollect.nl/gebarenoverleg_media/studioFilesMini/post"
            else:
                # Handle unexpected values by defaulting to 'raw'
                base_video_url = "https://signcollect.nl/gebarenoverleg_media/studioFilesMini/raw"
                print(f"Warning: Unexpected 'post_processed' value for gloss ID {m_transcription}: {post_processed}", file=sys.stderr)

            # Convert .wav to .mp4 by replacing the extension
            if m_file.lower().endswith('.wav'):
                m_file_mp4 = m_file[:-4] + '.mp4'
            else:
                m_file_mp4 = m_file  # If not .wav, keep as is

            # Construct the full URL
            m_file_url = os.path.join(base_video_url, m_file_mp4).replace("\\", "/")

            # Map m_transcription (gloss_id) to its transcription URLs
            if m_transcription in id_to_m_files:
                id_to_m_files[m_transcription].append(m_file_url)
            else:
                id_to_m_files[m_transcription] = [m_file_url]

        cursor.close()
        print(f"Fetched transcription files for {len(id_to_m_files)} unique gloss IDs from matched_transcriptions.")
    except Error as e:
        print(f"Error fetching data from matched_transcriptions: {e}", file=sys.stderr)
    return id_to_m_files

def extract_fields(input_data, gloss_to_id, id_to_m_files):
    """
    Extracts required fields from the input JSON data, enriching it with transcription file links.
    Additionally, adds NME_Videos when matched_transcriptions is empty and counts multiple NME_Videos.

    Parameters:
        input_data (list): The list of dictionaries from the input JSON.
        gloss_to_id (dict): A dictionary mapping glosses to their list of IDs.
        id_to_m_files (dict): A dictionary mapping gloss IDs to transcription file links.

    Returns:
        tuple: A tuple containing the list of extracted items, count_glos, nmm, count_empty_matched_and_nme_videos, 
               list_empty_matched, count_multiple_nme_videos, count_no_video, and list_no_video.
    """
    output = []
    count_glos = 0  # Counter for entries with non-empty 'Video'
    nmm = 0         # Counter for entries with at least one 'matched_transcriptions'
    count_empty_matched_and_nme_videos = 0  # Counter for entries with empty 'matched_transcriptions' and 'NME_Videos'
    list_empty_matched_and_nme_videos = []   # List of glosses with empty 'matched_transcriptions' and 'NME_Videos'
    count_multiple_nme_videos = 0            # Counter for glosses with more than one 'NME_Videos'
    count_no_video = 0        # Counter for entries without 'Video'
    list_no_video = []        # List of glosses without 'Video'
    multiple_nme_videos = []  # Dictionary containing glosses with multiple 'NME_Videos'

    for item in input_data:
        if not isinstance(item, dict):
            continue
        if len(item) != 1:
            continue

        # Extract the ID and the corresponding content
        id_key, content = next(iter(item.items()))

        # Check if 'Affiliation' exists and contains exactly ["UvA"]
        affiliation = content.get("Affiliation", [])
        if affiliation != ["UvA"]:
            continue

        # Extract required fields with default empty strings if not present
        lemma_id_gloss = content.get("Lemma ID Gloss: Dutch", "").strip()
        link = content.get("Link", "").strip()
        video = content.get("Video", "").strip()

        # Increment count_glos if 'Video' is non-empty
        if video:
            count_glos += 1
        else:
            count_no_video += 1
            list_no_video.append(lemma_id_gloss)

        # Fetch matched_transcriptions for all gloss IDs associated with the current gloss
        gloss_ids = gloss_to_id.get(lemma_id_gloss, [])
        # print(lemma_id_gloss)
        # if lemma_id_gloss == "PVDD":
        #     print("PVDD found")
        #     print(gloss_ids)
        if not gloss_ids:
            continue

        matched_transcriptions = []

        for gloss_id in gloss_ids:
            transcriptions = id_to_m_files.get(str(gloss_id), [])
            matched_transcriptions.extend(transcriptions)

        # Remove duplicates if any
        matched_transcriptions = list(set(matched_transcriptions))

        # Increment nmm if at least one transcription exists
        if matched_transcriptions:
            nmm += 1
        else:
            # Check if NME_Videos exist
            nme_videos = content.get("NME Videos", [])
            if not nme_videos:
                # Both matched_transcriptions and NME_Videos are empty
                count_empty_matched_and_nme_videos += 1
                list_empty_matched_and_nme_videos.append(lemma_id_gloss)
            # Note: We'll handle NME_Videos below

        # Construct the extracted item
        extracted_item = {
            "ID": id_key,
            "Lemma ID Gloss": lemma_id_gloss,
            "Link": link,
            "Video": video,
            "matched_transcriptions": matched_transcriptions
        }

        # **BEGIN MODIFICATION**
        # Add NME_Videos from input_data if matched_transcriptions is empty
        if not matched_transcriptions:
            nme_videos = content.get("NME Videos", [])
            if nme_videos:
                extracted_item["NME_Videos"] = nme_videos
                if len(nme_videos) > 2:
                    count_multiple_nme_videos += 1
                    multiple_nme_videos.append(lemma_id_gloss)
            else:
                # If "NME Videos" is not present or empty, assign an empty list
                extracted_item["NME_Videos"] = []
        # **END MODIFICATION**

        output.append(extracted_item)

    return (
        output, 
        count_glos, 
        nmm, 
        count_empty_matched_and_nme_videos,  # Updated Counter
        list_empty_matched_and_nme_videos,   # Updated List
        count_multiple_nme_videos,            # New Counter
        count_no_video, 
        list_no_video,
        multiple_nme_videos
    )

def main():
    # Define hardcoded file paths
    input_file = "/web/glosses_transformed.json"
    output_file = "/web/nmm/liteGlos.json"

    # MySQL configuration
    db_config = {
        'host': 'signlab-db',
        'user': 'user',
        'password': 'CHeZeGa85W',
        'database': 'admin_gebarenoverleg'
    }

    # Check if input file exists
    if not os.path.isfile(input_file):
        print(f"Error: The file '{input_file}' does not exist.", file=sys.stderr)
        sys.exit(1)

    # Read the input JSON file
    try:
        with open(input_file, "r", encoding="utf-8") as f:
            input_data = json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error: Failed to parse JSON file. {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: An unexpected error occurred while reading '{input_file}'. {e}", file=sys.stderr)
        sys.exit(1)

    # Establish database connection
    connection = get_db_connection(db_config)
    if not connection:
        sys.exit(1)  # Exit if DB connection failed

    # Fetch data from the database
    gloss_to_id = fetch_gloss_to_id(connection)
    id_to_m_files = fetch_id_to_m_files(connection)
    
    # Output gloss_to_id to json
    try:
        with open("/web/nmm/gloss_to_id.json", "w", encoding="utf-8") as f:
            json.dump(gloss_to_id, f, ensure_ascii=False, indent=4)
        print(f"Successfully wrote gloss_to_id to '/web/nmm/gloss_to_id.json'.")
    except IOError as e:
        print(f"Error: Failed to write to '/web/nmm/gloss_to_id.json'. {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: An unexpected error occurred while writing to '/web/nmm/gloss_to_id.json'. {e}", file=sys.stderr)
        sys.exit(1)
    
    # Output id_to_m_files to json
    try:
        with open("/web/nmm/id_to_m_files.json", "w", encoding="utf-8") as f:
            json.dump(id_to_m_files, f, ensure_ascii=False, indent=4)
        print(f"Successfully wrote id_to_m_files to '/web/nmm/id_to_m_files.json'.")
    except IOError as e:
        print(f"Error: Failed to write to '/web/nmm/id_to_m_files.json'. {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: An unexpected error occurred while writing to '/web/nmm/id_to_m_files.json'. {e}", file=sys.stderr)
        sys.exit(1)
    
    # Close the database connection
    try:
        if connection.is_connected():
            connection.close()
            print("Database connection closed.")
    except Error as e:
        print(f"Error closing the database connection: {e}", file=sys.stderr)

    # Process the input data with filtering and enrichment
    (
        extracted_data, 
        count_glos, 
        nmm, 
        count_empty_matched_and_nme_videos,  # Updated Counter
        list_empty_matched_and_nme_videos,   # Updated List
        count_multiple_nme_videos,            # New Counter
        count_no_video, 
        list_no_video,
        multiple_nme_videos
    ) = extract_fields(input_data, gloss_to_id, id_to_m_files)

    # Ensure the output directory exists
    output_dir = os.path.dirname(output_file)
    if not os.path.exists(output_dir):
        try:
            os.makedirs(output_dir)
            print(f"Created directory '{output_dir}'.")
        except Exception as e:
            print(f"Error: Failed to create directory '{output_dir}'. {e}", file=sys.stderr)
            sys.exit(1)

    # Prepare the final output structure
    final_output = {
        "data": extracted_data,
        "summary": {
            "count_all": len(extracted_data),
            "count_glos": count_glos,
            "nmm": nmm,
            "count_empty_matched_transcriptions_and_nme_videos": count_empty_matched_and_nme_videos,  # Updated Key
            "glosses_with_empty_matched_transcriptions_and_nme_videos": list_empty_matched_and_nme_videos,  # Updated List
            "count_multiple_nme_videos": count_multiple_nme_videos,  # New Summary Field
            "count_no_video": count_no_video,
            "glosses_without_video": list_no_video,
            "multiple_nme_videos:": multiple_nme_videos  # New Summary Field
        }
    }

    # Write the extracted data and counts to the output JSON file
    try:
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(final_output, f, ensure_ascii=False, indent=4)
        print(f"Successfully wrote extracted data and counts to '{output_file}'.")
        print(f"Summary:\n  count_glos: {count_glos}\n  nmm: {nmm}\n  count_empty_matched_transcriptions_and_nme_videos: {count_empty_matched_and_nme_videos}\n  count_multiple_nme_videos: {count_multiple_nme_videos}\n  count_no_video: {count_no_video}")
    except IOError as e:
        print(f"Error: Failed to write to '{output_file}'. {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: An unexpected error occurred while writing to '{output_file}'. {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
