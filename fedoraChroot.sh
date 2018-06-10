#!/bin/bash 
# This script will build a basic Fedora chroot environment that will allow us
# to upgrade to a full system.
# This is using supermin and one of their premade scripts

set -e

if [ "$(id -u)" -eq "0" ]
then
	echo "Do not run this script as root!"
	exit 1
fi

# Prepare Mode

dir=$(pwd)
deps="yum yum-config-manager supermin"
pkgs="bash coreutils rpm"
server=https://fedora.mirror.constant.com
serverpath=fedora/linux/releases/28/Everything/x86_64/os/Packages/f

if [ -d Fedora.d ]
then
	echo "Removing old packages directory"
	sudo rm -rf Fedora.d
fi

if [ -d Fedora ]
then
	echo "Removing old install directory"
	sudo rm -rf Fedora
fi

for dep in $deps
do
	if [[ "$(which $dep)" == "" ]]
	then
		echo "Please install $dep before continuing..."
		exit 1
	fi
done

echo "Building a mininum chroot envrinment with $pkgs ..."

mkdir Fedora.d

supermin --prepare $pkgs -o Fedora.d

# Build Mode

mkdir Fedora

supermin --build -f chroot -o Fedora Fedora.d

echo "Finished Building!"
ls -lsh Fedora

# Preparing Chroot
echo "Creating Fedora repos lists"
wget $server/$serverpath/fedora-release-28-1.noarch.rpm
wget $server/$serverpath/fedora-gpg-keys-28-1.noarch.rpm
wget $server/$serverpath/fedora-repos-28-1.noarch.rpm

mkdir -p Fedora/rpms

mv -v fedora-release-28-1.noarch.rpm Fedora/rpms/fedora.rpm
mv -v fedora-gpg-keys-28-1.noarch.rpm Fedora/rpms/fedora-keys.rpm
mv -v fedora-repos-28-1.noarch.rpm Fedora/rpms/fedora-repos.rpm

echo "Preparing Fedora install script"

cat > Fedora/fedora.sh << EOF
#!/bin/bash
echo "Entering chroot ..."
cd /rpms
rpm --import https://getfedora.org/static/9DB62FB1.txt
rpm -ivh --nosignature fedora-keys.rpm
rpm -ivh --nosignature ./*
EOF

chmod +x Fedora/fedora.sh

#echo "Installing repos"
#rpm -ivh --nosignature --root=$(pwd)/Fedora Fedora/rpms/fedora-repos.rpm

echo "Enabling Repos"
sudo yum-config-manager --add-repo="https://download.fedoraproject.org/pub/fedora/linux/releases/28/Everything/x86_64/os"
sudo yum-config-manager --add-repo="https://download.fedoraproject.org/pub/fedora/linux/updates/28/Everything/x86_64"

echo "Installing dnf"
sudo yum --installroot=$(pwd)/Fedora --releasever=28 install -y --nogpgcheck dnf Fedora/rpms/*

#sudo chroot Fedora /fedora.sh
