# LungCXR Flask backend, CPU-only. Built by Railway from server/ (see DEPLOY.md).
FROM python:3.14-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# CPU wheels first: the default PyPI torch bundles CUDA (gigabytes we don't
# use). The pins in requirements.txt are then already satisfied.
COPY requirements.txt .
RUN pip install --index-url https://download.pytorch.org/whl/cpu \
        torch==2.14.1+cpu torchvision==0.29.1+cpu \
 && pip install -r requirements.txt

COPY app ./app
COPY wsgi.py start.sh ./
RUN chmod +x start.sh

# Database, uploaded images and model files live on the Railway volume.
ENV LUNGCXR_DATA_DIR=/data

CMD ["./start.sh"]
