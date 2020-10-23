# Install GIT via Rackspace IUS directly from rpm:

sudo echo nothing 2>/dev/null 1>/dev/null || alias sudo=''
sudo yum remove -y git*
sudo yum list installed | grep ius-release-el7 \
    || sudo yum install -y  https://repo.ius.io/ius-release-el7.rpm
sudo yum install -y git-core
git --version 2>/dev/null | egrep "[2-9]\.[0-9]+\.[0-9]+" 2>/dev/null \
  && exit 0 \
  || exit 1

############################

# sudo errors below this line...

define_sudo() {
  sudo echo nothing 2>/dev/null 1>/dev/null || alias sudo=''
}
export -f define_sudo

remove_git() {
  define_sudo
  sudo yum remove -y git* || true
}
export -f remove_git

install_ius_repo() {
  define_sudo
  sudo yum list installed | grep ius-release-el7 \
    || sudo yum install -y  https://repo.ius.io/ius-release-el7.rpm
}
export -f install_ius_repo

install_endpoint_repo() {
  define_sudo
  sudo yum list installed | grep endpoint-repo \
    || sudo yum install -y  https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm
}
export -f install_endpoint_repo

install_wandisco_repo() {
  define_sudo
  sudo yum list installed | grep endpoint-repo \
    || sudo yum install -y http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-2.noarch.rpm
}
export -f install_wandisco_repo

verify_git_version() {
  git --version 2>/dev/null | egrep "[2-9]\.[0-9]+\.[0-9]+" 2>/dev/null 1>/dev/null
}
export -f verify_git_version

git_install() {
  define_sudo
  sudo yum install -y $@
}
export -f git_install


if verify_git_version; then
  echo "git v2+ already installed"
  true
fi

if install_ius_repo; then
  define_sudo
#  sudo echo nothing 2>/dev/null 1>/dev/null || alias sudo='$@'
  remove_git
  git_install git-core \
  && verify_git_version \
  && exit 0
fi

export -f define_sudo
export -f remove_git
export -f verify_git_version

if install_endpoint_repo; then
  export -f remove_git
  export -f verify_git_version
  remove_git \
  && sudo yum install -y git \
  && verify_git_version \
  && exit 0
fi

CENTOS_MAIN_VERSION=$(cat /etc/centos-release | awk '{print $4}' | awk -F '.' '{print $1}')
if [ "${CENTOS_MAIN_VERSION}" == "7" ] && install_wandisco_repo; then
  remove_git \
  && sudo yum install -y git \
  && verify_git_version \
  && exit 0
fi

exit 1


# Install git
if sudo yum list installed | grep ius-release-el7; then
  sudo yum remove -y git*
  sudo yum install -y git-core \
  && git --version | egrep "[2-9]\.[0-9]+\.[0-9]+" \
  && exit 0
fi

sudo yum remove git*
sudo yum -y install https://packages.endpoint.com/rhel/7/os/x86_64/endpoint-repo-1.7-1.x86_64.rpm \
  && sudo yum install git \
  && git --version \
  && exit 0

sudo yum install -y https://repo.ius.io/7/x86_64/packages/g/git224-core-2.24.3-1.el7.ius.x86_64.rpm \
  && git --version \
  && exit 0



# Was not successful? Then try via the Wandisco Repo:

# new method found on https://stackoverflow.com/questions/21820715/how-to-install-latest-version-of-git-on-centos-7-x-6-x
# I have seen major problems with CentoS 8, so we will apply it only for CentOS 7:
CENTOS_MAIN_VERSION=$(cat /etc/centos-release | awk '{print $4}' | awk -F '.' '{print $1}')

[ "${CENTOS_MAIN_VERSION}" == "7" ] \
  && echo "Not successfully tested for CentOS version ${CENTOS_MAIN_VERSION}. Skipping ..." \
  && yum install -y http://opensource.wandisco.com/centos/7/git/x86_64/wandisco-git-release-7-2.noarch.rpm \
  && yum install -y git \
  && git --version \
  && exit 0

exit 1


# old (create from source, takes longer):

yum remove -y git
yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc perl-ExtUtils-MakeMaker wget
[ "$GIT_VERSION" == "" ] && export GIT_VERSION=2.14.2
mkdir /root/git
cd /root/git
wget "https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz"
tar xvzf "git-${GIT_VERSION}.tar.gz"
cd git-${GIT_VERSION}
make prefix=/usr all
make prefix=/usr install
#yum remove -y git
git --version # should be GIT_VERSION
