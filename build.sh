#!/usr/bin/env bash
#

set -e

main() {
	case "$1" in
		x86_64)
			export XTARGET="x86_64-linux-musl"
			export LTARGET="X86"
			export LARCH="x86_64"
			export MARCH="x86_64"
			export KARCH="x86_64"
			;;
		i386)
			export XTARGET="i386-linux-musl"
			export LTARGET="X86"
			export LARCH="i686"
			export MARCH="i386"
			export KARCH="i386"
			;;
		aarch64)
			export XTARGET="aarch64-linux-musl"
			export LTARGET="AArch64"
			export LARCH="aarch64"
			export MARCH="aarch64"
			export KARCH="arm64"
			;;
		armv7l)
			export XTARGET="armv7l-linux-musleabihf"
			export LTARGET="ARM"
			export LARCH="armv7"
			export MARCH="arm"
			export KARCH="arm"
			;;
		armv6l)
			export XTARGET="armv6l-linux-musleabihf"
			export LTARGET="ARM"
			export LARCH="armv6"
			export MARCH="arm"
			export KARCH="arm"
			;;
		mips64)
			export XTARGET="mips64-linux-musl"
			export LTARGET="Mips"
			export LARCH="mips64"
			export MARCH="mips64"
			export KARCH="mips"
			;;
		mips64el)
			export XTARGET="mips64el-linux-musl"
			export LTARGET="Mips"
			export LARCH="mips64el"
			export MARCH="mips64"
			export KARCH="mips"
			;;
		mips)
			export XTARGET="mips-linux-musl"
			export LTARGET="Mips"
			export LARCH="mips"
			export MARCH="mips"
			export KARCH="mips"
			;;
		mipsel)
			export XTARGET="mipsel-linux-musl"
			export LTARGET="Mips"
			export LARCH="mipsel"
			export LARCH="mips"
			export MARCH="mips"
			export KARCH="mips"
			;;
		powerpc64le)
			export XTARGET="powerpc64le-linux-musl"
			export LTARGET="PowerPC"
			export LARCH="powerpc64le"
			export MARCH="powerpc64"
			export KARCH="powerpc"
			;;
		powerpc64)
			export XTARGET="powerpc64-linux-musl"
			export LTARGET="PowerPC"
			export LARCH="powerpc64"
			export MARCH="powerpc64"
			export KARCH="powerpc"
			;;
		riscv64)
			export XTARGET="riscv64-linux-musl"
			export LTARGET="RISCV"
			export LARCH="riscv64"
			export MARCH="riscv64"
			export KARCH="riscv"
			;;
		*)
			echo "Specify CPU architecture"
			exit 1
			;;
	esac

	export MUSLVER="1.2.1"
	export LLVMVER="11.0.0"
	export LINUXVER="5.10"
	export FORTIHVER="1.1"

	export LANG=C
	export LC_ALL=C
	export HOSTCC=clang
	export HOSTCXX=clang++
	export STUFF="$PWD/stuff"
	export BUILD="$PWD/build"
	export SRCDIR="$BUILD/src"
	export TOOLS="$BUILD/tools"
	export SYSROOT="$BUILD/sysroot"
	export PATH="$TOOLS/bin:$PATH"

	rm -rvf "$BUILD"
	mkdir -pv "$SRCDIR" "$TOOLS" "$SYSROOT"

	cd "$SRCDIR"
	curl -C - -L --retry 3 --retry-delay 3 -O https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$LINUXVER.tar.xz
	bsdtar -xvf linux-$LINUXVER.tar.xz

	for i in llvm clang clang-tools-extra lld compiler-rt libunwind libcxx libcxxabi; do
		curl -C - -L --retry 3 --retry-delay 3 -O https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVMVER/$i-$LLVMVER.src.tar.xz
		bsdtar -xvf $i-$LLVMVER.src.tar.xz
	done

	pushd "$SRCDIR/llvm-$LLVMVER.src"
		patch -Np1 -i "$STUFF"/llvm/0001-PowerPC64-ELFv2-fixes.patch
		patch -Np1 -i "$STUFF"/llvm/0002-Use-pc-relative-relocations-in-.eh_frame-on-MIPS.patch
	popd
	pushd "$SRCDIR/clang-$LLVMVER.src"
		patch -Np1 -i "$STUFF"/clang/0001-add-support-for-Ataraxia-Linux.patch
		patch -Np1 -i "$STUFF"/clang/0002-PowerPC64-ELFv2-fixes.patch
		patch -Np1 -i "$STUFF"/clang/0003-Add-fortify-headers-paths.patch
	popd
	pushd "$SRCDIR/compiler-rt-$LLVMVER.src"
		patch -Np1 -i "$STUFF"/compiler-rt/0001-port-crt-on-MIPS-build-on-PowerPC.patch
	popd
	pushd "$SRCDIR/libcxxabi-$LLVMVER.src"
		patch -Np1 -i "$STUFF"/libcxxabi/musl.patch
	popd
	pushd "$SRCDIR/libcxx-$LLVMVER.src"
		patch -Np1 -i "$STUFF"/libcxx/musl.patch
	popd

	curl -C - -L --retry 3 --retry-delay 3 -O https://musl.libc.org/releases/musl-$MUSLVER.tar.gz
	bsdtar -xvf musl-$MUSLVER.tar.gz

	#curl -C - -L --retry 3 --retry-delay 3 -O https://github.com/ataraxialinux/fortify-headers/archive/$FORTIHVER.tar.gz
	#bsdtar -xvf $FORTIHVER.tar.gz

	cd "$SRCDIR"/linux-$LINUXVER
	make mrproper -j$(nproc)

	make ARCH=$KARCH headers -j$(nproc)
	mkdir -p "$SYSROOT"/usr/include

	find usr/include -name '.*' -delete
	rm usr/include/Makefile
	cp -a usr/include/* "$SYSROOT"/usr/include

	find "$SYSROOT" \( -name .install -o -name ..install.cmd \) -print0 | xargs -0 rm -rf

	#cd "$SRCDIR"/fortify-headers-$FORTIHVER
	#make DESTDIR="$SYSROOT" PREFIX=/usr install

	cd "$SRCDIR"/llvm-$LLVMVER.src
	cp -av "$SRCDIR"/clang-$LLVMVER.src tools/clang
	cp -av "$SRCDIR"/clang-tools-extra-$LLVMVER.src tools/clang/tools/extra
	cp -av "$SRCDIR"/lld-$LLVMVER.src tools/lld
	cp -av "$SRCDIR"/compiler-rt-$LLVMVER.src projects/compiler-rt
	cp -av "$SRCDIR"/libunwind-$LLVMVER.src projects/libunwind
	cp -av "$SRCDIR"/libcxx-$LLVMVER.src projects/libcxx
	cp -av "$SRCDIR"/libcxxabi-$LLVMVER.src projects/libcxxabi
	mkdir -p build
	cd build
	cmake "$SRCDIR/llvm-$LLVMVER.src" \
		-DCMAKE_C_COMPILER=clang \
		-DCMAKE_CXX_COMPILER=clang++ \
		-DCMAKE_INSTALL_PREFIX="$TOOLS" \
		-DCMAKE_BUILD_TYPE=Release \
		-DCLANG_BUILD_EXAMPLES=OFF \
		-DCLANG_DEFAULT_CXX_STDLIB=libc++ \
		-DCLANG_DEFAULT_LINKER=lld \
		-DCLANG_DEFAULT_RTLIB=compiler-rt \
		-DCLANG_DEFAULT_UNWINDLIB=libunwind \
		-DCLANG_INCLUDE_DOCS=OFF \
		-DCLANG_INCLUDE_TESTS=OFF \
		-DCLANG_PLUGIN_SUPPORT=ON \
		-DCLANG_VENDOR=Ataraxia \
		-DLIBCXX_CXX_ABI=libcxxabi \
		-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
		-DLIBCXX_USE_COMPILER_RT=ON \
		-DLIBCXXABI_USE_LLVM_UNWINDER=ON \
		-DLIBCXXABI_USE_COMPILER_RT=ON \
		-DLIBUNWIND_USE_COMPILER_RT=ON \
		-DLLVM_BUILD_EXAMPLES=OFF \
		-DLLVM_BUILD_DOCS=OFF \
		-DLLVM_BUILD_TESTS=OFF \
		-DLLVM_DEFAULT_TARGET_TRIPLE=$XTARGET \
		-DLLVM_TARGET_ARCH=$LARCH \
		-DLLVM_TARGETS_TO_BUILD=$LTARGET \
		-DDEFAULT_SYSROOT="$SYSROOT" \
		-Wno-dev -G Ninja
	ninja -j$(nproc)
	ninja install -j$(nproc)

	local realclang="$(readlink $TOOLS/bin/clang)"

	pushd "$TOOLS/bin"
		for i in cc c++ clang clang++ cpp; do
			cp -v $realclang $XTARGET-$i
		done

		for i in ar as dwp nm objcopy objdump size strings; do
			cp -v llvm-$i $XTARGET-$i
		done

		cp -v lld $XTARGET-ld
		cp -v lld $XTARGET-ld.lld
		cp -v llvm-symbolizer $XTARGET-addr2line
		cp -v llvm-cxxfilt $XTARGET-c++filt
		cp -v llvm-cov $XTARGET-gcov
		cp -v llvm-ar $XTARGET-ranlib
		cp -v llvm-readobj $XTARGET-readelf
		cp -v llvm-objcopy $XTARGET-strip

		rm -fv $realclang clang clang++ clang-cl clang-cpp \
			lld-link ld.lld ld64.lld wasm-ld lld
	popd

	cd "$SRCDIR"/musl-$MUSLVER
	make ARCH=$MARCH prefix=/usr DESTDIR="$SYSROOT" install-headers -j$(nproc)

	cd "$SRCDIR"
	mkdir -p compiler-rt-builtins-build
	cd compiler-rt-builtins-build
	cmake "$SRCDIR"/compiler-rt-$LLVMVER.src \
		-DCMAKE_C_COMPILER_TARGET="$XTARGET" \
		-DCMAKE_ASM_COMPILER_TARGET="$XTARGET" \
		-DCMAKE_C_COMPILER="$TOOLS/bin/$XTARGET-clang" \
		-DCMAKE_CXX_COMPILER="$TOOLS/bin/$XTARGET-clang++" \
		-DCMAKE_AR="$TOOLS/bin/$XTARGET-ar" \
		-DCMAKE_NM="$TOOLS/bin/$XTARGET-nm" \
		-DCMAKE_RANLIB="$TOOLS/bin/$XTARGET-ranlib" \
		-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
		-DLLVM_CONFIG_PATH="$TOOLS/bin/llvm-config" \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
		-DCOMPILER_RT_BUILD_BUILTINS=ON \
		-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
		-DCOMPILER_RT_BUILD_PROFILE=OFF \
		-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_STANDALONE_BUILD=ON \
		-Wno-dev -G Ninja
	ninja -j$(nproc)

	for i in lib/linux/*; do
		install -Dm644 "$i" "$TOOLS"/lib/clang/$LLVMVER/lib/linux/$(basename $i)
	done

	cd "$SRCDIR"/musl-$MUSLVER
	./configure \
		--build=$(clang -dumpmachine) \
		--host=$XTARGET \
		--target=$XTARGET \
		--prefix=/usr \
		--libdir=/usr/lib \
		--syslibdir=/usr/lib \
		--enable-optimize=size \
		LIBCC="$($XTARGET-clang -print-libgcc-file-name)"
	make -j$(nproc)
	make DESTDIR="$SYSROOT" install -j$(nproc)

	cd "$SRCDIR"
	rm -rvf llvm-$LLVMVER.src
	bsdtar -xvf llvm-$LLVMVER.src 
	cd llvm-$LLVMVER.src
	cp -av "$SRCDIR"/libunwind-$LLVMVER.src projects/libunwind
	cp -av "$SRCDIR"/libcxx-$LLVMVER.src projects/libcxx
	cp -av "$SRCDIR"/libcxxabi-$LLVMVER.src projects/libcxxabi
	mkdir -p build
	cd build
	cmake "$SRCDIR/llvm-$LLVMVER.src" \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_C_COMPILER_TARGET="$XTARGET" \
		-DCMAKE_ASM_COMPILER_TARGET="$XTARGET" \
		-DCMAKE_C_COMPILER="$TOOLS/bin/$XTARGET-clang" \
		-DCMAKE_CXX_COMPILER="$TOOLS/bin/$XTARGET-clang++" \
		-DCMAKE_AR="$TOOLS/bin/$XTARGET-ar" \
		-DCMAKE_NM="$TOOLS/bin/$XTARGET-nm" \
		-DCMAKE_RANLIB="$TOOLS/bin/$XTARGET-ranlib" \
		-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
		-DLLVM_CONFIG_PATH="$TOOLS/bin/llvm-config" \
		-DLIBCXX_CXX_ABI=libcxxabi \
		-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
		-DLIBCXX_HAS_MUSL_LIBC=ON \
		-DLIBCXX_USE_COMPILER_RT=ON \
		-DLIBCXXABI_USE_LLVM_UNWINDER=ON \
		-DLIBCXXABI_USE_COMPILER_RT=ON \
		-DLIBUNWIND_USE_COMPILER_RT=ON \
		-DLLVM_DEFAULT_TARGET_TRIPLE=$XTARGET \
		-DLLVM_TARGETS_TO_BUILD=$LTARGET \
		-Wno-dev -G Ninja

	sed -i 's/-latomic//g' build.ninja

	ninja unwind cxxabi cxx -j$(nproc)
	DESTDIR="$SYSROOT" ninja install-unwind install-cxxabi install-cxx -j$(nproc)
}

main "$1"

exit 0

