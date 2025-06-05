# use a lightweight python base image
FROM python:3.9-slim

# set working directory inside the container
WORKDIR /app

# copy only needed files
COPY app.py requirements.txt ./

# install python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# expose streamlit's default port
EXPOSE 8501

# run the streamlit app when the container starts
ENTRYPOINT ["streamlit", "run", "app.py", "--server.port", "8501", "--server.address", "0.0.0.0"]
