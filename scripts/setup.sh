#!/bin/bash --init-file
clear

. /etc/os-release

DEPS_DEB=(python3-virtualenv sshpass)           # Dependencies
ANSIBLE_VERSION="${ANSIBLE_VERSION:-2.9.21}"    # Ansible version to install
ANSIBLE_TOO_NEW="${ANSIBLE_TOO_NEW:-2.10.0}"    # Ansible version too new
CONFIG_DIR="${CONFIG_DIR:-./config}"            # Default configuration directory location
JINJA2_VERSION="${JINJA2_VERSION:-2.11.1}"      # Jinja2 required version
PIP="${PIP:-pip3}"                              # Pip binary to use
PYTHON_BIN="${PYTHON_BIN:-/usr/bin/python3}"    # Python3 path
VENV_DIR="${VENV_DIR:-/opt/olympus/env}"        # Path to python virtual environment to create

export DEBIAN_FRONTEND=noninteractive

as_sudo(){
    cmd="sudo bash -c '$@'"
    eval $cmd
}

as_user(){
    cmd="bash -c '$@'"
    eval $cmd
}

echo "=== Bringing host up-to-date ==="
as_sudo "apt-get -yq --fix-missing update"
as_sudo "apt-get -yq install ${DEPS_DEB[@]}"
as_sudo "apt-get check"
as_sudo "apt-get autoremove"
as_sudo "apt-get clean"
as_sudo "apt-get autoclean"
echo

echo "=== Modifying the MOTD ==="
as_sudo "sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news"
echo

echo "=== Virtualenv setup ==="
if command -v virtualenv &> /dev/null ; then
    sudo mkdir -p "${VENV_DIR}"
    sudo chown -R $(id -u):$(id -g) "${VENV_DIR}"
    deactivate nondestructive &> /dev/null
    virtualenv -q --python="${PYTHON_BIN}" "${VENV_DIR}"
    . "${VENV_DIR}/bin/activate"
    as_user "${PIP} install -q --upgrade pip"

    # Check for any installed ansible pip package
    if pip show ansible 2>&1 >/dev/null; then
        current_version=$(pip show ansible | grep Version | awk '{print $2}')
	echo "Current version of Ansible is ${current_version}"
	if "${PYTHON_BIN}" -c "from distutils.version import LooseVersion; print(LooseVersion('$current_version') >= LooseVersion('$ANSIBLE_TOO_NEW'))" | grep True 2>&1 >/dev/null; then
            echo "Ansible version ${current_version} too new."
	    echo "Please uninstall any ansible, ansible-base, and ansible-core packages and re-run this script"
	    exit 1
	fi
	if "${PYTHON_BIN}" -c "from distutils.version import LooseVersion; print(LooseVersion('$current_version') < LooseVersion('$ANSIBLE_VERSION'))" | grep True 2>&1 >/dev/null; then
	    echo "Ansible will be upgraded from ${current_version} to ${ANSIBLE_VERSION}"
	fi
    fi

    as_user "${PIP} install -q --upgrade \
        ansible==${ANSIBLE_VERSION} \
        Jinja2==${JINJA2_VERSION} \
        netaddr \
        ruamel.yaml \
        PyMySQL \
        selinux"
else
    echo "ERROR: Unable to create Python virtual environment, 'virtualenv' command not found"
    exit 1
fi
echo

# Add Ansible virtual env to PATH when using Bash
if [ -f "${VENV_DIR}/bin/activate" ] ; then
    . "${VENV_DIR}/bin/activate"
    ansible localhost -m lineinfile -a "path=$HOME/.bashrc create=yes mode=0644 backup=yes line='source ${VENV_DIR}/bin/activate'"
fi
echo

if [ -f /var/run/reboot-required ]; then
    echo "=== Reboot required ==="
    as_sudo "reboot"
else
    echo "=== No reboot required ==="
fi