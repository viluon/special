FROM rust:1.55-buster

ARG GHC_VERSION=8.8.4
ARG STACK_RESOLVER=lts-16.12

ENV USERNAME=haskeller \
    USER_UID=2001 \
    USER_GID=2001 \
    DEBIAN_FRONTEND=noninteractive \
    GHC_VERSION=${GHC_VERSION} \
    STACK_RESOLVER=${STACK_RESOLVER}

RUN apt-get update
RUN (apt-get install -y --no-install-recommends \
                     build-essential \
                     curl \
                     curl \
                     libncurses5 \
                     libtinfo5 \
                     libtinfo5 \
                     lsb-release \
                     pandoc \
                     pipx \
                     python3-pip \
                     python3-setuptools \
                     sudo \
                     texlive-latex-extra \
                     zsh \
     ; apt-get autoremove -y \
     ; apt-get clean -y \
     ; rm -rf /tmp/* /var/tmp/*)

RUN groupadd --gid $USER_GID $USERNAME && \
    useradd -ms /bin/bash -K MAIL_DIR=/dev/null --uid $USER_UID --gid $USER_GID -m $USERNAME && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

USER ${USER_UID}:${USER_GID}
WORKDIR /home/${USERNAME}
ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.cabal/bin:/home/${USERNAME}/.ghcup/bin:$PATH"

ENV BOOTSTRAP_HASKELL_NONINTERACTIVE=yes \
    BOOTSTRAP_HASKELL_NO_UPGRADE=yes

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh
# Get poetry while we're at it
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | python3 -

# Set the GHC version
RUN ghcup install ghc ${GHC_VERSION} && ghcup set ghc ${GHC_VERSION}; \
    # Install cabal-install \
    ghcup install cabal && cabal update && cabal new-install -j cabal-install

# Get Stack, init global project and set defaults
RUN curl -sSL https://get.haskellstack.org/ | sh; \
    (stack ghc -- --version 2>/dev/null); \
    stack config --system-ghc set system-ghc --global true && \
    stack config --system-ghc set install-ghc --global false && \
    stack config --system-ghc set resolver $STACK_RESOLVER

# Install global packages
RUN cabal install -j \
                     alex \
                     dhall-json \
                     doctest \
                     happy \
                     pandoc-csv2table \
                     pandoc-plot \
                     pandoc-sidenote \
                     QuickCheck

# Install Entangled
RUN git clone --branch v1.2.4 https://github.com/entangled/entangled.git
WORKDIR /home/${USERNAME}/entangled
RUN cabal install -j

RUN sudo pip3 install --upgrade entangled-filters jupyter zsh_jupyter_kernel && \
    sudo python3 -m zsh_jupyter_kernel.install --sys-prefix \
    ; pipx install git+https://github.com/alexpdp7/pandocsql.git
RUN cargo install hyperfine

USER 0:0
WORKDIR /home/${USERNAME}

ENV DEBIAN_FRONTEND=dialog
ENTRYPOINT ["/bin/bash"]
