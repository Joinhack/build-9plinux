FROM ysangkok/i486-musl-cross
WORKDIR /

ENV CC /i486-musl-cross/bin/i486-linux-musl-gcc
ENV LD /i486-musl-cross/bin/i486-linux-musl-ld
ENV CXX /i486-musl-cross/bin/i486-linux-musl-g++
ENV CCBIN /i486-musl-cross/bin
ENV TOOLSBIN /i486-musl-cross/i486-linux-musl/bin
VOLUME /build

#make-4.1 uses OLDGNU tar format that busybox doesn't support, use our own tar
# alternative: https://sourceforge.net/projects/s-tar/files/
COPY sltar.c sltar.c
# alternative to make-4.1.tar.bz2: http://fossies.org/linux/privat/bmake-20141111.zip
COPY packages/make-4.2.1.tar.bz2 make-4.2.1.tar.bz2
RUN   $CC sltar.c -DVERSION="\"9000\"" -static -o sltar \
  &&  bunzip2 < make-4.2.1.tar.bz2 | ./sltar x \
  &&  ( \
            cd make-4.2.1 \
        &&  ./configure PATH=$TOOLSBIN:$CCBIN:$PATH CC="$CC" LDFLAGS="-static" AR=$TOOLSBIN/ar RANLIB=$TOOLSBIN/ranlib \
        &&  ./build.sh \
      )
COPY ./patchelf-0.9 patchelf
RUN cd patchelf && ./configure LDFLAGS=-static
RUN cd patchelf/src; $TOOLSBIN/../lib/libc.so /make-4.2.1/make MAKE="$TOOLSBIN/../lib/libc.so /make-4.2.1/make" AUTOMAKE=: AUTOCONF=:; cp patchelf /usr/bin
RUN patchelf --set-interpreter $TOOLSBIN/../lib/libc.so /make-4.2.1/make
RUN cd /make-4.2.1; cp ./make /usr/bin/make
RUN rm -rf make-4.2.1.tar.bz2 /make-4.2.1

ENV PATH /usr/local/bin:$PATH
COPY packages/nasm-2.11.08.tar.xz nasm-2.11.08.tar.xz
RUN   unxz < nasm-2.11.08.tar.xz | tar x \
  &&  ( \
            cd nasm-2.11.08 \
        &&  ./configure LDFLAGS="-static" CC=$CC \
        &&  make \
        &&  make install \
      ) \
  &&  rm -rf nasm-2.11.08 nasm-2.11.08.tar.xz\
  &&  nasm; if [[ $? != 1 ]]; then echo "no nasm"; exit 1; fi
COPY packages/syslinux-6.03.tar.xz syslinux-6.03.tar.xz
COPY packages/bigperl.bin /usr/bin/perl
RUN  unxz < syslinux-6.03.tar.xz | tar x \
  &&  chmod +x /usr/bin/perl

COPY packages/libuuid-1.0.3.tar.gz libuuid-1.0.3.tar.gz
RUN   gunzip < libuuid-1.0.3.tar.gz | /sltar x \
  &&  ( \
          cd libuuid-1.0.3 \
      &&  ./configure \
            --prefix=$TOOLSBIN/.. \
            CC=$CC \
            AR=$TOOLSBIN/ar \
            LDFLAGS=-static\
      ) \
  &&  make -C libuuid-1.0.3 \
        PATH=$CCBIN:$PATH \
        AUTOCONF=: AUTOHEADER=: AUTOMAKE=: ACLOCAL=: \
  &&  make -C libuuid-1.0.3 \
        install \
        AUTOCONF=: AUTOHEADER=: AUTOMAKE=: ACLOCAL=: \
  &&  rm -rf libuuid-1.0.3 libuuid-1.0.3.tar.gz

RUN   make -C syslinux-6.03 \
        install \
        PATH=$CCBIN:$PATH \
        CC=$CC \
        AR=$TOOLSBIN/ar \
        RANLIB=$TOOLSBIN/ranlib \
        LD=$LD \
        OBJCOPY=$CCBIN/i486-linux-musl-objcopy \
  &&  rm -rf syslinux-6.03 syslinux-6.03.tar.xz 
# replace shebang to avoid using bash
#RUN   curl http://landley.net/toybox/downloads/toybox-0.5.2.tar.gz | gunzip | tar x \
#  &&  cd toybox-0.5.2 \
#  &&  sed -i -re '1 s,^.*$,#!/bin/sh,g' scripts/genconfig.sh \
#  &&  echo -e '#!/bin/sh\n/x86_64-linux-musl/bin/x86_64-linux-musl-gcc -static $@' > /usr/bin/cc \
#  &&  chmod +x /usr/bin/cc \
#  &&  make defconfig \
#  &&  rm /usr/bin/cc

