#
# Make the avr-Xinu configuration program, config
#

ARCH	=	x86_64
DEVELOPER_BIN = /Applications/Xcode.app/Contents/Developer/usr/bin
TOOLCHAIN_BIN = /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin

CC		=	$(DEVELOPER_BIN)/gcc

CFLAGS	=	-x c -arch $(ARCH) -fmessage-length=0 -pipe -std=gnu99 -Wno-trigraphs\
-fpascal-strings -fasm-blocks -Os -mdynamic-no-pic\
-Wreturn-type -Wunused-variable

INCLUDE = /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include

LDFLAGS =	-arch $(ARCH) -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk


LEX    = $(TOOLCHAIN_BIN)/flex
YACC   = $(TOOLCHAIN_BIN)/bison -y	# -y Flag enables yacc-compatible filenames

LFLAGS = -lfl		# libfl.a -> flex library
#
# the flex library should be found in {sysroot}/usr/lib
# But, Apple left the library out of MacOSX10.8.sdk and MacOSX10.9.sdk
# You may have to copy libfl.a from an older SDKs/MacOSX10.6.sdk/usr/lib
#

CONFIG = config

all: ${CONFIG}

${CONFIG}.yy.o:	y.tab.c lex.yy.c
	$(CC) $(CFLAGS) -I${INCLUDE} -c y.tab.c -o ${CONFIG}.yy.o

${CONFIG}: ${CONFIG}.yy.o
	$(CC) ${LDFLAGS} -o $@ ${CONFIG}.yy.o ${LFLAGS}
	cp $(CONFIG) ..

lex.yy.c: config.l
	$(LEX) config.l

y.tab.c: config.y
	$(YACC) config.y

clean:
	rm -f ${CONFIG} lex.yy.c y.tab.c ${CONFIG}.yy.o
	
#
# run the Xinu configuration program, config.
#   output: conf.h, conf.c, and confisr.c
#   input:	./Configuration
#

	
install:
	cp ./${CONFIG} ..
