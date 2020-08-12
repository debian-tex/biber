#!/bin/bash

# This version of the build script can be run on the server hosting the VMs instead of a remote
# client

# build_master.sh <dir> <release> <branch> <justbuild> <deletescancache> <codesign>

# <dir> is where the binaries are
# <release> is a SF subdir of /home/frs/project/biblatex-biber/biblatex-biber/
# <branch> is a git branch to checkout on the build farm servers
# <justbuild> is a boolean which says to just build and stop without uploading
# <deletescancache> is a boolean which says to delete the scancache
# <codesign> is a boolean which says to not codesign OSX binary

me=$(whoami)
if [ "$me" = "root" ]; then
  echo "You should be logged on as the vbox user to do this!"
  exit 1
fi

function vmon {
  VM=$(pgrep -f -- "-startvm bbf-$1")
  if [ ! -z "$VM" ]; then
    echo "Biber build farm VM already running with PID: $VM"
  else
    nohup VBoxHeadless --startvm bbf-$1 &
  fi
}

function vmoff {
  VBoxManage controlvm bbf-$1 savestate
}

# Example: build_master.sh ~/Desktop/b development dev 1

BASE="/usr/local/data/code/biblatex-biber"
DOCDIR=$BASE/doc
DRIVERDIR=$BASE/lib/Biber/Input/
BINDIR=$BASE/dist
XSLDIR=$BASE/data
DIR=${1:-"/tmp/b"}
RELEASE=${2:-"development"}
BRANCH=${3:-"dev"}
JUSTBUILD=${4:-"0"}
DSCANCACHE=${5:-"0"}
CODESIGN=${6:-"1"}

echo "** Checking out branch '$BRANCH' on farm servers **"
echo "** If this is not correct, Ctrl-C now **"
sleep 5

# Make binary dir if it doesn't exist
if [ ! -e $DIR ]; then
  mkdir $DIR
fi

# Set scancache deletion if requested
if [ "$DSCANCACHE" = "1" ]; then
  echo "Deleting scan caches before builds";
  SCANCACHE="rm -f scancache;"
fi

# Create the binaries from the build farm if they don't exist

# Build farm OSX 64-bit intel LECAGY (10.5<version<10.13)
# ntpdate is because Vbox doesn't timesync OSX and ntp never works because the
# time difference is too great between boots
if [ ! -e $DIR/biber-darwinlegacy_x86_64.tar.gz ]; then
  vmon osx10.6
  sleep 5
  ssh philkime@bbf-osx10.6 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/darwinlegacy_x86_64;$SCANCACHE./build.sh;~/pp_osx_codesign_fix biber-darwinlegacy_x86_64;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-osx10.6:biblatex-biber/dist/darwinlegacy_x86_64/biber-darwinlegacy_x86_64 $DIR/
  ssh philkime@bbf-osx10.6 "\\rm -f biblatex-biber/dist/darwinlegacy_x86_64/biber-darwinlegacy_x86_64"
  vmoff osx10.6
  cd $DIR
  mv biber-darwinlegacy_x86_64 biber
  chmod +x biber
  tar cf biber-darwinlegacy_x86_64.tar biber
  gzip biber-darwinlegacy_x86_64.tar
  \rm biber
  cd $BASE
fi

# Build farm OSX 64-bit intel
if [ ! -e $DIR/biber-darwin_x86_64.tar.gz ]; then
  vmon osx10.12
  sleep 5
  ssh philkime@bbf-osx10.12 "cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/darwin_x86_64;$SCANCACHE./build.sh;~/pp_osx_codesign_fix biber-darwin_x86_64;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-osx10.12:biblatex-biber/dist/darwin_x86_64/biber-darwin_x86_64 $DIR/
  ssh philkime@bbf-osx10.12 "\\rm -f biblatex-biber/dist/darwin_x86_64/biber-darwin_x86_64"
  vmoff osx10.12
  cd $DIR
  if [ "$CODESIGN" = "1" ]; then
    # Special - copy biber back to local OSX to codesign and then back again
    # codesign in Xcode for osx10.12 does not have the runtime hardening options
    # --------------------------------------------------------------------------
    scp $DIR/biber-darwin_x86_64 philkime@grass:/tmp/
    ssh philkime@grass "cd /tmp;security unlock-keychain -p \$(</Users/philkime/.pw) login.keychain;codesign --sign 45MA3H23TG --force --timestamp --options runtime biber-darwin_x86_64"
    \rm $DIR/biber-darwin_x86_64
    scp philkime@grass:/tmp/biber-darwin_x86_64 $DIR/
    ssh philkime@grass "\\rm -f /tmp/biber-darwin_x86_64"
    # --------------------------------------------------------------------------
  fi
  mv biber-darwin_x86_64 biber
  chmod +x biber
  tar cf biber-darwin_x86_64.tar biber
  gzip biber-darwin_x86_64.tar
  \rm biber
  cd $BASE
fi

