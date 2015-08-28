;;; GNU Guix --- Functional package management for GNU
;;; Copyright © 2014 Pjotr Prins <pjotr.guix@thebird.nl>
;;; Copyright © 2014 Ludovic Courtès <ludo@gnu.org>
;;; Copyright © 2014, 2015 Mark H Weaver <mhw@netris.org>
;;; Copyright © 2014 David Thompson <davet@gnu.org>
;;; Copyright © 2015 Ricardo Wurmus <rekado@elephly.net>
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

(define-module (gnu packages ruby)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages readline)
  #:use-module (gnu packages autotools)
  #:use-module (gnu packages java)
  #:use-module (gnu packages libffi)
  #:use-module (gnu packages gdbm)
  #:use-module (gnu packages tls)
  #:use-module (gnu packages version-control)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix git-download)
  #:use-module (guix utils)
  #:use-module (guix build-system gnu)
  #:use-module (guix build-system ruby))

(define-public ruby
  (package
    (name "ruby")
    (version "2.2.3")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://cache.ruby-lang.org/pub/ruby/"
                           (version-major+minor version)
                           "/ruby-" version ".tar.xz"))
       (sha256
        (base32
         "19x8gs67klgc3ag815jpin83jn2nv1akgjcgayd6v3h1xplr1v66"))))
    (build-system gnu-build-system)
    (arguments
     `(#:test-target "test"
       #:parallel-tests? #f
       #:phases
       (alist-cons-before
        'configure 'replace-bin-sh
        (lambda _
          (substitute* '("Makefile.in"
                         "ext/pty/pty.c"
                         "io.c"
                         "lib/mkmf.rb"
                         "process.c"
                         "test/rubygems/test_gem_ext_configure_builder.rb"
                         "test/rdoc/test_rdoc_parser.rb"
                         "test/ruby/test_rubyoptions.rb"
                         "test/ruby/test_process.rb"
                         "test/ruby/test_system.rb"
                         "tool/rbinstall.rb")
            (("/bin/sh") (which "sh"))))
        %standard-phases)))
    (inputs
     `(("readline" ,readline)
       ("openssl" ,openssl)
       ("libffi" ,libffi)
       ("gdbm" ,gdbm)
       ("zlib" ,zlib)))
    (native-search-paths
     (list (search-path-specification
            (variable "GEM_PATH")
            (files (list (string-append "lib/ruby/gems/"
                                        (version-major+minor version)
                                        ".0"))))))
    (synopsis "Programming language interpreter")
    (description "Ruby is a dynamic object-oriented programming language with
a focus on simplicity and productivity.")
    (home-page "https://ruby-lang.org")
    (license license:ruby)))

(define-public ruby-2.1
  (package (inherit ruby)
    (version "2.1.6")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://cache.ruby-lang.org/pub/ruby/"
                           (version-major+minor version)
                           "/ruby-" version ".tar.bz2"))
       (sha256
        (base32
         "1sbcmbhadcxk0509svwxbm2vvgmpf3xjxr1397bgp9x46nz36lkv"))))
    (arguments
     `(#:test-target "test"
       #:parallel-tests? #f
       #:phases
        (alist-cons-before
         'configure 'replace-bin-sh
         (lambda _
           (substitute* '("Makefile.in"
                          "ext/pty/pty.c"
                          "io.c"
                          "lib/mkmf.rb"
                          "process.c")
             (("/bin/sh") (which "sh"))))
         %standard-phases)))
    (native-search-paths
     (list (search-path-specification
            (variable "GEM_PATH")
            (files (list (string-append "lib/ruby/gems/"
                                        (version-major+minor version)
                                        ".0"))))))))

(define-public ruby-1.8
  (package (inherit ruby)
    (version "1.8.7-p374")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "http://cache.ruby-lang.org/pub/ruby/"
                           (version-major+minor version)
                           "/ruby-" version ".tar.bz2"))
       (sha256
        (base32
         "1qq7khilwkayrhwmzlxk83scrmiqfi7lgsn4c63znyvz2c1lgqxl"))))
    (native-search-paths '())
    (arguments
     `(#:test-target "test"
       #:parallel-tests? #f
       #:phases
        (alist-cons-before
         'configure 'replace-bin-sh
         (lambda _
           (substitute* '("Makefile.in"
                          "ext/pty/pty.c"
                          "io.c"
                          "lib/mkmf.rb"
                          "process.c")
             (("/bin/sh") (which "sh"))))
         %standard-phases)))))

