echo -e "#!/bin/sh\n$CC -static \$@" > /usr/bin/gcc
chmod +x /usr/bin/gcc
cd /build
unxz < linux-4.1.39.tar.xz | tar x 
cd linux-4.1.39 
cp ../linux.config .config
make oldconfig ARCH=i386 
make ARCH=i386 PATH=$CCBIN:$TOOLSBIN:$PATH 
ln arch/x86/boot/bzImage /CD_root/bzImage 

cd /build
bunzip2 < busybox-1.26.2.tar.bz2 | tar x
cd busybox-1.26.2 
cp ../busybox.config .config
sed -i -re '295s/-1/1/' include/libbb.h
PATH=$TOOLSBIN:$PATH
make oldconfig 
make TGTARCH=i486 \
    LDFLAGS="--static" \
    EXTRA_CFLAGS=-m32 \
    EXTRA_LDFLAGS=-m32 \
    HOSTCFLAGS="-D_GNU_SOURCE"
make CONFIG_PREFIX=/initramfs install
rm /usr/bin/gcc

cd /initramfs
find . | cpio -o -H newc | gzip > ../CD_root/initramfs_data.cpio.gz
cd  /
ln /usr/share/syslinux/ldlinux.c32 /usr/share/syslinux/isolinux.bin CD_root/isolinux/
/opt/schily/bin/mkisofs \
    -allow-leading-dots \
    -allow-multidot \
    -l \
    -relaxed-filenames \
    -no-iso-translate \
    -o blockless.iso \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table CD_root