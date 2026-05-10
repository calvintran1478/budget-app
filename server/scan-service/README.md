# Getting Started

## Building Dependencies

Create a python virtual environment in the scan-service directory.
```bash
python -m venv falcon-env
```
Now activate your environment with the following command.
```bash
source falcon-env/bin/activate
```
Install the package requirements using pip
```bash
pip install -r requirements.txt
```

## Starting the Server

Ensure your virtual environment is active. To start the server navigate to the src directory and run
```bash
uvicorn server:app
```
To exit the virtual environment simply run
```bash
deactivate
```
