FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Optional arg to install custom devbox version
ARG DEVBOX_USE_VERSION

# Step 1: Installing dependencies
RUN apt-get update
RUN apt-get -y install bash binutils git xz-utils wget sudo

# Step 1.5: Setting up devbox user
ENV DEVBOX_USER=devbox
RUN adduser $DEVBOX_USER
RUN usermod -aG sudo $DEVBOX_USER
RUN echo "${DEVBOX_USER} ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/$DEVBOX_USER
USER $DEVBOX_USER

# Step 2: Installing Nix
RUN wget --output-document=/dev/stdout https://nixos.org/nix/install | sh -s -- --no-daemon
RUN . ~/.nix-profile/etc/profile.d/nix.sh

ENV PATH="/home/${DEVBOX_USER}/.nix-profile/bin:$PATH"

# Step 3: Installing devbox
ENV DEVBOX_USE_VERSION=$DEVBOX_USE_VERSION
RUN wget --quiet --output-document=/dev/stdout https://get.jetify.com/devbox   | bash -s -- -f
RUN chown -R "${DEVBOX_USER}:${DEVBOX_USER}" /usr/local/bin/devbox

# run a devbox command to make launcher download devbox binary
RUN devbox version

# Installing your devbox project
WORKDIR /code
USER root:root

RUN mkdir -p /code && chown ${DEVBOX_USER}:${DEVBOX_USER} /code

USER ${DEVBOX_USER}:${DEVBOX_USER}

RUN git config --global --add safe.directory /workspaces/platform-engineering

COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.json devbox.json
COPY --chown=${DEVBOX_USER}:${DEVBOX_USER} devbox.lock devbox.lock

RUN devbox run -- echo "Installed Packages." && nix-store --gc && nix-store --optimise

RUN devbox shellenv --init-hook >> ~/.profile


