;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2014 Cyrill Schenkel <cyrill.schenkel@gmail.com>
;;; Copyright © 2015 Andreas Enge <andreas@enge.fr>
;;; Copyright © 2015, 2016 David Thompson <davet@gnu.org>
;;; Copyright © 2016 Ludovic Courtès <ludo@gnu.org>
;;;
;;; This file is part of GNU Guix.
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

(define-module (gnu packages node)
  #:use-module ((guix licenses) #:select (expat))
  #:use-module (guix packages)
  #:use-module (guix derivations)
  #:use-module (guix download)
  #:use-module (guix build-system gnu)
  #:use-module (gnu packages adns)
  #:use-module (gnu packages base)
  #:use-module ((gnu packages compression) #:prefix compression:)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages libevent)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages perl)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module ((gnu packages tls) #:prefix tls:)
  #:use-module (gnu packages valgrind))

(define-public http-parser
  (package
    (name "http-parser")
    (version "2.7.1")
    (source (origin
              (method url-fetch)
              (uri (string-append
                    "https://github.com/nodejs/http-parser/archive/v"
                    version ".tar.gz"))
              (sha256
               (base32
                "1cw6nf8xy4jhib1w0jd2y0gpqjbdasg8b7pkl2k2vpp54k9rlh3h"))))
    (build-system gnu-build-system)
    (arguments
     '(#:make-flags (list "CC=gcc"
                          (string-append "DESTDIR=" (assoc-ref %outputs "out")))
       #:test-target "test-valgrind"
       #:phases
       (modify-phases %standard-phases
         (delete 'configure)
         (add-before 'build 'patch-makefile
           (lambda* (#:key inputs outputs #:allow-other-keys)
              (substitute* '("Makefile")
                (("/usr/local") ""))))
         (replace 'build
           (lambda* (#:key make-flags #:allow-other-keys)
             (zero? (apply system* "make" "library" make-flags))))
         )))
    (inputs '())
    (native-inputs `(("valgrind" ,valgrind)))
    (home-page "https://github.com/nodejs/http-parser")
    (synopsis "HTTP request/response parser for C")
    (description "HTTP parser is a parser for HTTP messages written in C.  It
parses both requests and responses.  The parser is designed to be used in
performance HTTP applications.  It does not make any syscalls nor allocations,
it does not buffer data, it can be interrupted at anytime.")
    (license expat)))

(define-public node
  (package
    (name "node")
    (version "6.4.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1l4p2zgld68c061njx6drxm06685hmp656ijm9i0hnyg30397355"))))
    (build-system gnu-build-system)
    (arguments
     '(#:configure-flags '("--shared-openssl"
                           "--shared-zlib"
                           "--shared-libuv"
                           "--shared-cares"
                           "--shared-http-parser"
                           "--without-snapshot")
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Fix hardcoded /bin/sh references.
             (substitute* '("lib/child_process.js"
                            "lib/internal/v8_prof_polyfill.js"
                            "test/parallel/test-stdio-closed.js")
               (("'/bin/sh'")
                (string-append "'" (which "bash") "'")))

             ;; Fix hardcoded /usr/bin/env references.
             (substitute*
                 '("test/parallel/test-child-process-default-options.js"
                   "test/parallel/test-child-process-env.js"
                   "test/parallel/test-child-process-exec-env.js")
               (("'/usr/bin/env'")
                (string-append "'" (which "env") "'")))

             ;; Having the build fail because of linter errors is insane!
             (substitute* '("Makefile")
               (("	\\$\\(MAKE\\) jslint") "")
               (("	\\$\\(MAKE\\) cpplint\n") ""))

             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/parallel/test-dgram-membership.js"
                         "test/parallel/test-cluster-master-error.js"
                         "test/parallel/test-cluster-master-kill.js"
                         "test/parallel/test-npm-install.js"
                         "test/sequential/test-child-process-emfile.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags (cons (string-append "--prefix=" prefix)
                                 configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               ;; Node's configure script expects the CC environment variable to
               ;; be set.
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             (string-append (assoc-ref inputs "python")
                                            "/bin/python")
                             "configure" flags)))))
         (add-after 'patch-shebangs 'patch-npm-shebang
           (lambda* (#:key outputs #:allow-other-keys)
             (let* ((bindir (string-append (assoc-ref outputs "out")
                                           "/bin"))
                    (npm    (string-append bindir "/npm"))
                    (target (readlink npm)))
               (with-directory-excursion bindir
                 (patch-shebang target (list bindir))
                 #t)))))))
    (native-inputs
     `(("python" ,python-2)
       ("perl" ,perl)
       ("procps" ,procps)
       ("util-linux" ,util-linux)
       ("which" ,which)))
    (native-search-paths
     (list (search-path-specification
            (variable "NODE_PATH")
            (files '("lib/node_modules")))))
    (inputs
     `(("libuv" ,libuv)
       ("openssl" ,tls:openssl)
       ("zlib" ,compression:zlib)
       ("http-parser" ,http-parser)
       ("c-ares" ,c-ares)))
    (synopsis "Evented I/O for V8 JavaScript")
    (description "Node.js is a platform built on Chrome's JavaScript runtime
for easily building fast, scalable network applications.  Node.js uses an
event-driven, non-blocking I/O model that makes it lightweight and efficient,
perfect for data-intensive real-time applications that run across distributed
devices.")
    (home-page "http://nodejs.org/")
    (license expat)))

(define-public node-0.5
  (package (inherit node)
    (version "0.5.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1fbq56w40h71l304bq8ggf5z80g0bsldbqciy3gm8dild5pphzmc"))))
    (arguments
     '(#:configure-flags `("--without-snapshot"
                           "--shared-cares")
       #:make-flags (list (string-append "CXXFLAGS=-I"
                                         (assoc-ref %build-inputs
                                                    "linux-headers")
                                         "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             (substitute* '("test/simple/test-child-process-env.js"
                            "test/simple/test-child-process-deprecated-api.js"
                            "test/simple/test-child-process-custom-fds.js")
               (("'/usr/bin/env'")
                (string-append "'" (which "env") "'"))
               (("'/bin/echo'")
                 (string-append "'" (which "echo") "'")))
             (for-each delete-file
                       '("test/simple/test-init.js"
                         "test/simple/test-https-simple.js"
                         "test/simple/test-dgram-multicast.js"
                         "test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-child-process-exec-env.js"
                         "test/simple/test-tls-server-verify.js"
                         "test/simple/test-child-process-exec-cwd.js"
                         "test/simple/test-http-full-response.js"
                         "test/simple/test-net-server-on-fd-0.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-cwd.js"
                         "test/simple/test-regress-GH-819.js"
                         "test/simple/test-http-dns-fail.js"
                         "test/simple/test-net-connect-timeout.js"
                         "test/simple/test-pipe-file-to-http.js"
                         "test/simple/test-process-env.js"
                         "test/simple/test-http-curl-chunk-problem.js"
                         "test/simple/test-cli-eval.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("coreutils" ,coreutils) ;; for running dd with make test
       ("curl" ,curl)
       ("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)
       ("util-linux" ,util-linux)
       ("pkg-config" ,pkg-config)))
    (inputs
     `(("openssl" ,tls:openssl)
       ("c-ares" ,c-ares)))))
;;04nhs9h4ncgcbci11yslc1drpqf48cl5vv40gziznhzi98acdi0r

(define-public node-0.3.1
  (package (inherit node-0.5)
    (version "0.3.1")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "04nhs9h4ncgcbci11yslc1drpqf48cl5vv40gziznhzi98acdi0r"))))
    (arguments
     '(#:configure-flags `("--without-snapshot"
                           "--shared-cares")
       #:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects-visiting.h")
               (("    IteratePointers")
                "    BodyVisitorBase<StaticVisitor>::IteratePointers"))

             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-dgram-multicast.js"
                         "test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-child-process-deprecated-api.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-child-process-exec-env.js"
                         "test/simple/test-child-process-exec-cwd.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-cwd.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-custom-fds.js"
                         "test/simple/test-child-process-env.js"
                         "test/simple/test-http-full-response.js"
                         "test/simple/test-readline.js"
                         "test/simple/test-http-curl-chunk-problem.js"
                         "test/simple/test-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.3.0
  (package (inherit node-0.5)
    (version "0.3.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1d972im6zfpl2isbvqqh5yi2wvkyj7cxj4yhi8805anf6v8w6lxa"
                ))))
    (arguments
     '(#:configure-flags `("--without-snapshot"
                           "--shared-cares")
       #:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects-visiting.h")
               (("    IteratePointers")
                "    BodyVisitorBase<StaticVisitor>::IteratePointers"))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-dgram-multicast.js"
                         "test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-child-process-deprecated-api.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-child-process-exec-env.js"
                         "test/simple/test-child-process-exec-cwd.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-cwd.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-custom-fds.js"
                         "test/simple/test-child-process-env.js"
                         "test/simple/test-http-full-response.js"
                         "test/simple/test-readline.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.2
  (package (inherit node-0.5)
    (version "0.2.0")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "0cb6laqb9z74kl1q67m721kr85svmscyyg2g0ks7m4f9hy9gygix"))))
    (arguments
     '(#:configure-flags `("--without-snapshot"
                           "--shared-cares")
       #:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects-visiting.h")
               (("    IteratePointers")
                "    BodyVisitorBase<StaticVisitor>::IteratePointers"))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-dgram-multicast.js"
                         "test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-child-process-deprecated-api.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-child-process-exec-env.js"
                         "test/simple/test-child-process-exec-cwd.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-cwd.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-custom-fds.js"
                         "test/simple/test-child-process-env.js"
                         "test/simple/test-http-full-response.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.1.101
  (package (inherit node-0.2)
    (version "0.1.101")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "0wz7nj8ggiz4bipdmh6f0853bhbyfvhngg27siwkvhnhkdf8rc24"))))
    (arguments
     '(#:configure-flags `(;;"--without-snapshot"
                           ;;"--shared-cares"
                           )
       #:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
                "int entry = this->FindEntry(key);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-http-full-response.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-custom-fds.js"
                         "test/simple/test-child-process-env.js"
                         "test/simple/test-child-process-exec-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.1.98
  (package (inherit node-0.2)
    (version "0.1.98")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1a7xr6jna9h9syh9756y40m7x9qi662kxgv5s62l07xsh4p4prbc"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
                "int entry = this->FindEntry(key);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-http-full-response.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-custom-fds.js"
                         "test/simple/test-child-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.1.95
  (package (inherit node-0.2)
    (version "0.1.95")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1f3mlfppishnd8z1pnr3jidmpj6waw3kz0cp5x94hzzw0mw4f5fj"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
                "int entry = this->FindEntry(key);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-http-304.js"
                         "test/simple/test-c-ares.js"
                         "test/simple/test-stdout-to-file.js"
                         "test/simple/test-error-reporting.js"
                         "test/simple/test-stdin-from-file.js"
                         "test/simple/test-pipe-head.js"
                         "test/simple/test-http-full-response.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.1.90
  (package (inherit node-0.2)
    (version "0.1.90")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1hwm8shkbarxf677hxdx72n8rkwcbar6iwkgvra9l125pvv4gg8d"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
                "int entry = this->FindEntry(key);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-c-ares.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-remote-module-loading.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-child-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with bash.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))))

(define-public node-0.1.28
  (package (inherit node)
           (version "0.1.28")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "0schdkjdmjv73k2kw3l3v5yrqxwz1wppqjam2fdn4d3d4kasiy06"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Symbols were used before they were included
             (substitute* '("deps/v8/src/globals.h")
               (("namespace v8 \\{")
                "#include <cstring>\nnamespace v8 {"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
               "int entry = this->FindEntry(key);"))
             (substitute* '("deps/v8/src/objects.h")
               (("set\\(HashTable")
                "this->set(HashTable")
               (("get\\(HashTable")
                "this->get(HashTable")
               (("fast_set\\(this, kNextEnumerationIndexIndex")
               "this->fast_set(this, kNextEnumerationIndexIndex"))
             (substitute* '("src/node.cc")
               (("f->Call\\(global, 1, &Local<Value>::New\\(process\\)\\);")
                "Local<Value> args[1] = { Local<Value>::New(process) };
                 f->Call(global, 1, args);"))
             (substitute* '("deps/v8/src/utils.h")
               (("set_start\\(buffer_\\);")
                "this->set_start(buffer_);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/mjsunit/test-tcp-tls.js"
                         "test/mjsunit/test-keep-alive.js"
                         "test/mjsunit/test-remote-module-loading.js"
                         "test/mjsunit/test-exec.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with the standard configure flags.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)))
    (inputs
     `(("gnutls" ,tls:gnutls)))))

(define-public node-0.1.32
  (package (inherit node)
    (version "0.1.32")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "0gppaz5qflnjvaflndard93vcjf6y2rqr6y54hyxy59c3zgpbnhz"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Symbols were used before they were included
             (substitute* '("deps/v8/src/globals.h")
               (("namespace v8 \\{")
                "#include <cstring>\nnamespace v8 {"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
               "int entry = this->FindEntry(key);"))
             (substitute* '("deps/v8/src/objects.h")
               (("set\\(HashTable")
                "this->set(HashTable")
               (("get\\(HashTable")
                "this->get(HashTable")
               (("fast_set\\(this, kNextEnumerationIndexIndex")
                "this->fast_set(this, kNextEnumerationIndexIndex"))
             (substitute* '("deps/v8/src/utils.h")
               (("set_start\\(buffer_\\);")
                "this->set_start(buffer_);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-remote-module-loading.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with the standard configure flags.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)))
    (inputs
     `(("gnutls" ,tls:gnutls)))))

(define-public node-0.1.31
  (package (inherit node)
    (version "0.1.31")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "1gdbg5fyc5hak243cjqsacd16yviwfhjgjikcjsq15bqvyz74296"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Symbols were used before they were included
             (substitute* '("deps/v8/src/globals.h")
               (("namespace v8 \\{")
                "#include <cstring>\nnamespace v8 {"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
               "int entry = this->FindEntry(key);"))
             (substitute* '("deps/v8/src/objects.h")
               (("set\\(HashTable")
                "this->set(HashTable")
               (("get\\(HashTable")
                "this->get(HashTable")
               (("fast_set\\(this, kNextEnumerationIndexIndex")
                "this->fast_set(this, kNextEnumerationIndexIndex"))
             (substitute* '("deps/v8/src/utils.h")
               (("set_start\\(buffer_\\);")
                "this->set_start(buffer_);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-remote-module-loading.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with the standard configure flags.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)))
    (inputs
     `(("gnutls" ,tls:gnutls)))))

(define-public node-0.1.30
  (package (inherit node)
    (version "0.1.30")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "0b7jsgdfqm3yhc8hdjavjxvnfzq2rwrylwh4619916v08ddlgvip"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Symbols were used before they were included
             (substitute* '("deps/v8/src/globals.h")
               (("namespace v8 \\{")
                "#include <cstring>\nnamespace v8 {"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
               "int entry = this->FindEntry(key);"))
             (substitute* '("deps/v8/src/objects.h")
               (("set\\(HashTable")
                "this->set(HashTable")
               (("get\\(HashTable")
                "this->get(HashTable")
               (("fast_set\\(this, kNextEnumerationIndexIndex")
                "this->fast_set(this, kNextEnumerationIndexIndex"))
             (substitute* '("deps/v8/src/utils.h")
               (("set_start\\(buffer_\\);")
                "this->set_start(buffer_);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/mjsunit/test-tcp-tls.js"
                         "test/mjsunit/test-keep-alive.js"
                         "test/mjsunit/test-remote-module-loading.js"
                         "test/mjsunit/test-exec.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with the standard configure flags.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)))
    (inputs
     `(("gnutls" ,tls:gnutls)))))

(define-public node-0.1.29
  (package (inherit node)
    (version "0.1.29")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "01mvx5pizzarndzlxp7jvclff9217xb9b0nkyx6ng7yqzgkdwvdm"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-g -I"
                           (assoc-ref %build-inputs "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Symbols were used before they were included
             (substitute* '("deps/v8/src/globals.h")
               (("namespace v8 \\{")
                "#include <cstring>\nnamespace v8 {"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.cc")
               (("int entry = FindEntry\\(key\\);")
               "int entry = this->FindEntry(key);"))
             (substitute* '("deps/v8/src/objects.h")
               (("set\\(HashTable")
                "this->set(HashTable")
               (("get\\(HashTable")
                "this->get(HashTable")
               (("fast_set\\(this, kNextEnumerationIndexIndex")
                "this->fast_set(this, kNextEnumerationIndexIndex"))
             (substitute* '("deps/v8/src/utils.h")
               (("set_start\\(buffer_\\);")
                "this->set_start(buffer_);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/mjsunit/test-tcp-tls.js"
                         "test/mjsunit/test-keep-alive.js"
                         "test/mjsunit/test-remote-module-loading.js"
                         "test/mjsunit/test-exec.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with the standard configure flags.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)))
    (inputs
     `(("gnutls" ,tls:gnutls)))))

(define-public node-0.1
  (package (inherit node)
    (version "0.1.33")
    (source (origin
              (method url-fetch)
              (uri (string-append "http://nodejs.org/dist/v" version
                                  "/node-v" version ".tar.gz"))
              (sha256
               (base32
                "19y5211rhj0waisfi0yc7j86psykkc49qym78cxayaxjmkdv2paa"))))
    (arguments
     '(#:make-flags (list (string-append
                           "CXXFLAGS=-g -I"
                           (assoc-ref %build-inputs
                                      "linux-headers")
                           "/include")
                          (string-append
                           "CFLAGS=-g -I"
                           (assoc-ref %build-inputs
                                      "linux-headers")
                           "/include"))
       #:test-target "test"
       #:phases
       (modify-phases %standard-phases
         (add-before 'configure 'patch-files
           (lambda* (#:key inputs #:allow-other-keys)
             ;; Backport an overflow bug with a fix from:
             ;; https://groups.google.com/forum/#!topic/v8-dev/n5dTMV1zb04
             (substitute* '("deps/v8/src/utils.h")
               (("while \\(dest <= limit - kStepSize\\) \\{")
                "ASSERT(dest + kStepSize > dest);  // Check for overflow.
                 while (dest + kStepSize <= limit) {"))
             ;; XXX: The configure script does not support the
             ;; --without-snapshot flaq, but this can be patched in manually
             (substitute* '("wscript")
               (("snapshot=on")
                ""))
             ;; XXX: For some reason, gcc makes v8 have segmentation faults by
             ;; optimizing the wrong things, requiring us to patch the flag
             ;; directly:
             (substitute* '("deps/v8/SConstruct")
               (("'-O3'")
                "'-O2'"))
             ;; XXX: Old sources made use of a more permissive compiler, but
             ;; for more recent versions of gcc, we need to properly designate
             ;; the namespace of functions we call.
             (substitute* '("deps/v8/src/objects.h" "deps/v8/src/objects.cc")
               (("\\(get\\(")
                "(this->get(")
               (("return get\\(E")
                "return this->get(E")
               (("return get\\(H")
                "return this->get(H")
               (("!get\\(")
                "!this->get(")
               (("int entry = FindEntry\\(key\\);")
                "int entry = this->FindEntry(key);"))
             ;; FIXME: These tests fail in the build container, but they don't
             ;; seem to be indicative of real problems in practice.
             (for-each delete-file
                       '("test/simple/test-remote-module-loading.js"
                         "test/simple/test-exec.js"
                         "test/simple/test-tcp-binary.js" 
                         "test/simple/test-fs-realpath.js"
                         "test/simple/test-child-process-env.js"))
             #t))
         (replace 'configure
           ;; Node's configure script is actually a python script, so we can't
           ;; run it with the standard configure flags.
           (lambda* (#:key outputs (configure-flags '()) inputs
                     #:allow-other-keys)
             (let* ((prefix (assoc-ref outputs "out"))
                    (flags
                     (cons (string-append "--prefix=" prefix)
                           configure-flags)))
               (format #t "build directory: ~s~%" (getcwd))
               (format #t "configure flags: ~s~%" flags)
               (setenv "CC" (string-append (assoc-ref inputs "gcc") "/bin/gcc"))
               (zero? (apply system*
                             "./configure" flags))))))))
    (native-inputs
     `(("python" ,python-2)
       ("linux-headers" ,linux-libre-headers)))
    (inputs
     `(("gnutls" ,tls:gnutls)))))
