# 5 Ways to install GIT on CentOS 6/7
# They are tried one after the other
# - binary from IUS Repo (repo.ius.io)
# - binary from packages.endpoint.com repo
# - binary directly from RPM of IUS repo
# - binary from wandisco repo (opensource.wandisco.com)
# - from source (www.kernel.org/pub/software/scm/git)

# Exit on error:
set -e

CENTOS_MAIN_VERSION=$(cat /etc/centos-release | awk '{print $4}' | awk -F '.' '{print $1}')

URL_IUS=https://repo.ius.io/ius-release-el${CENTOS_MAIN_VERSION}.rpm
GIT_PACKAGE_IUS=git-core

URL_PACKAGES=https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
GIT_PACKAGE_PACKAGES=git

URL_IUS_GIT_RPM=https://repo.ius.io/7/x86_64/packages/g/git224-core-2.24.3-1.el7.ius.x86_64.rpm

URL_WANDISCO=http://opensource.wandisco.com/centos/${CENTOS_MAIN_VERSION}/git/x86_64/wandisco-git-release-7-2.noarch.rpm
GIT_PACKAGE_WANDISCO=git

GIT_VERSION_FROM_SOURCE=${GIT_VERSION_FROM_SOURCE:=2.29.1}
BASE_URL_GIT_SOURCE_REPO="https://www.kernel.org/pub/software/scm/git"

define_sudo() {
  unalias sudo 2>/dev/null
  if ! sudo echo nothing 2>/dev/null 1>/dev/null; then 
    sudo() { $@; }; 
  fi
}

remove_git() {
  define_sudo
  sudo yum remove -y git* || true
}

package_pattern_from_url() {
  _url=${1}
  echo ${_url} | awk -F '/' '{print $NF}' | awk -F '.' '{print $1}'
}

install_repo_from_url() {
  _url=${1}
  define_sudo
  sudo yum list installed | grep $(package_pattern_from_url ${_url}) \
    || sudo yum install -y ${_url}
}

print_git_version() {
  git --version 2>/dev/null
}

verify_git_version() {
  print_git_version | egrep "[2-9]\.[0-9]+\.[0-9]+" 2>/dev/null 1>/dev/null
}

yum_install() {
  define_sudo
  sudo yum install -y $@
}

install_git_from_url() {
  _package=${1}
  _url=${2}
  if install_repo_from_url ${_url}; then
    define_sudo
    remove_git
    yum_install ${_package}
  fi
}

install_git_from_source() {
  _version=${1}
  define_sudo
  remove_git
  yum install -y make curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc perl-ExtUtils-MakeMaker wget
  mkdir /root/git \
  && cd /root/git \
  && wget "${BASE_URL_GIT_SOURCE_REPO}/git-${_version}.tar.gz" \
  && tar xvzf "git-${_version}.tar.gz" \
  && cd git-${_version} \
  && make prefix=/usr all \
  && make prefix=/usr install
}

############
### MAIN ###
############

# exit, if git has correct version
verify_git_version \
  && echo "git v2+ already installed" \
  && print_git_version \
  && exit 0

# install git from IUS repo and exit on success
install_git_from_url ${GIT_PACKAGE_IUS} ${URL_IUS} \
  && print_git_version \
  && verify_git_version \
  && exit 0

# install git from packages repo and exit on success
install_git_from_url ${GIT_PACKAGE_PACKAGES} ${URL_PACKAGES} \
  && print_git_version \
  && verify_git_version \
  && exit 0

# install directly from IUS PRM and exit on success
yum_install ${URL_IUS_GIT_RPM} \
  && print_git_version \
  && verify_git_version \
  && exit 0

# install git from wandisco repo and exit on success
CENTOS_MAIN_VERSION=$(cat /etc/centos-release | awk '{print $4}' | awk -F '.' '{print $1}')
[ "${CENTOS_MAIN_VERSION}" == "7" ] \
  && install_git_from_url ${GIT_PACKAGE_WANDISCO} ${URL_WANDISCO} \
  && print_git_version \
  && verify_git_version \
  && exit 0

# install from source and exit on success
install_git_from_source ${GIT_VERSION_FROM_SOURCE} \
  && print_git_version \
  && verify_git_version \
  && exit 0

exit 1
