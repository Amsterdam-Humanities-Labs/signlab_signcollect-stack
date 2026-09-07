import requests
import os

def upload_video(php_url, video_path, glos):
    """
    Uploads a video file and a 'glos' parameter to the specified PHP endpoint.

    Args:
        php_url (str): The URL to the PHP upload script.
        video_path (str): The file path to the video you want to upload.
        glos (str): The 'glos' parameter to send with the upload.

    Returns:
        dict: The JSON response from the PHP script.
    """
    if not os.path.isfile(video_path):
        print(f"Error: The file '{video_path}' does not exist.")
        return

    try:
        with open(video_path, 'rb') as video_file:
            files = {'video': (os.path.basename(video_path), video_file, 'video/webm')}
            data = {'glos': glos}

            print(f"Uploading '{video_path}' with glos='{glos}' to '{php_url}'...")

            response = requests.post(php_url, files=files, data=data, verify=False)

            # Check if the request was successful
            if response.status_code == 200:
                try:
                    json_response = response.json()
                    print("Response from server:")
                    print(json_response)
                    return json_response
                except ValueError:
                    print("Error: Response is not valid JSON.")
                    print("Response content:")
                    print(response.text)
            else:
                print(f"Error: Received status code {response.status_code}")
                print("Response content:")
                print(response.text)

    except requests.exceptions.RequestException as e:
        print(f"Request failed: {e}")

if __name__ == "__main__":
    # Configuration
    PHP_UPLOAD_URL = "https://signcollect.nl/nmm/upload_video_nmm.php"  # Replace with your actual PHP script URL
    VIDEO_FILE_PATH = "/web/uploads/35fd887c4966232e50a701fd427d0235a8db7ff7331d24050df3f484b9ba2b1e.webm"                        # Replace with the path to your video file
    GLOS_VALUE = "test"                                   # Replace with your desired 'glos' value

    # Upload the video
    upload_video(PHP_UPLOAD_URL, VIDEO_FILE_PATH, GLOS_VALUE)