COPY packages/bzip2-bzip2-1.0.8.tar.gz bzip2-bzip2-1.0.8.tar.gz
RUN  gunzip < bzip2-bzip2-1.0.8.tar.gz | tar x 
RUN ( \
  cd bzip2-bzip2-1.0.8 \
  && make CC=$CC LDFLAGS=-static AR=$TOOLSBIN/ar RANLIB=$TOOLSBIN/ranlib bzip2 \
  && ./bzip2 \
  && cp bzip2 /usr/local/bin \
) && rm -rf bzip2-bzip2-1.0.8*

COPY packages/byacc.tar.gz byacc.tar.gz
RUN  gunzip < byacc.tar.gz | tar x
RUN   (     cd byacc* \
        &&  ./configure \
            LDFLAGS=-static \
            CC=$CC \
            AR=$TOOLSBIN/ar \
            RANLIB=$TOOLSBIN/ranlib \
        &&  make \
        &&  make install\
      ) \
  &&  rm -rf byacc*

COPY packages/m4-1.4.17.tar.xz m4-1.4.17.tar.xz
RUN  unxz < m4-1.4.17.tar.xz | tar x \
  &&  ( \
            cd m4-1.4.17 \
        &&  ./configure \
              LDFLAGS=-static \
              CC=$CC \
              AR=$TOOLSBIN/ar \
        RANLIB=$TOOLSBIN/ranlib \
        &&  make \
              PATH=$CCBIN:$PATH \
        &&  make install \
      ) \
  &&  rm -rf m4-1.4.17 m4-1.4.17.tar.xz

COPY packages/flex-2.5.39.tar.xz flex-2.5.39.tar.xz
# alternative for this method: a zip file: http://fossies.org/linux/misc/flex-2.5.39.zip
RUN unxz < flex-2.5.39.tar.xz | /sltar x

RUN   cd flex-2.5.39 \
  &&  grep -vE ' *doc *\\ *' < Makefile.am > temp \
  &&  mv temp Makefile.am \
  &&  grep -vE ' *doc *\\ *' < Makefile.in > temp \
  &&  mv temp Makefile.in \
  &&  ./configure --enable-static LDFLAGS=--static CC=$CC RANLIB=$TOOLSBIN/ranlib
RUN   cd flex-2.5.39 \
  &&  make \
        PATH=$TOOLSBIN:$CCBIN:$PATH
RUN   cd flex-2.5.39 \
  &&  ./flex; if [[ $? != 1 ]]; then ls -ld flex; exit 1; fi
RUN   ( \
            cd flex-2.5.39 \
        &&  make \
              install \
              PATH=$CCBIN:$PATH \
      ) \
  &&  rm -rf flex-2.5.39 flex-2.5.39.tar.xz

COPY packages/lunzip-1.9.tar.gz lunzip-1.9.tar.gz
RUN  gunzip < lunzip-1.9.tar.gz | tar x \
  &&  ( \
            cd lunzip-1.9 \
        &&  ./configure \
              CC=$CC \
              AR=$TOOLSBIN/ar \
              RANLIB=$TOOLSBIN/ranlib \
              LDFLAGS=-static \
        &&  make \
        &&  make install \
      ) \
  &&  rm -rf lunzip-1.9 lunzip-1.9.tar.gz

COPY packages/ed-1.11.tar.lz ed-1.11.tar.lz
RUN  lunzip < ed-1.11.tar.lz | tar x \
  &&  ( \
            cd ed-1.11 \
        &&  ./configure \
              LDFLAGS=-static \
              CC=$CC \
              AR=$TOOLSBIN/ar \
              RANLIB=$TOOLSBIN/ranlib \
        &&  make \
        &&  make install \
      ) \
  &&  rm -rf ed-1.11 ed-1.11.tar.lz

COPY packages/bc-1.06.95.tar.bz2 bc-1.06.95.tar.bz2
RUN  bunzip2 < bc-1.06.95.tar.bz2 | /sltar x \
  &&  ( \
            cd bc-1.06.95 \
        &&  ./configure \
              CC=$CC \
              LDFLAGS=-static \
        &&  sed -i -re 's/ doc$//' Makefile.am Makefile.in \
        &&  make \
              PATH=$CCBIN:$PATH \
              AR=$TOOLSBIN/ar \
              RANLIB=$TOOLSBIN/ranlib \
        &&  make install \
      ) \
  &&  rm -rf bc-1.06.95 bc-1.06.95.tar.bz2


COPY packages/smake-1.2.5.tar.gz smake-1.2.5.tar.gz
RUN gunzip < smake-1.2.5.tar.gz | tar x
# make bootstrap smake:
RUN   cd smake-1.2.5/psmake \
  &&  export MAKE=make && \
  LDFLAGS=-static CC=$CC ./MAKE-all

