FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    bash \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install noirup and nargo
SHELL ["/bin/bash", "-c"]
RUN curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
ENV PATH="/root/.nargo/bin:$PATH"
RUN noirup

# Install bats
RUN git clone https://github.com/bats-core/bats-core.git /tmp/bats && \
    /tmp/bats/install.sh /usr/local && \
    rm -rf /tmp/bats

# Install bb (Barretenberg)
RUN curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/refs/heads/next/barretenberg/bbup/install | bash
ENV PATH="/root/.bb:$PATH"
RUN bbup

# Install Foundry (forge, cast)
RUN curl -L https://foundry.paradigm.xyz | bash
ENV PATH="/root/.foundry/bin:$PATH"
RUN foundryup

# Install noir-build-tools
WORKDIR /opt/noir-build-tools
COPY . .
RUN ./install.sh
ENV PATH="/root/.local/bin:$PATH"
ENV NOIR_BUILD_TOOLS_LIB="/opt/noir-build-tools/lib"

# Set working directory for user code
WORKDIR /app

# Default command
CMD ["nbt", "doctor"]
