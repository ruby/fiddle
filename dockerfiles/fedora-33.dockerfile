FROM fedora:33

RUN \
  dnf install -y \
    gcc \
    gcc-c++ \
    libffi-devel \
    make \
    redhat-rpm-config \
    ruby-devel \
    which && \
  dnf clean all

RUN \
  gem install bundler

RUN \
  useradd --user-group --create-home user

RUN \
  echo "user ALL=(ALL:ALL) NOPASSWD:ALL" | \
    EDITOR=tee visudo -f /etc/sudoers.d/user

USER user
WORKDIR /home/user
