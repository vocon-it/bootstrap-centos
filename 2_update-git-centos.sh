sudo yum remove git
yum install -y curl-devel expat-devel gettext-devel openssl-devel zlib-devel gcc perl-ExtUtils-MakeMaker wget
[ "$GIT_VERSION" == "" ] && export GIT_VERSION=2.14.2
mkdir /root/git
cd /root/git
wget "https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz"
tar xvzf "git-${GIT_VERSION}.tar.gz"
cd git-${GIT_VERSION}
make prefix=/usr/local all
make prefix=/usr/local install
yum remove -y git
cat /etc/bashrc | grep "PATH" | grep -qv '/usr/local/bin' && echo "export PATH=$PATH:/usr/local/bin" >> /etc/bashrc
source /etc/bashrc
git --version # should be GIT_VERSION