# Build farm WMSWIN32
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [ ! -e $DIR/biber-MSWIN32.zip ]; then
  vmon wxp32
  sleep 10
  ssh philkime@bbf-wxp32 "cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;perl Build install;cd dist/MSWIN32;$SCANCACHE./build.bat;cd ~/biblatex-biber;perl Build realclean"
  scp philkime@bbf-wxp32:biblatex-biber/dist/MSWIN32/biber-MSWIN32.exe $DIR/
  ssh philkime@bbf-wxp32 "\\rm -f biblatex-biber/dist/MSWIN32/biber-MSWIN32.exe"
  vmoff wxp32
  cd $DIR
  mv biber-MSWIN32.exe biber.exe
  chmod +x biber.exe
  /usr/bin/zip biber-MSWIN32.zip biber.exe
  \rm -f biber.exe
  cd $BASE
fi

# Build farm WMSWIN64
# DON'T FORGET THAT installdeps WON'T WORK FOR STRAWBERRY INSIDE CYGWIN
# SO YOU HAVE TO INSTALL MODULE UPDATES MANUALLY
if [ ! -e $DIR/biber-MSWIN64.zip ]; then
  vmon w1064
  sleep 10
  ssh phili@bbf-w1064 "cd biblatex-biber;git checkout $BRANCH;git pull;perl ./Build.PL;perl Build install;cd dist/MSWIN64;$SCANCACHE./build.bat;cd ~/biblatex-biber;perl Build realclean"
  scp phili@bbf-w1064:biblatex-biber/dist/MSWIN64/biber-MSWIN64.exe $DIR/
  ssh phili@bbf-w1064 "\\rm -f biblatex-biber/dist/MSWIN64/biber-MSWIN64.exe"
  vmoff w1064
  cd $DIR
  mv biber-MSWIN64.exe biber.exe
  chmod +x biber.exe
  /usr/bin/zip biber-MSWIN64.zip biber.exe
  \rm -f biber.exe
  cd $BASE
fi

# Build farm Linux 64
if [ ! -e $DIR/biber-linux_x86_64.tar.gz ]; then
  vmon l64
  sleep 10
  ssh philkime@bbf-l64 "sudo ntpdate ch.pool.ntp.org;cd biblatex-biber;git checkout $BRANCH;git pull;/usr/local/perl/bin/perl ./Build.PL;sudo ./Build installdeps;sudo ./Build install;cd dist/linux_x86_64;$SCANCACHE./build.sh;cd ~/biblatex-biber;sudo ./Build realclean"
  scp philkime@bbf-l64:biblatex-biber/dist/linux_x86_64/biber-linux_x86_64 $DIR/
  ssh philkime@bbf-l64 "\\rm -f biblatex-biber/dist/linux_x86_64/biber-linux_x86_64"
  vmoff l64
  cd $DIR
  mv biber-linux_x86_64 biber
  chmod +x biber
  tar cf biber-linux_x86_64.tar biber
  gzip biber-linux_x86_64.tar
  \rm biber
  cd $BASE
fi

# Stop here if JUSTBUILD is set
if [ "$JUSTBUILD" = "1" ]; then
  echo "JUSTBUILD is set, will not upload anything";
  exit 0;
fi

cd $DIR
# OSX 64-bit legacy
if [ -e $DIR/biber-darwinlegacy_x86_64.tar.gz ]; then
  scp biber-darwinlegacy_x86_64.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber-darwinlegacy_x86_64.tar.gz
fi

# OSX 64-bit
if [ -e $DIR/biber-darwin_x86_64.tar.gz ]; then
  scp biber-darwin_x86_64.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/OSX_Intel/biber-darwin_x86_64.tar.gz
fi

# Windows 32-bit
if [ -e $DIR/biber-MSWIN32.zip ]; then
  scp biber-MSWIN32.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber-MSWIN32.zip
fi

# Windows 64-bit
if [ -e $DIR/biber-MSWIN64.zip ]; then
  scp biber-MSWIN64.zip philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Windows/biber-MSWIN64.zip
fi

# Linux 64-bit
if [ -e $DIR/biber-linux_x86_64.tar.gz ]; then
  scp biber-linux_x86_64.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/binaries/Linux/biber-linux_x86_64.tar.gz
fi

# Doc
cd $DOCDIR
lualatex -interaction=batchmode biber.tex
lualatex -interaction=batchmode biber.tex
lualatex -interaction=batchmode biber.tex
\rm *.{aux,bbl,bcf,blg,log,run.xml,toc,out,lot,synctex} 2>/dev/null
cd $BASE
scp $DOCDIR/biber.pdf philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/documentation/biber.pdf

# Changes file
scp $BASE/Changes philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/Changes

# Unicode <-> LaTeX macro mapping doc
perl $BINDIR/xsl-transform.pl $BASE/lib/Biber/LaTeX/recode_data.xml $XSLDIR/texmap.xsl
scp $BASE/lib/Biber/LaTeX/recode_data.xml.html philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/documentation/utf8-macro-map.html
\rm -f $BASE/lib/Biber/LaTeX/recode_data.xml.html

# source
cd $BASE
./Build dist
scp $BASE/biblatex-biber-*.tar.gz philkime,biblatex-biber@frs.sourceforge.net:/home/frs/project/biblatex-biber/biblatex-biber/$RELEASE/biblatex-biber.tar.gz
\rm -f $BASE/biblatex-biber-*.tar.gz

cd $BASE
