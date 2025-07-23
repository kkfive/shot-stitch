# Video Preview Generator Docker Image
# Lightweight Alpine Linux based image

FROM alpine:latest

# Maintainer information
LABEL maintainer="DreamyTZK"
LABEL version="0.1.0"
LABEL description="Local video preview image generator"

# Install required dependencies
RUN apk add --no-cache \
    ffmpeg \
    imagemagick \
    bc \
    bash \
    coreutils \
    findutils \
    && rm -rf /var/cache/apk/*

# Create working directory
WORKDIR /app

# Copy project files
COPY . /app/

# Set script permissions
RUN chmod +x /app/preview.sh

# Create data mount point
VOLUME ["/data"]

# Set environment variables
ENV PATH="/app:$PATH"

# Set entrypoint
ENTRYPOINT ["./preview.sh"]

# Default command (show help)
CMD ["--help"]
