FROM ubuntu:22.04

# Environment variables
ENV NODE_ENV=development
ENV CODE_SERVER_PORT=8443
ENV NODE_VERSION=18.20.5
ENV NVM_DIR=/home/codeuser/.nvm
ENV PATH="/home/codeuser/.nvm/versions/node/v${NODE_VERSION}/bin:${PATH}"

RUN apt update && apt install -y curl git sudo acl

# Create groups 
RUN groupadd -r testgroup && \
    groupadd -r codegroup

# Create users
RUN useradd -m -s /bin/bash -G codegroup codeuser && \
    useradd -r -s /bin/false -G testgroup testuser

# Setup sudo permissions
RUN echo "root ALL=(ALL) ALL" >> /etc/sudoers && \
    echo "codeuser ALL=(root) NOPASSWD: /usr/bin/npm install" >> /etc/sudoers

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install VSCode extensions
RUN code-server --install-extension dbaeumer.vscode-eslint \
    --install-extension esbenp.prettier-vscode \
    --install-extension ms-vscode.vscode-typescript-next \
    --install-extension dsznajder.es7-react-js-snippets \
    --install-extension christian-kohler.path-intellisense \
    --install-extension christian-kohler.npm-intellisense


 
RUN mkdir -p /home/codeuser/.local/share/code-server/User && \
    echo '{"security.workspace.trust.startupPrompt": "never", "security.workspace.trust.enabled": false}' > /home/codeuser/.local/share/code-server/User/settings.json




# Install NVM and Node.js
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install ${NODE_VERSION} && \
    nvm use ${NODE_VERSION} && \
    nvm alias default ${NODE_VERSION}

# Explicitly add Node.js bin to PATH
RUN ln -s "$NVM_DIR/versions/node/v${NODE_VERSION}/bin/node" /usr/local/bin/node && \
    ln -s "$NVM_DIR/versions/node/v${NODE_VERSION}/bin/npm" /usr/local/bin/npm

# Set working directory and copy project files
WORKDIR /config/workspace

# Copy project files
COPY . .
USER root
RUN chown -R root:root /config/workspace/.vscode /config/workspace/tests && \
    chmod -R 700 /config/workspace/.vscode /config/workspace/tests && \
    setfacl -R -m u:root:rwx /config/workspace/.vscode /config/workspace/tests && \
    setfacl -R -m u:codeuser:r-x /config/workspace/.vscode /config/workspace/tests && \
    chown -R codeuser:codegroup /config/workspace && \
    chmod -R 755 /config/workspace
RUN chown -R root:root /config/workspace/tests
RUN chown -R root:root /config/workspace/.vscode
USER codeuser

# Install project dependencies
RUN /bin/bash -c 'source "$NVM_DIR/nvm.sh" && npm install --legacy-peer-deps'
EXPOSE 8443
# Health check, this one is required because we check if the server is up and running in our coding challenge
HEALTHCHECK --interval=2s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8443 || exit 1
CMD ["code-server", "/config/workspace", "--bind-addr", "0.0.0.0:8443", "--auth", "none"]
