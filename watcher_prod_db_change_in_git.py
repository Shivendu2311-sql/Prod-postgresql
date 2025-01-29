import time
import base64
import requests
from dotenv import load_dotenv
import os
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler  # Importing FileSystemEventHandler

# Load environment variables from the .env file
load_dotenv()

# Set your GitHub credentials and repository details
repo_owner = 'Shivendu2311-sql'  # Your GitHub username
repo_name = 'Prod-postgresql'  # The repository where you want to upload the file
commit_message = 'Automated file upload'  # The commit message for the upload

# Path to the local SQL file you want to upload
local_file_path = r'C:\Users\Workstation-04\AppData\Roaming\DBeaverData\workspace6\General\Scripts'

# Read and encode file content
def read_and_encode_file(file_path):
    with open(file_path, 'rb') as file:
        file_content = file.read()
    base64_content = base64.b64encode(file_content).decode('utf-8')
    return base64_content

# Fetch file details from GitHub (to get the SHA)
def get_file_sha(file_path):
    url = f'https://api.github.com/repos/{repo_owner}/{repo_name}/contents/{file_path}'
    headers = {
        'Authorization': f'token {os.getenv("GITHUB_TOKEN")}',
    }

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json()['sha']  # Get the SHA of the file
    else:
        print(f"Error fetching file details: {response.status_code} - {response.json()}")
        return None

# Upload file to GitHub
def upload_to_github(file_path, base64_content, sha=None):
    url = f'https://api.github.com/repos/{repo_owner}/{repo_name}/contents/{file_path}'
    token = os.getenv('GITHUB_TOKEN')  # Fetch the token from the environment variable

    if token is None:
        print("Error: GitHub token not found. Make sure it is set in the .env file.")
        return

    headers = {
        'Authorization': f'token {token}',  # Add token in the Authorization header
    }

    # If SHA is not provided, we are creating a new file
    data = {
        'message': commit_message,  # Commit message
        'content': base64_content,  # The file content in base64 format
    }

    # Add the SHA for file updates
    if sha:
        data['sha'] = sha

    # Make the API request to upload the file
    response = requests.put(url, json=data, headers=headers)

    # Check the response from GitHub API
    if response.status_code == 201:
        print(f"File uploaded successfully: {response.json()}")
    else:
        print(f"Error: {response.status_code} - {response.json()}")

# Watchdog event handler for file change
class FileChangeHandler(FileSystemEventHandler):  
    def on_modified(self, event):
        # Ensure the event is for a file, not a directory
        if not event.is_directory:  
            print(f"File modified: {event.src_path}")
            file_content = read_and_encode_file(event.src_path)  # Use event.src_path for the modified file

            # Get the file path in the repo (under 'prod')
            file_path_in_repo = f'prod/{os.path.basename(event.src_path)}'  # Use the file's name and put it in 'prod'

            # Fetch the SHA of the existing file (if it exists)
            sha = get_file_sha(file_path_in_repo)

            if sha:
                # File exists, update it
                upload_to_github(file_path_in_repo, file_content, sha)
            else:
                # File does not exist, create a new one
                upload_to_github(file_path_in_repo, file_content)

    def on_created(self, event):
        # This will be triggered when a new file is created
        if not event.is_directory:
            print(f"New file added: {event.src_path}")
            file_content = read_and_encode_file(event.src_path)  # Read the new file

            # Get the file path in the repo (under 'prod')
            file_path_in_repo = f'prod/{os.path.basename(event.src_path)}'  # Use the file's name and put it in 'prod'

            # Fetch the SHA of the existing file (if it exists)
            sha = get_file_sha(file_path_in_repo)

            if sha:
                # File exists, update it
                upload_to_github(file_path_in_repo, file_content, sha)
            else:
                # File does not exist, create a new one
                upload_to_github(file_path_in_repo, file_content)


# Start watching the directory for file changes
def start_watching():
    event_handler = FileChangeHandler()
    observer = Observer()
    observer.schedule(event_handler, path=local_file_path, recursive=True)
    observer.start()

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

if __name__ == "__main__":
    start_watching()
