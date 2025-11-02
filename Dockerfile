# Dockerfile for noteworthy MCP Server
FROM python:3.14-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and README (needed for package metadata)
COPY pyproject.toml README.md ./
RUN pip install -e .

# Copy the application code
COPY noteworthy/ ./noteworthy/

# Set environment variables
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1
# these directories may be mounted for persistence
ENV XDG_CONFIG_HOME=/app
ENV XDG_STATE_HOME=/app/state

# Create non-root user
RUN useradd --create-home --shell /bin/bash mcp_user && \
    chown -R mcp_user:mcp_user /app
USER mcp_user

# Default command to run the noteworthy MCP server
CMD ["hy", "-m", "noteworthy.mcp_server"]
