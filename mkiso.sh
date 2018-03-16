#!/bin/bash

set -xe

if [ $(id -u) -ne 0 ]; then
    echo "must run as root"
    exit 1
fi

time=$(date +%Y%m%d%H%M)
product=ubuntu-iso-${time}.iso

workdir=$(dirname $(readlink -f $0))
cd ${workdir}

if [ -d ./cache ]; then
    rm -rf ./cache
fi
mkdir ./cache
chmod 777 ./cache
if [ -d ./tmp ]; then
    rm -rf ./tmp
fi
mkdir ./tmp

echo -n "cp ./baseiso -> ./tmp/FinalCD ... "
cp -ra ./baseiso ./tmp/FinalCD
echo "OK"

setup_apt() {
    echo
    echo "******************************************"
    echo "Setup apt"
    echo "******************************************"

    cd ${workdir}/tmp
    ## configure apt
    # apt deb
    cat > ./apt-ftparchive-deb.conf << deb_EOF
Dir {
  ArchiveDir "$(pwd)/FinalCD";
};

TreeDefault {
  Directory "pool/";
};

BinDirectory "pool/main" {
  Packages "dists/xenial/main/binary-amd64/Packages";
};

Default {
  Packages {
    Extensions ".deb";
    Compress ". gzip";
  };
};

Contents {
  Compress "gzip";
};
deb_EOF
    # apt udeb
    cat > ./apt-ftparchive-udeb.conf << udeb_EOF
Dir {
  ArchiveDir "$(pwd)/FinalCD";
};

TreeDefault {
  Directory "pool/";
};

BinDirectory "pool/main" {
  Packages "dists/xenial/main/debian-installer/binary-amd64/Packages";
};

Default {
  Packages {
    Extensions ".udeb";
    Compress ". gzip";
  };
};

Contents {
  Compress "gzip";
};
udeb_EOF
    # apt extras
    cat > ./apt-ftparchive-extras.conf << extras_EOF
Dir {
  ArchiveDir "$(pwd)/FinalCD";
};

TreeDefault {
  Directory "pool/";
};

BinDirectory "pool/extras" {
  Packages "dists/xenial/extras/binary-amd64/Packages";
};

Default {
  Packages {
    Extensions ".deb";
    Compress ". gzip";
  };
};

Contents {
  Compress "gzip";
};
extras_EOF

    apt-ftparchive generate apt-ftparchive-deb.conf && \
    apt-ftparchive generate apt-ftparchive-udeb.conf && \
    apt-ftparchive generate apt-ftparchive-extras.conf && \
    apt-ftparchive release ./FinalCD/dists/xenial/ >> ./FinalCD/dists/xenial/Release
    if [ $? -ne 0 ]; then
        echo -e "\nConfigure APT Failed\n"
        exit 1
    fi

    return 0
}


build_iso() {
    setup_apt
    cd ${workdir}
    mkisofs -b isolinux/isolinux.bin -c isolinux/boot.cat -allow-limited-size -no-emul-boot -boot-load-size 4 -boot-info-table -hide-rr-moved -o ./cache/${product} -R tmp/FinalCD
    isohybrid ./cache/${product}
    rm -rf tmp
}

build_iso

