;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2015, 2016, 2017 Ricardo Wurmus <rekado@elephly.net>
;;; Copyright © 2016 Leo Famulari <leo@famulari.name>
;;; Copyright © 2016, 2017 Roel Janssen <roel@gnu.org>
;;; Copyright © 2017 Carlo Zancanaro <carlo@zancanaro.id.au>
;;;
;;; GNU Guix is free software; you can redistribute it and/or modify it
;;; under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 3 of the License, or (at
;;; your option) any later version.
;;;
;;; GNU Guix is distributed in the hope that it will be useful, but
;;; WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Guix.  If not, see <http://www.gnu.org/licenses/>.

(define-module (umcu packages java)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix utils)
  #:use-module (guix build-system ant)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages)
  #:use-module (gnu packages attr)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages certs)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages cups)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages gl)
  #:use-module (gnu packages gnuzilla) ;nss
  #:use-module (gnu packages ghostscript) ;lcms
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gtk)
  #:use-module (gnu packages image)
  #:use-module (gnu packages linux) ;alsa
  #:use-module (gnu packages wget)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages kerberos)
  #:use-module (gnu packages xml)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages zip)
  #:use-module (gnu packages texinfo)
  #:use-module ((srfi srfi-1) #:select (fold alist-delete))
  #:use-module (srfi srfi-11)
  #:use-module (ice-9 match))

