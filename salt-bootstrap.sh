#!/bin/bash -e
# vim: set ts=4 sw=4 sts=4 et :

MIN_SALT_VERSION=2014.7.0
BUILD_DEPS="vim git ca-certificates lsb-release rsync python-dulwich python-pip python-gnupg"

SRC_PATH="$(readlink -m $0)"
SRC_DIR="${SRC_PATH%/*}"

source "${SRC_DIR}/.salt-functions.sh"
source "${SRC_DIR}/.salt-purge"
source "${SRC_DIR}/.salt-activate"
source "${SRC_DIR}/.salt-bind"

# Auto authorize installed salt-minion if AUTHORIZE = "1"
AUTHORIZE=1

# If COPY_REPO="1" then this whole repo will be copied to /srv/salt so the
# included state files can be updated via git
COPY_REPO=1

# If a file named '.debug' exists in the same directory as 'salt-bootstrap.sh'
# then salt directories will be deleted before installation and development
# env will be set up
if [ -f "${SRC_DIR}/.debug" ]; then
    echo "DEBUG MODE IS ENABLED!"
    DEBUG=1
fi

# Dummy Placeholder patches
patchDependsPre() { true; }
patchDependsPost() { true; }
patchClonePre() { true; }
patchClonePost() { true; }
patchBootstrapPre() { true; }
patchBootstrapPost() { true; }
patchInstallPre() { true; }
patchInstallPost() { true; }

# Check for patches
if [ -f "${SRC_DIR}/.patch-${ID}-${VERSION_ID}" ]; then
    source "${SRC_DIR}/.patch-${ID}-${VERSION_ID}"
fi

# -----------------------------------------------------------------------------
# Simulate clean installation (purge all salt related files)
# -----------------------------------------------------------------------------
if [ "$DEBUG" == "1" ] || [ -f "${SRC_DIR}/.purge" ]; then
    saltPurge
fi

