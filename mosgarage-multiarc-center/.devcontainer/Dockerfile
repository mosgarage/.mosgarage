FROM ubuntu:20.10 

ARG USERNAME=dcuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME

# Update packages list & install missing packages
RUN apt-get update \
    && export DEBIAN_FRONTEND=noninteractive \
    # install missing packages
    && mkdir -p /usr/share/man/man1 \
    && apt-get install -y sudo git curl make procps lsb-release vim jq python3-pip unzip gnupg software-properties-common wget jq dos2unix 
    
# Finish setting up $USERNAME (sudo, no password etc ...)
RUN echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME  

# Install missing packages out of apt-get
COPY tools-install.sh /home/$USERNAME/
RUN chmod +x ./home/$USERNAME/tools-install.sh
RUN dos2unix ./home/$USERNAME/tools-install.sh && ./home/$USERNAME/tools-install.sh

# Python things: update pip, install az-cli
RUN python3 -m pip install pip --upgrade

# Install required librairies
COPY ./requirements.txt /home/$USERNAME/
RUN pip install -r /home/$USERNAME/requirements.txt

# install .Net 6.0 SDK
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
RUN dpkg -i packages-microsoft-prod.deb
RUN apt-get update \
    && apt-get install -y apt-transport-https \
    && apt-get install -y dotnet-sdk-6.0

# update path 
ENV PATH="$HOME/.local/bin:$PATH"

# Install Docker CLI
RUN apt-get update \
    && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    dnsutils
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN  apt-get update \
      && apt-get install -y docker-ce-cli

# Install Docker-compose
RUN curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
RUN chmod +x /usr/local/bin/docker-compose

# now everything from here uses the normal user
USER $USERNAME

# configure az cli to automatically install extension
RUN az config set extension.use_dynamic_install=yes_without_prompt

# back to default shell
SHELL ["/bin/sh", "-c"]

CMD [ "sleep", "infinity" ]