# Dockerfile for noteworthy MCP Server
FROM python:3.13-slim
# 3.14 breaks brotli

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    neovim \
    libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# We don't need CUDA for this build.
# If you really want CUDA, comment out these lines.
RUN pip3 install torch --index-url https://download.pytorch.org/whl/cpu
RUN pip install sentence-transformers --no-deps

# Copy the application code
COPY noteworthy noteworthy/

# Copy requirements and README (needed for package metadata)
COPY pyproject.toml README.md COPYING ./
RUN pip install -e .

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
# these directories may be mounted for persistence
ENV XDG_CONFIG_HOME=/app/config
ENV XDG_STATE_HOME=/app/state

# Create non-root user
RUN useradd --create-home --shell /bin/bash mcp_user && \
    chown -R mcp_user:mcp_user /app
USER mcp_user

# Copy the config dirs
COPY config config/

# Default command to run the noteworthy MCP server
CMD ["hy", "-m", "noteworthy.mcp_server"]
