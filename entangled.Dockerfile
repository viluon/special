FROM rust:1.56-bullseye

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
                     jq \
                     libncurses5 \
                     libtinfo5 \
                     libtinfo5 \
                     locales \
                     lsb-release \
                     python3-dev \
                     python3-pip \
                     python3-setuptools \
                     python3-venv \
                     python3-wheel \
                     sudo \
                     texlive-latex-extra \
                     zsh \
     ; apt-get autoremove -y \
     ; apt-get clean -y \
     ; rm -rf /tmp/* /var/tmp/*)

# fix locales
# FIXME: this sets up root's `.bashrc`, but later we switch to the haskeller user
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen \
  ; locale-gen \
  ; echo "export   LC_ALL=en_US.UTF-8" >> ~/.bashrc \
  ; echo "export     LANG=en_US.UTF-8" >> ~/.bashrc \
  ; echo "export LANGUAGE=en_US.UTF-8" >> ~/.bashrc


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

# Install Entangled & global Haskell packages
RUN git clone --branch v1.2.4 https://github.com/entangled/entangled.git
WORKDIR /home/${USERNAME}/entangled
RUN cabal install -j \
                     alex \
                     dhall-json \
                     doctest \
                     happy \
                     pandoc-2.14.0.2 \
                     pandoc-crossref \
                     pandoc-csv2table \
                     pandoc-sidenote
RUN cabal install -j --lib \
                     QuickCheck

RUN sudo pip3 install --upgrade entangled-filters jupyter zsh_jupyter_kernel virtualenv && \
    sudo python3 -m zsh_jupyter_kernel.install --sys-prefix \
    ; pip3 install --user pipx \
    ; python3 -m pipx ensurepath \
    ; pipx --version \
    ; pipx install git+https://github.com/alexpdp7/pandocsql.git
RUN cargo install hyperfine

USER 0:0
WORKDIR /home/${USERNAME}

ENV DEBIAN_FRONTEND=dialog
ENTRYPOINT ["/bin/bash"]
