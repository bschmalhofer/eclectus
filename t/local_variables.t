; $Id$

(load "tests-driver.scm") ; this should come first

(add-tests-with-string-output "local variables"
  [(let () 13)                                             => "13\n"]     
  [(let (($var_a 17)) 13)                                  => "13\n"]     
  [(let ((var-a 17)) 13)                                   => "13\n"]     
  [(let (($var_a 14)) $var_a)                              => "14\n"]     
  [(let (($var_a 17) ($var_b 21)) 13)                      => "13\n"]     
  [(let (($var_a 13) ($var_b 21)) (fxadd1 $var_a))         => "14\n"]     
  [(let (($var_a 13) ($var_b 21)) (fx+ $var_a $var_b))     => "34\n"]     
  [(let (($var_a 13) ($var_b 21)) (fx> $var_a $var_b))     => "#f\n"]     
  [(let (($var_a 13) ($var_b 21)) (fx> $var_b $var_a))     => "#t\n"]     
  [(let ((var-a 13) (var-b 22))   (fx+ var-a var-b))       => "35\n"]     
  [(let ((var-a2 13) (var-b3 23))   (fx+ var-a2 var-b3))   => "36\n"]     
  [(let* () 23)                                            => "23\n"]     
)

(load "compiler.scm")
(test-all)