RUN   ( \
            cd smake-1.2.5 \
        &&  sed -i.bak -re "67 s,^.*$,LDFLAGS='\$(LDOPTS)' $PWD/autoconf/configure \$(CONFFLAGS),g" RULES/rules.cnf \
        &&  make PATH=$CCBIN:$PATH CCOM=gcc CC_COM=$CC LDOPTS="-static" \
        &&  $TOOLSBIN/ranlib libs/x86_64-linux-gcc/libschily.a \
        &&  (cd smake; $CC -Llibs/x86_64-linux-cc -o OBJ/x86_64-linux-gcc/smake OBJ/x86_64-linux-gcc/make.o \
        OBJ/x86_64-linux-gcc/archconf.o OBJ/x86_64-linux-gcc/readfile.o OBJ/x86_64-linux-gcc/parse.o \
        OBJ/x86_64-linux-gcc/update.o OBJ/x86_64-linux-gcc/rules.o  OBJ/x86_64-linux-gcc/job.o OBJ/x86_64-linux-gcc/memory.o \
        -static -L../libs/x86_64-linux-gcc -lschily) \
        &&  make install\
      ) \
  &&  rm -rf smake-1.2.5 smake-1.2.5.tar.gz \
  &&  /opt/schily/bin/smake; if [[ $? != 1 ]]; then echo "no smake"; exit 1; fi


COPY packages/bash-4.3.30.tar.gz bash-4.3.30.tar.gz
RUN  gunzip < bash-4.3.30.tar.gz | tar x \
  &&  ( \
            cd bash-4.3.30 \
         && ./configure \
              --prefix=/ \
              --without-bash-malloc \
              PATH=$CCBIN:$PATH \
              CC=$CC \
              LDFLAGS=-static \
              AR=$TOOLSBIN/ar \
              RANLIB=$TOOLSBIN/ranlib \
         && make \
              PATH=$CCBIN:$PATH \
         && make install\
      ) \
  &&  rm -rf bash-4.3.30 bash-4.3.30.tar.gz \
  &&  rm -r share

COPY packages/cdrtools-3.02a09.tar.bz2 cdrtools.tar.bz2
RUN    bunzip2 < cdrtools.tar.bz2 | tar x \
  &&  PATH=$CCBIN:$PATH /opt/schily/bin/smake -C cdrtools-3.02 CC_COM=$CC CCOM=gcc LDOPTS=-static
