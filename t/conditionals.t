; $Id$

(load "tests-driver.scm")
(load "compiler.scm")

(add-tests-with-string-output "conditional expressions"      
  [(if #t 1 0)                                   => "1\n" ]
  [(if #f 1 0)                                   => "0\n" ]
  [(if 0 1 0)                                    => "1\n" ]
  [(if 1 1 0)                                    => "1\n" ]
  [(if #\A 1 0)                                  => "1\n" ]
  [(if (fixnum? #\A) 1 0)                        => "0\n" ]
  [(if (char? #\A) 1 0)                          => "1\n" ]
  [(if (fixnum? #\A) 1 0)                        => "0\n" ]
  [(if (fixnum? 100) 1 0)                        => "1\n" ]
  [(if (and) 1 0)                                => "1\n" ]
  [(if (and #t) 1 0)                             => "1\n" ]
  [(if (and #f) 1 0)                             => "0\n" ]
  [(if (and #t #f) 1 0)                          => "0\n" ]
  [(if (and #t #t) 1 0)                          => "1\n" ]
  [(if (or) 1 0)                                 => "0\n" ]
  [(if (or #t) 1 0)                              => "1\n" ]
  [(if (or #f) 1 0)                              => "0\n" ]
  [(if (or #t #f) 1 0)                           => "1\n" ]
  [(if (or #t #t) 1 0)                           => "1\n" ]
  [(if (or (and #t #f) #t) 1 0)                  => "1\n" ]
  [(if (or (and #t #t) #t) 1 0)                  => "1\n" ]
  [(if (or (and #f #f) #t) 1 0)                  => "1\n" ]
  [(if (or (and #t #f) #f) 1 0)                  => "0\n" ]
  [(if (or (and #t #t) #f) 1 0)                  => "1\n" ]
  [(if (or (and #f #f) #f) 1 0)                  => "0\n" ]
  [(if (and (or #t #f) #t) 1 0)                  => "1\n" ]
  [(if (and (or #t #t) #t) 1 0)                  => "1\n" ]
  [(if (and (or #f #f) #t) 1 0)                  => "0\n" ]
  [(if (and (or #t #f) #f) 1 0)                  => "0\n" ]
  [(if (and (or #t #t) #f) 1 0)                  => "0\n" ]
  [(if (and (or #f #f) #f) 1 0)                  => "0\n" ]
  [(if (if (if #t #f #f) (if #t #f #f) #f) 1 0)  => "0\n" ]
  [(if (if #f (if #t #f #f) #f) 1 0)             => "0\n" ]
  [(if (if (if #t #f #f) (if #t #f #f) #t) 1 0)  => "1\n" ]
  [(if (if #f (if #t #f #f) #t) 1 0)             => "1\n" ]
  [(if #f #f #t)                                 => "#t\n" ]
  [(if (if #f #f #t) 1 0)                        => "1\n" ]
  [(if (if #t #f #f) 1 0)                        => "0\n" ]
  [(if #f (if #t #f #f) #t)                      => "#t\n" ]
  [(if () #f #t)                                 => "#f\n" ]
)

(test-all)
