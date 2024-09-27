FROM fedora:latest

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
  gem install \
    test-unit \
    test-unit-ruby-core

RUN \
  useradd --user-group --create-home user

RUN \
  echo "user ALL=(ALL:ALL) NOPASSWD:ALL" | \
    EDITOR=tee visudo -f /etc/sudoers.d/user

USER user
WORKDIR /home/user