RUN cd cdrtools-3.02/mkisofs; for i in ../libs/x86_64-linux-gcc/*.a; do $TOOLSBIN/ranlib $i; done
RUN cd cdrtools-3.02/mkisofs; \
    $CC -o OBJ/x86_64-linux-gcc/mkisofs OBJ/x86_64-linux-gcc/mkisofs.o OBJ/x86_64-linux-gcc/tree.o \
    OBJ/x86_64-linux-gcc/write.o OBJ/x86_64-linux-gcc/hash.o OBJ/x86_64-linux-gcc/rock.o \
    OBJ/x86_64-linux-gcc/inode.o OBJ/x86_64-linux-gcc/udf.o OBJ/x86_64-linux-gcc/multi.o  \
    OBJ/x86_64-linux-gcc/joliet.o OBJ/x86_64-linux-gcc/match.o OBJ/x86_64-linux-gcc/name.o \
    OBJ/x86_64-linux-gcc/eltorito.o OBJ/x86_64-linux-gcc/boot.o OBJ/x86_64-linux-gcc/isonum.o  \
    OBJ/x86_64-linux-gcc/scsi.o  OBJ/x86_64-linux-gcc/apple.o OBJ/x86_64-linux-gcc/volume.o \
    OBJ/x86_64-linux-gcc/desktop.o OBJ/x86_64-linux-gcc/mac_label.o OBJ/x86_64-linux-gcc/stream.o  \
    OBJ/x86_64-linux-gcc/ifo_read.o OBJ/x86_64-linux-gcc/dvd_file.o OBJ/x86_64-linux-gcc/dvd_reader.o  \
    OBJ/x86_64-linux-gcc/walk.o  -static  -lhfs -lfile -lsiconv -lscgcmd -lrscg -lscg  -lcdrdeflt -ldeflt  \
    -lfind -lmdigest -lschily -L../libs/x86_64-linux-gcc/
RUN  PATH=$CCBIN:$PATH /opt/schily/bin/smake -C cdrtools-3.02 install CC_COM=$CC CCOM=gcc LDOPTX=-static
RUN  /opt/schily/bin/mkisofs; if [[ $? != 1 ]]; then echo "no mkisofs"; exit 1; fi
RUN  cd / && rm  -rf cdrtools-3.02 cdrtools.tar.bz2

COPY packages/cpio-2.12.tar.bz2 cpio-2.12.tar.bz2
RUN    bunzip2 < cpio-2.12.tar.bz2 | tar x \
  &&  ( \
            cd cpio-2.12 \
        &&  touch aclocal.m4 configure \
        &&  ./configure LDFLAGS=-static CC=$CC AUTOCONF=: AUTOHEADER=: AUTOMAKE=: AR=$TOOLSBIN/ar RANLIB=$TOOLSBIN/ranlib \
        &&  PATH=$CCBIN:$PATH make AUTOCONF=: AUTOHEADER=: AUTOMAKE=:  \
        &&  make install \
      ) \
  &&  rm -rf cpio-2.12 cpio-2.12.tar.bz2   \
  && cpio;if [[ $? != 2 ]]; then echo "no cpio"; exit 1; fi

COPY entry.sh entry.sh
COPY packages/bash-4.3.30.tar.gz bash-4.3.30.tar.gz
RUN  gunzip < bash-4.3.30.tar.gz | tar x \
  &&  ( \
             cd bash-4.3.30 \
         &&  ./configure \
                --enable-static-link \
                --build=i386-linux \
                --host=x86_64-linux \
                --prefix=/ \
                --without-bash-malloc \
                PATH=$CCBIN:$PATH \
                LDFLAGS_FOR_BUILD=-static \
                CC_FOR_BUILD=$CC \
                CC=$CC \
                AR=$TOOLSBIN/ar \
         &&  make RANLIB=$TOOLSBIN/ranlib \
         &&  make install DESTDIR=/initramfs \
         &&  $TOOLSBIN/strip /initramfs/bin/bash \
      ) \
  &&  rm -rf /bash-4.3.30 bash-4.3.30.tar.gz


#########################################################################################################################################################
COPY isolinux.cfg CD_root/isolinux/
# COPY config-3.17.8 .config
# COPY isolinux.cfg CD_root/isolinux/
# COPY packages/linux-4.1.39.tar.xz linux-4.1.39.tar.xz
# RUN  unxz < linux-4.1.39.tar.xz | tar x \
#   &&  echo -e "#!/bin/sh\n$CC -static \$@" > /usr/bin/gcc \
#   &&  chmod +x /usr/bin/gcc \
#   &&  ( \
#             cd linux-4.1.39 \
#         &&  mv ../.config . \
#         &&  make oldconfig ARCH=i386 \
#         &&  make ARCH=i386 PATH=$CCBIN:$TOOLSBIN:$PATH \
#         &&  ln arch/x86/boot/bzImage ../CD_root/bzImage \
#       ) \
#   &&  rm -rf linux-4.1.39 \
#   &&  rm /usr/bin/gcc


# COPY packages/busybox-1.26.2.tar.bz2 busybox-1.26.2.tar.bz2
# RUN  bunzip2 < busybox-1.26.2.tar.bz2 | tar x \
#   && echo -e "#!/bin/sh\n/$CC -static \$@" > /usr/bin/gcc \
#   && chmod +x /usr/bin/gcc
# COPY busybox-1.23.1-config /busybox-1.26.2/.config
# RUN  ( \
#           cd busybox-1.26.2 && sed -i -re '295s/-1/1/' include/libbb.h \
#        && PATH=$TOOLSBIN:$PATH \
#        && make oldconfig \
#        && make \
#           TGTARCH=i486 \
#           LDFLAGS="--static" \
#           EXTRA_CFLAGS=-m32 \
#           EXTRA_LDFLAGS=-m32 \
#           HOSTCFLAGS="-D_GNU_SOURCE" \
#        && make CONFIG_PREFIX=/initramfs install\
# ) && cd /&& rm -rf busybox-1.26.2  && rm /usr/bin/gcc

# # remove bash locale stuff
# RUN rm -rv initramfs/share

# # copying into the container
# COPY initramfs initramfs/

# RUN  ( \
#           cd initramfs \
#        && find . | cpio -o -H newc | gzip > ../CD_root/initramfs_data.cpio.gz \
#      ) \
#  &&  ln /usr/share/syslinux/ldlinux.c32 /usr/share/syslinux/isolinux.bin CD_root/isolinux/ \
#  &&  /opt/schily/bin/mkisofs \
#        -allow-leading-dots \
#        -allow-multidot \
#        -l \
#        -relaxed-filenames \
#        -no-iso-translate \
#        -o blockless.iso \
#        -b isolinux/isolinux.bin \
#        -c isolinux/boot.cat \
#        -no-emul-boot \
#        -boot-load-size 4 \
#        -boot-info-table CD_root
