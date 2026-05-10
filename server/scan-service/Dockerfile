# Set the base image using Python 3.14
FROM python:3.14

# Set the working directory to /app
WORKDIR /app

# Copy requirements to working directory
COPY ./requirements.txt /app

# Copy source files to working directory
COPY ./src /app

# Install requirements
RUN pip install --upgrade -r /app/requirements.txt

# Expose port the app runs on
EXPOSE 8000

# Run the app with uvicorn
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8000"]