(define-public icedtea-6
  (package
    (name "icedtea")
    (version "1.13.13")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "http://icedtea.wildebeest.org/download/source/icedtea6-"
                    version ".tar.xz"))
              (sha256
               (base32
                "0bg9sb4f7qbq77c0zf9m17p47ga0kf0r9622g9p12ysg26jd1ksg"))
              (modules '((guix build utils)))
              (snippet
               '(substitute* "Makefile.in"
                  ;; link against libgcj to avoid linker error
                  (("-o native-ecj")
                   "-lgcj -o native-ecj")
                  ;; do not leak information about the build host
                  (("DISTRIBUTION_ID=\"\\$\\(DIST_ID\\)\"")
                   "DISTRIBUTION_ID=\"\\\"guix\\\"\"")))))
    (build-system gnu-build-system)
    (outputs '("out"   ; Java Runtime Environment
               "jdk"   ; Java Development Kit
               "doc")) ; all documentation
    (arguments
     `(;; There are many failing tests and many are known to fail upstream.
       ;;
       ;; * Hotspot VM tests:
       ;;   FAILED: compiler/7082949/Test7082949.java
       ;;   FAILED: compiler/7088020/Test7088020.java
       ;;   FAILED: runtime/6929067/Test6929067.sh
       ;;   FAILED: serviceability/sa/jmap-hashcode/Test8028623.java
       ;;   => Test results: passed: 161; failed: 4
       ;;
       ;; * langtools tests:
       ;;   FAILED: com/sun/javadoc/testHtmlDefinitionListTag/TestHtmlDefinitionListTag.java
       ;;   FAILED: tools/javac/6627362/T6627362.java
       ;;   FAILED: tools/javac/7003595/T7003595.java
       ;;   FAILED: tools/javac/7024568/T7024568.java
       ;;   FAILED: tools/javap/4111861/T4111861.java
       ;;   FAILED: tools/javap/ListTest.java
       ;;   FAILED: tools/javap/OptionTest.java
       ;;   FAILED: tools/javap/T4884240.java
       ;;   FAILED: tools/javap/T4975569.java
       ;;     --> fails because of insignificant whitespace differences
       ;;         in output of javap
       ;;   FAILED: tools/javap/T6868539.java
       ;;   => Test results: passed: 1,445; failed: 10
       ;;
       ;; * JDK tests:
       ;;   Tests are incomplete because of a segfault after this test:
       ;;     javax/crypto/spec/RC5ParameterSpec/RC5ParameterSpecEquals.java
       ;;   A bug report has already been filed upstream:
       ;;     http://icedtea.classpath.org/bugzilla/show_bug.cgi?id=2188
       ;;
       ;;   The tests require xvfb-run, a wrapper script around Xvfb, which
       ;;   has not been packaged yet.  Without it many AWT tests fail, so I
       ;;   made no attempts to make a list of failing JDK tests.  At least
       ;;   222 tests are failing of which at least 132 are AWT tests.
       #:tests? #f

       ;; The DSOs use $ORIGIN to refer to each other, but (guix build
       ;; gremlin) doesn't support it yet, so skip this phase.
       #:validate-runpath? #f

       #:modules ((guix build utils)
                  (guix build gnu-build-system)
                  (ice-9 popen)
                  (ice-9 rdelim)
                  (srfi srfi-19))

       #:configure-flags
       (let* ((gcjdir (assoc-ref %build-inputs "gcj"))
              (ecj    (string-append gcjdir "/share/java/ecj.jar"))
              (jdk    (string-append gcjdir "/lib/jvm/"))
              (gcj    (string-append gcjdir "/bin/gcj")))
         `("--enable-bootstrap"
           "--enable-nss"
           "--without-rhino"
           "--disable-downloading"
           "--disable-tests" ;they are run in the check phase instead
           "--with-openjdk-src-dir=./openjdk.src"
           ,(string-append "--with-javac=" jdk "/bin/javac")
           ,(string-append "--with-ecj-jar=" ecj)
           ,(string-append "--with-gcj=" gcj)
           ,(string-append "--with-jdk-home=" jdk)
           ,(string-append "--with-java=" jdk "/bin/java")))
       #:phases
       (modify-phases %standard-phases
         (replace 'unpack
           (lambda* (#:key source inputs #:allow-other-keys)
             (and (zero? (system* "tar" "xvf" source))
                  (begin
                    (chdir (string-append "icedtea6-" ,version))
                    (mkdir "openjdk.src")
                    (with-directory-excursion "openjdk.src"
                      (copy-file (assoc-ref inputs "openjdk6-src")
                                 "openjdk6-src.tar.xz")
                      (zero? (system* "tar" "xvf" "openjdk6-src.tar.xz")))))))
         (add-after 'unpack 'patch-patches
           (lambda _
             ;; shebang in patches so that they apply cleanly
             (substitute* '("patches/jtreg-jrunscript.patch"
                            "patches/hotspot/hs23/drop_unlicensed_test.patch")
               (("#!/bin/sh") (string-append "#!" (which "sh"))))
             #t))
         (add-after 'unpack 'patch-paths
           (lambda _
             ;; buildtree.make generates shell scripts, so we need to replace
             ;; the generated shebang
             (substitute* '("openjdk.src/hotspot/make/linux/makefiles/buildtree.make")
               (("/bin/sh") (which "bash")))

             (let ((corebin (string-append
                             (assoc-ref %build-inputs "coreutils") "/bin/"))
                   (binbin  (string-append
                             (assoc-ref %build-inputs "binutils") "/bin/"))
                   (grepbin (string-append
                             (assoc-ref %build-inputs "grep") "/bin/")))
               (substitute* '("openjdk.src/jdk/make/common/shared/Defs-linux.gmk"
                              "openjdk.src/corba/make/common/shared/Defs-linux.gmk")
                 (("UNIXCOMMAND_PATH  = /bin/")
                  (string-append "UNIXCOMMAND_PATH = " corebin))
                 (("USRBIN_PATH  = /usr/bin/")
                  (string-append "USRBIN_PATH = " corebin))
                 (("DEVTOOLS_PATH *= */usr/bin/")
                  (string-append "DEVTOOLS_PATH = " corebin))
                 (("COMPILER_PATH *= */usr/bin/")
                  (string-append "COMPILER_PATH = "
                                 (assoc-ref %build-inputs "gcc") "/bin/"))
                 (("DEF_OBJCOPY *=.*objcopy")
                  (string-append "DEF_OBJCOPY = " (which "objcopy"))))

               ;; fix path to alsa header
               (substitute* "openjdk.src/jdk/make/common/shared/Sanity.gmk"
                 (("ALSA_INCLUDE=/usr/include/alsa/version.h")
                  (string-append "ALSA_INCLUDE="
                                 (assoc-ref %build-inputs "alsa-lib")
                                 "/include/alsa/version.h")))

               ;; fix hard-coded utility paths
               (substitute* '("openjdk.src/jdk/make/common/shared/Defs-utils.gmk"
                              "openjdk.src/corba/make/common/shared/Defs-utils.gmk")
                 (("ECHO *=.*echo")
                  (string-append "ECHO = " (which "echo")))
                 (("^GREP *=.*grep")
                  (string-append "GREP = " (which "grep")))
                 (("EGREP *=.*egrep")
                  (string-append "EGREP = " (which "egrep")))
                 (("CPIO *=.*cpio")
                  (string-append "CPIO = " (which "cpio")))
                 (("READELF *=.*readelf")
                  (string-append "READELF = " (which "readelf")))
                 (("^ *AR *=.*ar")
                  (string-append "AR = " (which "ar")))
                 (("^ *TAR *=.*tar")
                  (string-append "TAR = " (which "tar")))
                 (("AS *=.*as")
                  (string-append "AS = " (which "as")))
                 (("LD *=.*ld")
                  (string-append "LD = " (which "ld")))
                 (("STRIP *=.*strip")
                  (string-append "STRIP = " (which "strip")))
                 (("NM *=.*nm")
                  (string-append "NM = " (which "nm")))
                 (("^SH *=.*sh")
                  (string-append "SH = " (which "bash")))
                 (("^FIND *=.*find")
                  (string-append "FIND = " (which "find")))
                 (("LDD *=.*ldd")
                  (string-append "LDD = " (which "ldd")))
                 (("NAWK *=.*(n|g)awk")
                  (string-append "NAWK = " (which "gawk")))
                 (("XARGS *=.*xargs")
                  (string-append "XARGS = " (which "xargs")))
                 (("UNZIP *=.*unzip")
                  (string-append "UNZIP = " (which "unzip")))
                 (("ZIPEXE *=.*zip")
                  (string-append "ZIPEXE = " (which "zip")))
                 (("SED *=.*sed")
                  (string-append "SED = " (which "sed"))))

               ;; Some of these timestamps cause problems as they are more than
               ;; 10 years ago, failing the build process.
               (substitute*
                   "openjdk.src/jdk/src/share/classes/java/util/CurrencyData.properties"
                 (("AZ=AZM;2005-12-31-20-00-00;AZN") "AZ=AZN")
                 (("MZ=MZM;2006-06-30-22-00-00;MZN") "MZ=MZN")
                 (("RO=ROL;2005-06-30-21-00-00;RON") "RO=RON")
                 (("TR=TRL;2004-12-31-22-00-00;TRY") "TR=TRY")))))
         (add-before 'configure 'set-additional-paths
           (lambda* (#:key inputs #:allow-other-keys)
             (let* ((gcjdir  (assoc-ref %build-inputs "gcj"))
                    (gcjlib  (string-append gcjdir "/lib"))
                    ;; Get target-specific include directory so that
                    ;; libgcj-config.h is found when compiling hotspot.
                    (gcjinclude (let* ((port (open-input-pipe "gcj -print-file-name=include"))
                                       (str  (read-line port)))
                                  (close-pipe port)
                                  str)))
               (setenv "CPATH"
                       (string-append gcjinclude ":"
                                      (assoc-ref %build-inputs "libxrender")
                                      "/include/X11/extensions" ":"
                                      (assoc-ref %build-inputs "libxtst")
                                      "/include/X11/extensions" ":"
                                      (assoc-ref %build-inputs "libxinerama")
                                      "/include/X11/extensions" ":"
                                      (or (getenv "CPATH") "")))
               (setenv "ALT_CUPS_HEADERS_PATH"
                       (string-append (assoc-ref %build-inputs "cups")
                                      "/include"))
               (setenv "ALT_FREETYPE_HEADERS_PATH"
                       (string-append (assoc-ref %build-inputs "freetype")
                                      "/include"))
               (setenv "ALT_FREETYPE_LIB_PATH"
                       (string-append (assoc-ref %build-inputs "freetype")
                                      "/lib")))))
         (add-before 'check 'fix-test-framework
           (lambda _
             ;; Fix PATH in test environment
             (substitute* "src/jtreg/com/sun/javatest/regtest/Main.java"
               (("PATH=/bin:/usr/bin")
                (string-append "PATH=" (getenv "PATH"))))
             (substitute* "src/jtreg/com/sun/javatest/util/SysEnv.java"
               (("/usr/bin/env") (which "env")))
             #t))
         (add-before 'check 'fix-hotspot-tests
           (lambda _
             (with-directory-excursion "openjdk.src/hotspot/test/"
               (substitute* "jprt.config"
                 (("PATH=\"\\$\\{path4sdk\\}\"")
                  (string-append "PATH=" (getenv "PATH")))
                 (("make=/usr/bin/make")
                  (string-append "make=" (which "make"))))
               (substitute* '("runtime/6626217/Test6626217.sh"
                              "runtime/7110720/Test7110720.sh")
                 (("/bin/rm") (which "rm"))
                 (("/bin/cp") (which "cp"))
                 (("/bin/mv") (which "mv"))))
             #t))
         (add-before 'check 'fix-jdk-tests
           (lambda _
             (with-directory-excursion "openjdk.src/jdk/test/"
               (substitute* "com/sun/jdi/JdbReadTwiceTest.sh"
                 (("/bin/pwd") (which "pwd")))
               (substitute* "com/sun/jdi/ShellScaffold.sh"
                 (("/bin/kill") (which "kill")))
               (substitute* "start-Xvfb.sh"
                 ;;(("/usr/bin/X11/Xvfb") (which "Xvfb"))
                 (("/usr/bin/nohup")    (which "nohup")))
               (substitute* "javax/security/auth/Subject/doAs/Test.sh"
                 (("/bin/rm") (which "rm")))
               (substitute* "tools/launcher/MultipleJRE.sh"
                 (("echo \"#!/bin/sh\"")
                  (string-append "echo \"#!" (which "rm") "\""))
                 (("/usr/bin/zip") (which "zip")))
               (substitute* "com/sun/jdi/OnThrowTest.java"
                 (("#!/bin/sh") (string-append "#!" (which "sh"))))
               (substitute* "java/lang/management/OperatingSystemMXBean/GetSystemLoadAverage.java"
                 (("/usr/bin/uptime") (which "uptime")))
               (substitute* "java/lang/ProcessBuilder/Basic.java"
                 (("/usr/bin/env") (which "env"))
                 (("/bin/false") (which "false"))
                 (("/bin/true") (which "true"))
                 (("/bin/cp") (which "cp"))
                 (("/bin/sh") (which "sh")))
               (substitute* "java/lang/ProcessBuilder/FeelingLucky.java"
                 (("/bin/sh") (which "sh")))
               (substitute* "java/lang/ProcessBuilder/Zombies.java"
                 (("/usr/bin/perl") (which "perl"))
                 (("/bin/ps") (which "ps"))
                 (("/bin/true") (which "true")))
               (substitute* "java/lang/Runtime/exec/ConcurrentRead.java"
                 (("/usr/bin/tee") (which "tee")))
               (substitute* "java/lang/Runtime/exec/ExecWithDir.java"
                 (("/bin/true") (which "true")))
               (substitute* "java/lang/Runtime/exec/ExecWithInput.java"
                 (("/bin/cat") (which "cat")))
               (substitute* "java/lang/Runtime/exec/ExitValue.java"
                 (("/bin/sh") (which "sh"))
                 (("/bin/true") (which "true"))
                 (("/bin/kill") (which "kill")))
               (substitute* "java/lang/Runtime/exec/LotsOfDestroys.java"
                 (("/usr/bin/echo") (which "echo")))
               (substitute* "java/lang/Runtime/exec/LotsOfOutput.java"
                 (("/usr/bin/cat") (which "cat")))
               (substitute* "java/lang/Runtime/exec/SleepyCat.java"
                 (("/bin/cat") (which "cat"))
                 (("/bin/sleep") (which "sleep"))
                 (("/bin/sh") (which "sh")))
               (substitute* "java/lang/Runtime/exec/StreamsSurviveDestroy.java"
                 (("/bin/cat") (which "cat")))
               (substitute* "java/rmi/activation/CommandEnvironment/SetChildEnv.java"
                 (("/bin/chmod") (which "chmod")))
               (substitute* "java/util/zip/ZipFile/Assortment.java"
                 (("/bin/sh") (which "sh"))))
             #t))
         (replace 'check
           (lambda _
             ;; The "make check-*" targets always return zero, so we need to
             ;; check for errors in the associated log files to determine
             ;; whether any tests have failed.
             (use-modules (ice-9 rdelim))
             (let* ((error-pattern (make-regexp "^(Error|FAILED):.*"))
                    (checker (lambda (port)
                               (let loop ()
                                 (let ((line (read-line port)))
                                   (cond
                                    ((eof-object? line) #t)
                                    ((regexp-exec error-pattern line) #f)
                                    (else (loop)))))))
                    (run-test (lambda (test)
                                (system* "make" test)
                                (call-with-input-file
                                    (string-append "test/" test ".log")
                                  checker))))
               (or #t ; skip tests
                   (and (run-test "check-hotspot")
                        (run-test "check-langtools")
                        (run-test "check-jdk"))))))
         (replace 'install
           (lambda* (#:key outputs #:allow-other-keys)
             (let ((doc (string-append (assoc-ref outputs "doc")
                                       "/share/doc/icedtea"))
                   (jre (assoc-ref outputs "out"))
                   (jdk (assoc-ref outputs "jdk")))
               (copy-recursively "openjdk.build/docs" doc)
               (copy-recursively "openjdk.build/j2re-image" jre)
               (copy-recursively "openjdk.build/j2sdk-image" jdk))))
         ;; By default IcedTea only generates an empty keystore.  In order to
         ;; be able to use certificates in Java programs we need to generate a
         ;; keystore from a set of certificates.  For convenience we use the
         ;; certificates from the nss-certs package.
         (add-after 'install 'install-keystore
           (lambda* (#:key inputs outputs #:allow-other-keys)
             (let* ((keystore  "cacerts")
                    (certs-dir (string-append (assoc-ref inputs "nss-certs")
                                              "/etc/ssl/certs"))
                    (keytool   (string-append (assoc-ref outputs "jdk")
                                              "/bin/keytool")))
               (define (extract-cert file target)
                 (call-with-input-file file
                   (lambda (in)
                     (call-with-output-file target
                       (lambda (out)
                         (let loop ((line (read-line in 'concat))
                                    (copying? #f))
                           (cond
                            ((eof-object? line) #t)
                            ((string-prefix? "-----BEGIN" line)
                             (display line out)
                             (loop (read-line in 'concat) #t))
                            ((string-prefix? "-----END" line)
                             (display line out)
                             #t)
                            (else
                             (when copying? (display line out))
                             (loop (read-line in 'concat) copying?)))))))))
               (define (import-cert cert)
                 (format #t "Importing certificate ~a\n" (basename cert))
                 (let ((temp "tmpcert"))
                   (extract-cert cert temp)
                   (let ((port (open-pipe* OPEN_WRITE keytool
                                           "-import"
                                           "-alias" (basename cert)
                                           "-keystore" keystore
                                           "-storepass" "changeit"
                                           "-file" temp)))
                     (display "yes\n" port)
                     (when (not (zero? (status:exit-val (close-pipe port))))
                       (format #t "failed to import ~a\n" cert)))
                   (delete-file temp)))

               ;; This is necessary because the certificate directory contains
               ;; files with non-ASCII characters in their names.
               (setlocale LC_ALL "en_US.utf8")
               (setenv "LC_ALL" "en_US.utf8")

               (for-each import-cert (find-files certs-dir "\\.pem$"))
               (mkdir-p (string-append (assoc-ref outputs "out")
                                       "/lib/security"))
               (mkdir-p (string-append (assoc-ref outputs "jdk")
                                       "/jre/lib/security"))

               ;; The cacerts files we are going to overwrite are chmod'ed as
               ;; read-only (444) in icedtea-8 (which derives from this
               ;; package).  We have to change this so we can overwrite them.
               (chmod (string-append (assoc-ref outputs "out")
                                     "/lib/security/" keystore) #o644)
               (chmod (string-append (assoc-ref outputs "jdk")
                                     "/jre/lib/security/" keystore) #o644)

               (install-file keystore
                             (string-append (assoc-ref outputs "out")
                                            "/lib/security"))
               (install-file keystore
                             (string-append (assoc-ref outputs "jdk")
                                            "/jre/lib/security"))
               #t))))))
    (native-inputs
     `(("ant" ,ant)
       ("alsa-lib" ,alsa-lib)
       ("attr" ,attr)
       ("autoconf" ,autoconf)
       ("automake" ,automake)
       ("coreutils" ,coreutils)
       ("diffutils" ,diffutils) ;for tests
       ("gawk" ,gawk)
       ("grep" ,grep)
       ("libtool" ,libtool)
       ("pkg-config" ,pkg-config)
       ("cups" ,cups)
       ("wget" ,wget)
       ("which" ,which)
       ("cpio" ,cpio)
       ("zip" ,zip)
       ("unzip" ,unzip)
       ("fastjar" ,fastjar)
       ("libxslt" ,libxslt) ;for xsltproc
       ("mit-krb5" ,mit-krb5)
       ("nss" ,nss)
       ("nss-certs" ,nss-certs)
       ("libx11" ,libx11)
       ("libxcomposite" ,libxcomposite)
       ("libxt" ,libxt)
       ("libxtst" ,libxtst)
       ("libxi" ,libxi)
       ("libxinerama" ,libxinerama)
       ("libxrender" ,libxrender)
       ("libjpeg" ,libjpeg)
       ("libpng" ,libpng)
       ("giflib" ,giflib)
       ("perl" ,perl)
       ("procps" ,procps) ;for "free", even though I'm not sure we should use it
       ("openjdk6-src"
        ,(origin
           (method url-fetch)
           (uri "https://java.net/downloads/openjdk6/openjdk-6-src-b41-04_jan_2017.tar.xz")
           (sha256
            (base32
             "058szix0j280g14jzajvsixx1j2dxmc10r848f5swpy6rr8x8d4f"))))
       ("lcms" ,lcms)
       ("zlib" ,zlib)
       ("gtk" ,gtk+-2)
       ("fontconfig" ,fontconfig)
       ("freetype" ,freetype)
       ("gcj" ,gcj)))
    (home-page "http://icedtea.classpath.org")
    (synopsis "Java development kit")
    (description
     "The OpenJDK built with the IcedTea build harness.")
    ;; IcedTea is released under the GPL2 + Classpath exception, which is the
    ;; same license as both GNU Classpath and OpenJDK.
    (license license:gpl2+)))