# -----------------------------------------------------------------------------
# Install build depends, including salt if recent enough version in repo
# -----------------------------------------------------------------------------
installDepends() {
    if ! [ -f /tmp/.salt.build_deps ]; then
        patchDependsPre

        RETVAL=0
        if [ "$ID" == "debian" -o "$ID" == "ubuntu" ]; then
            # NOTE: currently repo_salt_version is set in .patch-debian-7/8 which will
            #       set variable if there is a suitable salt candidate to install
            # TODO: Add code for ubuntu

            # No need to bootstrap salt if version in repo recent enough
            if gte ${repo_salt_version} ${MIN_SALT_VERION}; then
                installed=$(apt-cache policy salt-master | grep Installed)
                if [ ${installed##* } == "(none)" ]; then
                    installed=''
                fi

                if [ "X${installed}" != "X" ]; then
                    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
                        apt-get -y --force-yes install --reinstall salt-minion salt-master ${BUILD_DEPS}
                else
                    DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
                        apt-get -y --force-yes install salt-minion salt-master ${BUILD_DEPS}
                fi
                retval $?

                if [ "$RETVAL" == "0" ]; then
                    touch /tmp/.salt.installed_by_repo
                fi
            else
                DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
                apt-get --purge -y --force-yes remove salt-minion salt-master salt-syndic

                DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
                    apt-get update
                retval $?

                DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
                    apt-get -y --force-yes install ${BUILD_DEPS}
                retval $?
            fi
        elif [ "$ID" == "fedora" ]; then
            # No need to bootstrap salt if version in repo recent enough
            repo_salt_version="$(repoquery salt --qf "%{version}")"

            if gte ${repo_salt_version} ${MIN_SALT_VERION}; then
                if rpm -q salt; then
                    yum reinstall -y salt salt-master salt-minion ${BUILD_DEPS}
                else
                    yum install -y salt salt-master salt-minion ${BUILD_DEPS}
                fi
                retval $?
                if [ "$RETVAL" == "0" ]; then
                    touch /tmp/.salt.installed_by_repo
                fi
            else
                yum erase -y salt
                yum install -y ${BUILD_DEPS}
                retval $?
            fi
        else
            echo "Exiting Build and Installation of salt"
            echo "The operating system id is listed as: $id"
            echo "And this script has only been tested to work on fedora, debian or ubuntu"
            exit 1
        fi

        if [ "$RETVAL" == "0" ]; then
            touch /tmp/.salt.build_deps
        fi

        patchDependsPost
    fi
}

# -----------------------------------------------------------------------------
# Clone salt bootstrap
# -----------------------------------------------------------------------------
cloneSaltBootstrap() {
    if [ /tmp/.salt.build_deps -a ! -f /tmp/.salt.cloned ]; then
        patchClonePre

        RETVAL=0

        # XXX: Specify a specific tag so we don't run into regrerssion errors
        # XXX: Need to verify git signatures
        if [ ! -d /tmp/salt-bootstrap ]; then
            git clone https://github.com/saltstack/salt-bootstrap.git /tmp/salt-bootstrap
        fi

        retval $?
        if [ "$RETVAL" == "0" ]; then
            touch /tmp/.salt.cloned
        fi

        patchClonePost
    fi
}

# -----------------------------------------------------------------------------
# Install salt via bootstrap
#
#  install.sh options:
#  -D  Show debug output.
#  -X  Do not start daemons after installation
#  -U  If set, fully upgrade the system prior to bootstrapping salt
#  -M  Also install salt-master
#  -S  Also install salt-syndic
#  -N  Do not install salt-minion
#  -p  Extra-package to install while installing salt dependencies. One package
#      per -p flag. You're responsible for providing the proper package name.
#
#======================================================================================================================
#  Environment variables taken into account.
#----------------------------------------------------------------------------------------------------------------------
#   * BS_COLORS:                If 0 disables colour support
#   * BS_PIP_ALLOWED:           If 1 enable pip based installations(if needed)
#   * BS_ECHO_DEBUG:            If 1 enable debug echo which can also be set by -D
#   * BS_SALT_ETC_DIR:          Defaults to /etc/salt (Only tweak'able on git based installations)
#   * BS_KEEP_TEMP_FILES:       If 1, don't move temporary files, instead copy them
#   * BS_FORCE_OVERWRITE:       Force overriding copied files(config, init.d, etc)
#   * BS_UPGRADE_SYS:           If 1 and an option, upgrade system. Default 0.
#   * BS_GENTOO_USE_BINHOST:    If 1 add `--getbinpkg` to gentoo's emerge
#   * BS_SALT_MASTER_ADDRESS:   The IP or DNS name of the salt-master the minion should connect to
#   * BS_SALT_GIT_CHECKOUT_DIR: The directory where to clone Salt on git installations
#======================================================================================================================
installSalt() {
    if [ /tmp/.salt.cloned -a ! -f /tmp/.salt.bootstrap ]; then
        patchBootstrapPre

        RETVAL=0

        pushd /tmp/salt-bootstrap
            ./bootstrap-salt.sh -D -U -X -M git v2014.7.0
            retval $?
        popd

        if [ "$RETVAL" == "0" ]; then
            touch /tmp/.salt.bootstrap
        fi

        patchBootstrapPost
    fi

    patchInstallPre
}

# -----------------------------------------------------------------------------
# Install modified salt-* unit files
# -----------------------------------------------------------------------------
installUnitFiles() {
    systemctl stop salt-api salt-minion salt-syndic salt-master || true
    systemctl disable salt-api salt-minion salt-syndic salt-master || true

    install --owner=root --group=root --mode=0644 "${SRC_DIR}/salt/files/salt-master.service" /etc/systemd/system
    install --owner=root --group=root --mode=0644 "${SRC_DIR}/salt/files/salt-minion.service" /etc/systemd/system
    install --owner=root --group=root --mode=0644 "${SRC_DIR}/salt/files/salt-syndic.service" /etc/systemd/system
    install --owner=root --group=root --mode=0644 "${SRC_DIR}/salt/files/salt-api.service" /etc/systemd/system
    mkdir -p /usr/lib/salt
    install --owner=root --group=root --mode=0755 "${SRC_DIR}/salt/files/bind-directories" /usr/lib/salt/bind-directories
}

# -----------------------------------------------------------------------------
# Install salt configuration and state files, etc
# -----------------------------------------------------------------------------
configureSalt() {
    install -d --owner=root --group=root --mode=0750 /etc/salt
    install --owner=root --group=root --mode=0640 "${SRC_DIR}/salt/files/master" /etc/salt
    install --owner=root --group=root --mode=0640 "${SRC_DIR}/salt/files/minion" /etc/salt
    install -d --owner=root --group=root --mode=0750 /etc/salt/master.d
    install -d --owner=root --group=root --mode=0750 /etc/salt/minion.d
    install --owner=root --group=root --mode=0640 "${SRC_DIR}/salt/files/master.d/"* /etc/salt/master.d || true
    install --owner=root --group=root --mode=0640 "${SRC_DIR}/salt/files/minion.d/"* /etc/salt/minion.d || true

    install -d --owner=root --group=root --mode=0750 /srv/salt
    install -d --owner=root --group=root --mode=0750 /srv/pillar
    install -d --owner=root --group=root --mode=0750 /srv/salt-formulas

    if [ "$COPY_REPO" == "1" ]; then
        cp -r "${SRC_DIR}/". /srv/salt

        # Don't allow .debug or .purge files to copy over
        rm -f /srv/salt/.debug
        rm -f /srv/salt/.purge
    else
        install --owner=root --group=root --mode=0640 "${SRC_DIR}/top.sls" /srv/salt/top.sls
        cp -r "${SRC_DIR}/salt" /srv/salt/salt || true
        cp -r "${SRC_DIR}/python_pip" /srv/salt/python_pip || true
        cp -r "${SRC_DIR}/vim" /srv/salt/vim || true
        cp -r "${SRC_DIR}/theme" /srv/salt/theme || true
    fi
    cp -r "${SRC_DIR}/pillar/"* /srv/pillar || true
    cp -r "${SRC_DIR}/salt-formulas/"* /srv/salt-formulas

    # Replace master config files with development files
    if [ "$DEBUG" == "1" ] && [ -d "${SRC_DIR}/dev" ]; then
        pushd "${SRC_DIR}/dev"
            ./dev-mode.sh
        popd
    fi

    chmod -R u=rwX,g=rX,o-wrxX /srv/salt
    chmod -R u=rwX,g=rX,o-wrxX /srv/salt-formulas
    chmod -R u=rwX,g=rX,o-wrxX /srv/pillar
    sync
}

# -----------------------------------------------------------------------------
# Run highstate for the first time.  If salt was installed via bootstrap,
# its will be replaced with git version
# -----------------------------------------------------------------------------
initialHighstate() {
    systemctl enable salt-master salt-minion salt-api
    systemctl start salt-master salt-minion salt-api

    salt-call --local saltutil.sync_all
    salt-call --local state.highstate || true
    timer 5
    sync

    # Salt initially configured; restart and run a highstate again
    echo
    echo "salt-master and salt-minion will be stopped, disabled, re-enabled and then restarted."
    echo
    echo "NOTE: It can take salt-master a long time to stop (1 to 2 minutes)"
    echo "without any indication of its progress.  Be patient :)"
    echo
    systemctl stop salt-minion salt-api salt-master || true
    systemctl disable salt-master salt-minion salt-api || true
    systemctl enable salt-master salt-minion salt-api || true
    systemctl start salt-master salt-minion salt-api || true
    salt-call --local state.highstate || true
}

# -----------------------------------------------------------------------------
# Authorize Salt Minion
# -----------------------------------------------------------------------------
authorizeSalt() {
    # Just incase we have not yet authorized...
    if [ "$AUTHORIZE" == "1" ]; then
        echo "Trying to authorize minion..."
        timer 30
        saltActivate
    fi
}


# Main
# ----

# Make sure there are no existing salt services currently running
systemctl stop salt-api salt-minion salt-syndic salt-master || true

# Install build depends, including salt if recent enough version in repo
installDepends

if [ ! -e "/tmp/.salt.installed_by_repo" ]; then
    # Clone salt bootstrap
    cloneSaltBootstrap

    # Install salt via bootstrap (will return if installed by repo)
    installSalt
fi

# Bind /rw dirs to salt dirs
bindDirectories

# Install modified salt-* unit files
installUnitFiles

# Install salt configuration and state files, etc
configureSalt

# Run highstate for the first time.  If salt was installed via bootstrap,
# its will be replaced with git version
initialHighstate

# Authorize Salt Minion
authorizeSalt

# Run any additional post installation patches
patchInstallPost

