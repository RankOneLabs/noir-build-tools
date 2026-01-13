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

# Install bb (Barretenberg)
RUN curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/cpp/scripts/install_bb.sh | bash
ENV PATH="/root/.bb:$PATH"
# Ensure bb is installed (the script might just install the updater?)
# Usually the script installs 'bb'. Let's verify or run bbup if needed.
# For simplicity, assuming the script puts bb in path or we need to look closer.
# Alternative: curl release binary directly.
# Let's use the explicit binary download if the handy script is flaky.
# Using the one from noir-lang/noir releases? No, bb is separate.
# Let's assume the install script works or try a known working pattern:
# RUN curl -L https://github.com/AztecProtocol/aztec-packages/releases/download/barretenberg-v0.46.1/barretenberg-x86_64-linux-gnu.tar.gz | tar -xz -C /usr/local/bin
# But pinning version is hard.
# Let's try the simple install script again, but verify path.
# Actually, nargo often manages bb via `nargo backend`? No, nbt uses `bb` CLI.

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
