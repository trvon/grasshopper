FROM ubuntu:22.04

# environment variables
ENV DEBIAN_FRONTEND="noninteractive"
ENV HOME="/root"
ENV XDG_DATA_HOME="/root/.config"
ENV LC_ALL="en_US.UTF-8"
ENV LC_CTYPE="en_US.UTF-8"
ENV TERM="xterm-256color"
ENV SHELL="/bin/bash"
ENV VIRTUAL_ENV="${HOME}""/""${VENV}"

# build variables
ARG BINWALK="https://github.com/devttys0/binwalk.git"
ARG GDB="gdb-13.0.50.20221218"
ARG GDB_EXT=".tar.xz"
ARG HOME="/root"
ARG MSF="https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb"
ARG MSF_PATH="/opt/metasploit-framework/bin"
ARG MSF_SCRIPT="msfinstall"
ARG R2="https://github.com/radareorg/radare2.git"
ARG R2_PATH="/radare/radare2/sys"
ARG PIP_FILE="${HOME}""/requirements.txt"
ARG SECLISTS="https://github.com/danielmiessler/SecLists.git"
ARG VENV="prophesy"
ARG WORDLIST_DIR_MAIN="/data/wordlists"
ARG WORDLIST_DIR_LINK="/usr/share/wordlists"
ARG ROCKYOU_PATH="${WORDLIST_DIR_MAIN}""/Passwords/Leaked-Databases"

WORKDIR "${HOME}""/workbench"

# Update everything
RUN dpkg --add-architecture i386 &&\
    apt -y update  &&\
    apt -y upgrade

# Add configurations
COPY ./configs/* "${HOME}"/
COPY ./configs/.* "${HOME}"/
COPY ./configs/.config "${HOME}"/.config

# Add a bunch of random things we may need
RUN apt -y install\
    bat\
    ca-certificates\
    checksec\
    clang\
    curl\
    file\
    git\
    gnupg\
    hexedit\
    libexpat1-dev\
    libgmp-dev\
    libmpfr-dev\
    locales\
    make\
    netcat\
    net-tools\
    nmap\
    postgresql\
    procps\
    ruby\
    software-properties-common\
    strace\
    subnetcalc\
    trash-cli\
    tmux\
    wget\
    wine\
    xz-utils &&\
    gem install bundler &&\
    mkdir -p ~/.local/share/Trash &&\
    sed -i '/^#.*en_US.UTF-8.*/s/^#//' /etc/locale.gen &&\
    locale-gen en_US.UTF-8 &&\
    dpkg-reconfigure locales

# Add NodeJS
RUN cd /tmp &&\
    curl -sL install-node.vercel.app/lts > ./lts &&\
    chmod +x ./lts &&\
    ./lts --yes &&\
    rm -rf ./lts

# Add text editors and configurations
RUN apt -y install vim neovim &&\
    curl -fLo\
    ~/.config/nvim/autoload/plug.vim --create-dirs\
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim &&\
    nvim +PlugInstall +q +UpdateRemotePlugins +q

# Add everything we will probably need with python
RUN apt -y install\
    python3\
    python3-dev\
    python3-distutils\
    python3-pip\
    python3-venv &&\
    python3 -m venv "${VIRTUAL_ENV}"

# Set this now to avoid issues in the future
ENV PATH="${VIRTUAL_ENV}""/bin:""${PATH}"

COPY ./requirements.txt "${PIP_FILE}"
RUN python3 -m pip install -r "${PIP_FILE}" &&\
    rm -rf "${PIP_FILE}"

# Add GEF to GDB
# Sadly, we have to install GDB ourselves for python support
RUN /bin/bash -c "$(curl -fsSL https://gef.blah.cat/sh)" &&\
    git clone https://github.com/scwuaptx/Pwngdb.git --depth 1 ~/Pwngdb &&\
    cat ~/Pwngdb/.gdbinit >> ~/.gdbinit

RUN cd /tmp &&\
  wget https://sourceware.org/pub/gdb/snapshots/current/${GDB}${GDB_EXT} &&\
  tar xvf "${GDB}""${GDB_EXT}" &&\
  cd "${GDB}" &&\
  ./configure --with-python=/usr/bin/python3 &&\
  make -j `nproc` &&\
  make install &&\
  cd /tmp &&\
  rm -rf /tmp/"${GDB}"*

# Install binwalk
RUN cd /tmp &&\
    git clone "${BINWALK}" --depth 1 &&\
    cd ./binwalk &&\
    ./setup.py install &&\
    rm -rf /tmp/binwalk

# Install wordlists
RUN cd /tmp &&\
    git clone "${SECLISTS}" &&\
    mkdir -p /data/ /usr/share/ &&\
    cp -r /tmp/SecLists "${WORDLIST_DIR_MAIN}" &&\
    ln -sf "${WORDLIST_DIR_MAIN}" "${WORDLIST_DIR_LINK}" &&\
    cd "${ROCKYOU_PATH}" &&\
    tar -xzf rockyou.txt.tar.gz

# Install hashcat
# And hashcat wrapper for ease of use
RUN apt -y install hashcat
# TODO: hashcat wrapper script

# Install metasploit
RUN cd /tmp &&\
    curl "${MSF}" > "${MSF_SCRIPT}" &&\
    chmod +x "${MSF_SCRIPT}" &&\
    ./"${MSF_SCRIPT}" &&\
    rm -rf ./"${MSF_SCRIPT}"

# Install Radare2
# And we have to keep the source dir around, so put it somewhere permanent
RUN mkdir /radare &&\
    cd /radare &&\
    git clone "${R2}" &&\
    cd "${R2_PATH}" &&\
    ./install.sh

# Install qemu user-emulation mode things
RUN apt -y install qemu qemu-user-static

# Cleanup
RUN apt clean &&\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
