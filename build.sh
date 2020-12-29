#!/usr/bin/env bash
#

set -e

main() {
	export MUSLVER="1.2.1"
	export LLVMVER="11.0.0"

	export LANG=C
	export LC_ALL=C
	export BUILD="$PWD/build"
	export SRCDIR="$BUILD/src"
	export TOOLS="$BUILD/tools"
	export SYSROOT="$BUILD/sysroot"
	export PATH="$TOOLS/bin:$PATH"

	rm -rvf "$BUILD"
	mkdir -pv "$SRCDIR" "$TOOLS" "$SYSROOT"

	cd "$SRCDIR"
	for i in llvm clang clang-tools-extra lld compiler-rt libunwind libcxx libcxxabi openmp; do
		curl -C - -L -O https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVMVER/$i-$LLVMVER.src.tar.xz
		bsdtar -xvf $i-$LLVMVER.src.tar.xz
	done

	curl -C - -L -O https://musl.libc.org/releases/musl-$MUSLVER.tar.gz
	bsdtar -xvf musl-$MUSLVER.tar.gz

	cd "$SRCDIR"/llvm-$LLVMVER.src
	cp -av "$SRCDIR"/clang-$LLVMVER.src tools/clang
	cp -av "$SRCDIR"/clang-tools-extra-$LLVMVER.src tools/clang/tools/extra
	cp -av "$SRCDIR"/lld-$LLVMVER.src tools/lld
	cp -av "$SRCDIR"/compiler-rt-$LLVMVER.src projects/compiler-rt
	cp -av "$SRCDIR"/libunwind-$LLVMVER.src projects/libunwind
	mkdir -p build
	cd build
	cmake "$SRCDIR/llvm-$LLVMVER.src" \
		-DCMAKE_C_COMPILER=clang \
		-DCMAKE_CXX_COMPILER=clang++ \
		-DCMAKE_INSTALL_PREFIX="$TOOLS" \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCLANG_BUILD_EXAMPLES=OFF \
		-DCLANG_DEFAULT_LINKER=lld \
		-DCLANG_DEFAULT_RTLIB=compiler-rt \
		-DCLANG_DEFAULT_UNWINDLIB=libunwind \
		-DCLANG_INCLUDE_DOCS=OFF \
		-DCLANG_INCLUDE_TESTS=OFF \
		-DCLANG_PLUGIN_SUPPORT=ON \
		-DCOMPILER_RT_BUILD_BUILTINS=ON \
		-DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
		-DCOMPILER_RT_BUILD_PROFILE=OFF \
		-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DLIBUNWIND_USE_COMPILER_RT=ON \
		-DLLVM_BUILD_EXAMPLES=OFF \
		-DLLVM_BUILD_DOCS=OFF \
		-DLLVM_BUILD_TESTS=OFF \
		-DLLVM_TARGET_ARCH=Mips \
		-DLLVM_TARGETS_TO_BUILD=Mips \
		-DLLVM_DEFAULT_TARGET_TRIPLE=mipsel-linux-musl \
		-DDEFAULT_SYSROOT="$SYSROOT" \
		-Wno-dev -G Ninja
	ninja -j$(nproc)
	ninja install -j$(nproc)

	local realclang="$(readlink $TOOLS/bin/clang)"

	pushd "$TOOLS/bin"
		for i in cc c++ clang clang++ cpp; do
			cp -v $realclang mipsel-linux-musl-$i
		done

		for i in ar as dwp nm objcopy objdump size strings; do
			cp -v llvm-$i mipsel-linux-musl-$i
		done

		cp -v lld mipsel-linux-musl-ld
		cp -v lld mipsel-linux-musl-ld.lld
		cp -v llvm-symbolizer mipsel-linux-musl-addr2line
		cp -v llvm-cxxfilt mipsel-linux-musl-c++filt
		cp -v llvm-ar mipsel-linux-musl-ranlib
		cp -v llvm-readobj mipsel-linux-musl-readelf
		cp -v llvm-objcopy mipsel-linux-musl-strip

		rm -fv $realclang clang clang++ clang-cl clang-cpp \
			lld-link ld.lld ld64.lld wasm-ld lld
	popd

	cd "$SRCDIR"/musl-$MUSLVER
	make ARCH=mips prefix=/usr DESTDIR="$SYSROOT" install-headers

	cd "$SRCDIR"
	mkdir compiler-rt-builtins-build
	cd compiler-rt-builtins-build
	cmake ../compiler-rt-$LLVMVER.src \
		-DCMAKE_C_COMPILER_TARGET="mipsel-linux-musl" \
		-DCMAKE_ASM_COMPILER_TARGET="mipsel-linux-musl" \
		-DCMAKE_C_COMPILER="$TOOLS/bin/mipsel-linux-musl-clang" \
		-DCMAKE_CXX_COMPILER="$TOOLS/bin/mipsel-linux-musl-clang++" \
		-DCMAKE_AR="$TOOLS/bin/mipsel-linux-musl-ar" \
		-DCMAKE_NM="$TOOLS/bin/mipsel-linux-musl-nm" \
		-DCMAKE_RANLIB="$TOOLS/bin/mipsel-linux-musl-ranlib" \
		-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
		-DLLVM_CONFIG_PATH="$TOOLS/bin/llvm-config" \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
		-DCOMPILER_RT_BUILD_BUILTINS=ON \
		-DCOMPILER_RT_BUILD_SANITIZERS=OFF \
		-DCOMPILER_RT_BUILD_XRAY=OFF \
		-DCOMPILER_RT_INCLUDE_TESTS=OFF \
		-Wno-dev -G Ninja
	ninja
	for i in lib/linux/*; do
		install -Dm644 "$i" "$TOOLS"/lib/clang/$LLVMVER/lib/linux/$(basename $i)
	done

	cd "$SRCDIR"/musl-$MUSLVER
	./configure \
		--build=$(clang -dumpmachine) \
		--host=mipsel-linux-musl \
		--target=mipsel-linux-musl \
		--prefix=/usr \
		--libdir=/usr/lib \
		--syslibdir=/usr/lib \
		--enable-optimize=size \
		LIBCC="$(mipsel-linux-musl-clang -print-libgcc-file-name)"
	make -j9
	make DESTDIR="$SYSROOT" install -j9
}

main

exit 0