(define-public ruby-hoe
  (package
    (name "ruby-hoe")
    (version "3.13.1")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "hoe" version))
              (sha256
               (base32
                "1mac13krdrasn9819dd65xj27kklfy0xdbj3p6s2ij4vlcb46h8q"))) )
    (build-system ruby-build-system)
    (synopsis "Ruby project management helper")
    (description
     "Hoe is a rake/rubygems helper for project Rakefiles.  It helps manage,
maintain, and release projects and includes a dynamic plug-in system allowing
for easy extensibility.  Hoe ships with plug-ins for all the usual project
tasks including rdoc generation, testing, packaging, deployment, and
announcement.")
    (home-page "http://www.zenspider.com/projects/hoe.html")
    (license license:expat)))

(define-public ruby-rake-compiler
  (package
    (name "ruby-rake-compiler")
    (version "0.9.5")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rake-compiler" version))
              (sha256
               (base32
                "1k8im2vzj849xdgjk6wafspkiwwapqwm738majchb4dnhnsk64cx"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; needs cucumber
    (synopsis "Building and packaging helper for Ruby native extensions")
    (description "Rake-compiler provides a framework for building and
packaging native C and Java extensions in Ruby.")
    (home-page "https://github.com/rake-compiler/rake-compiler")
    (license license:expat)))

(define-public ruby-i18n
  (package
    (name "ruby-i18n")
    (version "0.7.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "i18n" version))
              (sha256
               (base32
                "1i5z1ykl8zhszsxcs8mzl8d0dxgs3ylz8qlzrw74jb0gplkx6758"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; no tests
    (synopsis "Internationalization library for Ruby")
    (description "Ruby i18n is an internationalization and localization
solution for Ruby programs.  It features translation and localization,
interpolation of values to translations, pluralization, customizable
transliteration to ASCII, flexible defaults, bulk lookup, lambdas as
translation data, custom key/scope separator, custom exception handlers, and
an extensible architecture with a swappable backend.")
    (home-page "http://github.com/svenfuchs/i18n")
    (license license:expat)))

;; RSpec is the dominant testing library for Ruby projects.  Even RSpec's
;; dependencies use RSpec for their test suites!  To avoid these circular
;; dependencies, we disable tests for all of the RSpec-related packages.
(define ruby-rspec-support
  (package
    (name "ruby-rspec-support")
    (version "3.2.2")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rspec-support" version))
              (sha256
               (base32
                "194zry5195ls2hni7r9824vqb5d3qfg4jb15fgj8glfy0rvw3zxl"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (synopsis "RSpec support library")
    (description "Support utilities for RSpec gems.")
    (home-page "https://github.com/rspec/rspec-support")
    (license license:expat)))

(define-public ruby-rspec-core
  (package
    (name "ruby-rspec-core")
    (version "3.2.3")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rspec-core" version))
              (sha256
               (base32
                "0k2471iw30gc2cvv67damrx666pmsvx8l0ahk3hm20dhfnmcmpvv"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (propagated-inputs
     `(("ruby-rspec-support" ,ruby-rspec-support)))
    (synopsis "RSpec core library")
    (description "Rspec-core provides the RSpec test runner and example
groups.")
    (home-page "https://github.com/rspec/rspec-core")
    (license license:expat)))

(define-public ruby-diff-lcs
  (package
    (name "ruby-diff-lcs")
    (version "1.2.5")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "diff-lcs" version))
              (sha256
               (base32
                "1vf9civd41bnqi6brr5d9jifdw73j9khc6fkhfl1f8r9cpkdvlx1"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (synopsis "Compute the difference between two Enumerable sequences")
    (description "Diff::LCS computes the difference between two Enumerable
sequences using the McIlroy-Hunt longest common subsequence (LCS) algorithm.
It includes utilities to create a simple HTML diff output format and a
standard diff-like tool.")
    (home-page "https://github.com/halostatue/diff-lcs")
    (license license:expat)))

(define-public ruby-rspec-expectations
  (package
    (name "ruby-rspec-expectations")
    (version "3.2.1")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rspec-expectations" version))
              (sha256
               (base32
                "01kmchabgpdcaqdsqg8r0g5gy385xhp1k1jsds3w264ypin17n14"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (propagated-inputs
     `(("ruby-rspec-support" ,ruby-rspec-support)
       ("ruby-diff-lcs" ,ruby-diff-lcs)))
    (synopsis "RSpec expectations library")
    (description "Rspec-expectations provides a simple API to express expected
outcomes of a code example.")
    (home-page "https://github.com/rspec/rspec-expectations")
    (license license:expat)))

(define-public ruby-rspec-mocks
  (package
    (name "ruby-rspec-mocks")
    (version "3.2.1")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rspec-mocks" version))
              (sha256
               (base32
                "09yig1lwgxl8fsns71z3xhv7wkg7zvagydh37pvaqpw92dz55jv2"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (propagated-inputs
     `(("ruby-rspec-support" ,ruby-rspec-support)
       ("ruby-diff-lcs" ,ruby-diff-lcs)))
    (synopsis "RSpec stubbing and mocking library")
    (description "Rspec-mocks provides RSpec's \"test double\" framework, with
support for stubbing and mocking.")
    (home-page "https://github.com/rspec/rspec-mocks")
    (license license:expat)))

(define-public ruby-rspec
  (package
    (name "ruby-rspec")
    (version "3.2.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rspec" version))
              (sha256
               (base32
                "0lkz01j4yxcwb3g5w6r1l9khnyw3sxib4rrh4npd2pxh390fcc4f"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (propagated-inputs
     `(("ruby-rspec-core" ,ruby-rspec-core)
       ("ruby-rspec-mocks" ,ruby-rspec-mocks)
       ("ruby-rspec-expectations" ,ruby-rspec-expectations)))
    (synopsis "Behavior-driven development framework for Ruby")
    (description "RSpec is a behavior-driven development (BDD) framework for
Ruby.  This meta-package includes the RSpec test runner, along with the
expectations and mocks frameworks.")
    (home-page "http://rspec.info/")
    (license license:expat)))

;; Bundler is yet another source of circular dependencies, so we must disable
;; its test suite as well.
(define-public bundler
  (package
    (name "bundler")
    (version "1.9.9")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "bundler" version))
              (sha256
               (base32
                "12qk1569pswa9mmid6lsqy2napn9fmkbmv0k7xkl52nyfh8rsy4d"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; avoid dependency cycles
    (synopsis "Ruby gem bundler")
    (description "Bundler automatically downloads and installs a list of gems
specified in a \"Gemfile\", as well as their dependencies.")
    (home-page "http://bundler.io/")
    (license license:expat)))

(define-public ruby-builder
  (package
    (name "ruby-builder")
    (version "3.2.2")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "builder" version))
              (sha256
               (base32
                "14fii7ab8qszrvsvhz6z2z3i4dw0h41a62fjr2h1j8m41vbrmyv2"))))
    (build-system ruby-build-system)
    (arguments
     `(#:phases
       (modify-phases %standard-phases
         (add-after 'unpack 'do-not-use-rvm
          (lambda _
            (substitute* "rakelib/tags.rake"
              (("RVM_GEMDIR = .*") "RVM_GEMDIR = 'no-rvm-please'\n"))
            #t)))))
    (synopsis "Ruby library to create structured data")
    (description "Builder provides a number of builder objects that make it
easy to create structured data.  Currently the following builder objects are
supported: XML Markup and XML Events.")
    (home-page "https://github.com/jimweirich/builder")
    (license license:expat)))

(define-public ruby-rjb
  (package
    (name "ruby-rjb")
    (version "1.5.3")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "rjb" version))
              (sha256
               (base32
                "0gzs92dagk981s4vrymnqg0vll783b9k564j0cdgp167nc5a2zg4"))))
    (build-system ruby-build-system)
    (arguments
     `(#:tests? #f ; no rakefile
       #:phases
       (modify-phases %standard-phases
         (add-before 'build 'set-java-home
          (lambda* (#:key inputs #:allow-other-keys)
            (setenv "JAVA_HOME" (assoc-ref inputs "jdk"))
            #t)))))
    (native-inputs
     `(("jdk" ,icedtea7 "jdk")))
    (synopsis "Ruby-to-Java bridge using the Java Native Interface")
    (description "RJB is a bridge program that connects Ruby and Java via the
Java Native Interface.")
    (home-page "http://www.artonx.org/collabo/backyard/?RubyJavaBridge")
    (license license:lgpl2.1+)))

(define-public ruby-useragent
  (package
    (name "ruby-useragent")
    (version "0.13.3")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "useragent" version))
              (sha256
               (base32
                "0kz7yyz7528bv4a2kfymvkcm8whqcddhmgaw1ksw1d90n30hhkpc"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; no test suite
    (synopsis "HTTP user agent parser for Ruby")
    (description "UserAgent is a Ruby library that parses and compares HTTP
User Agents.")
    (home-page "https://github.com/gshutler/useragent")
    (license license:expat)))

(define-public ruby-bacon
  (package
    (name "ruby-bacon")
    (version "1.2.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "bacon" version))
              (sha256
               (base32
                "1f06gdj77bmwzc1k5iragl1595hbn67yc7sqvs56ca8plrr2vmai"))))
    (build-system ruby-build-system)
    (synopsis "Small RSpec clone")
    (description "Bacon is a small RSpec clone providing all essential
features.")
    (home-page "https://github.com/chneukirchen/bacon")
    (license license:expat)))

(define-public ruby-arel
  (package
    (name "ruby-arel")
    (version "6.0.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "arel" version))
              (sha256
               (base32
                "18wnfnzr2i5p3fygsddjbi1cimws6823nbk8drxidmnj8jz7h0ar"))))
    (build-system ruby-build-system)
    (arguments
     '(#:tests? #f)) ; no test suite
    (synopsis "SQL AST manager for Ruby")
    (description "Arel is a SQL AST manager for Ruby.  It simplifies the
generation of complex SQL queries and adapts to various relational database
implementations.")
    (home-page "https://github.com/rails/arel")
    (license license:expat)))

(define-public ruby-connection-pool
  (package
    (name "ruby-connection-pool")
    (version "2.2.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "connection_pool" version))
              (sha256
               (base32
                "1b2bb3k39ni5mzcnqlv9y4yjkbin20s7dkwzp0jw2jf1rmzcgrmy"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("bundler" ,bundler)))
    (synopsis "Generic connection pool for Ruby")
    (description "Connection_pool provides a generic connection pooling
interface for Ruby programs.")
    (home-page "https://github.com/mperham/connection_pool")
    (license license:expat)))

(define-public ruby-net-http-persistent
  (package
    (name "ruby-net-http-persistent")
    (version "2.9.4")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "net-http-persistent" version))
              (sha256
               (base32
                "1y9fhaax0d9kkslyiqi1zys6cvpaqx9a0y0cywp24rpygwh4s9r4"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("ruby-connection-pool" ,ruby-connection-pool)
       ("ruby-hoe" ,ruby-hoe)))
    (synopsis "Persistent HTTP connection manager")
    (description "Net::HTTP::Persistent manages persistent HTTP connections
using Net::HTTP, supporting reconnection and retry according to RFC 2616.")
    (home-page "https://github.com/drbrain/net-http-persistent")
    (license license:expat)))

(define-public ruby-minitest
  (package
    (name "ruby-minitest")
    (version "5.7.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "minitest" version))
              (sha256
               (base32
                "0rxqfakp629mp3vwda7zpgb57lcns5znkskikbfd0kriwv8i1vq8"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("ruby-hoe" ,ruby-hoe)))
    (synopsis "Small test suite library for Ruby")
    (description "Minitest provides a complete suite of Ruby testing
facilities supporting TDD, BDD, mocking, and benchmarking.")
    (home-page "https://github.com/seattlerb/minitest")
    (license license:expat)))

(define-public ruby-minitest-sprint
  (package
    (name "ruby-minitest-sprint")
    (version "1.1.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "minitest-sprint" version))
              (sha256
               (base32
                "179d6pj56l9xzm46fqsqj10mzjkr1f9fv4cxa8wvchs97hqz33w1"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("ruby-hoe" ,ruby-hoe)
       ("ruby-minitest" ,ruby-minitest)))
    (synopsis "Fast test suite runner for minitest")
    (description "Minitest-sprint is a test runner for minitest that makes it
easier to re-run individual failing tests.")
    (home-page "https://github.com/seattlerb/minitest-sprint")
    (license license:expat)))

(define-public ruby-minitest-bacon
  (package
    (name "ruby-minitest-bacon")
    (version "1.0.2")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "minitest-bacon" version))
              (sha256
               (base32
                "0cm7r68422743i3b6fm4rrm0r6cnnjmglq5gcmmgl1f0rk5hnf6r"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("ruby-hoe" ,ruby-hoe)))
    (inputs
     `(("ruby-minitest" ,ruby-minitest)))
    (synopsis "Bacon compatibility library for minitest")
    (description "Minitest-bacon extends minitest with bacon-like
functionality, making it easier to migrate test suites from bacon to minitest.")
    (home-page "https://github.com/seattlerb/minitest-bacon")
    (license license:expat)))

(define-public ruby-daemons
  (package
    (name "ruby-daemons")
    (version "1.2.2")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "daemons" version))
              (sha256
               (base32
                "121c7vkimg3baxga69xvdkwxiq8wkmxqvdbyqi5i82vhih5d3cn3"))))
    (build-system ruby-build-system)
    (arguments
     `(#:tests? #f)) ; no test suite
    (synopsis "Daemonize Ruby programs")
    (description "Daemons provides a way to wrap existing Ruby scripts to be
run as a daemon and to be controlled by simple start/stop/restart commands.")
    (home-page "https://github.com/thuehlinger/daemons")
    (license license:expat)))

(define-public ruby-git
  (package
    (name "ruby-git")
    (version "1.2.9.1")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "git" version))
              (sha256
               (base32
                "1sqfj8lmhl7c5zamcckkpik4izfph2zkv6krw0i8mzj5pdws5acs"))))
    (build-system ruby-build-system)
    (arguments
     `(#:tests? #f ; no tests
       #:phases (modify-phases %standard-phases
                  (add-after 'install 'patch-git-binary
                    (lambda* (#:key inputs outputs #:allow-other-keys)
                      ;; Make the default git binary an absolute path to the
                      ;; store.
                      (let ((git    (string-append (assoc-ref inputs "git")
                                                   "/bin/git"))
                            (config (string-append (getenv "GEM_HOME")
                                                   "/gems/git-" ,version
                                                   "/lib/git/config.rb")))
                        (substitute* (list config)
                          (("'git'")
                           (string-append "'" git "'")))
                        #t))))))
    (inputs
     `(("git" ,git)))
    (synopsis "Ruby wrappers for Git")
    (description "Ruby/Git is a Ruby library that can be used to create, read
and manipulate Git repositories by wrapping system calls to the git binary.")
    (home-page "https://github.com/schacon/ruby-git")
    (license license:expat)))

(define-public ruby-slop
  (package
    (name "ruby-slop")
    (version "4.1.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "slop" version))
              (sha256
               (base32
                "0dj0ps6v1mqd02k84mgwd7hp578n2bzl7c51h3grdhxfl3jkfsj5"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("ruby-minitest" ,ruby-minitest)))
    (synopsis "Ruby command line option parser")
    (description "Slop provides a Ruby domain specific language for gathering
options and parsing command line flags.")
    (home-page "https://github.com/leejarvis/slop")
    (license license:expat)))

(define-public ruby-multipart-post
  (package
    (name "ruby-multipart-post")
    (version "2.0.0")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "multipart-post" version))
              (sha256
               (base32
                "09k0b3cybqilk1gwrwwain95rdypixb2q9w65gd44gfzsd84xi1x"))))
    (build-system ruby-build-system)
    (native-inputs
     `(("bundler" ,bundler)))
    (synopsis "Multipart POST library for Ruby")
    (description "Multipart-Post Adds multipart POST capability to Ruby's
net/http library.")
    (home-page "https://github.com/nicksieger/multipart-post")
    (license license:expat)))

(define-public ruby-arel
  (package
    (name "ruby-arel")
    (version "6.0.3")
    (source (origin
              (method url-fetch)
              (uri (rubygems-uri "arel" version))
              (sha256
               (base32
                "1a270mlajhrmpqbhxcqjqypnvgrq4pgixpv3w9gwp1wrrapnwrzk"))))
    (build-system ruby-build-system)
    (arguments '(#:tests? #f)) ; no tests
    (home-page "https://github.com/rails/arel")
    (synopsis "SQL AST manager for Ruby")
    (description "Arel is a SQL AST manager for Ruby.  It simplifies the
generation of complex SQL queries and is compatible with various RDBMSes.")
    (license license:expat)))
