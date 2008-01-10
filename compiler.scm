; $Id$

; Generate driver and PAST for Eclectus

;; Helpers that emit PIR

; unique ids for registers
(define counter 1000)
(define (gen-unique-id)
  (set! counter (+ 1 counter))
  counter)

; Emit PIR that loads libs
(define emit-init
  (lambda ()
    (emit "
          # PIR generated by compiler.scm
          
          # The dynamics PMCs used by Eclectus are loaded
          .loadlib 'eclectus_group'
          
          # for devel
          .include 'library/dumper.pir'
          
          .namespace
          
          .sub '__onload' :init
              load_bytecode 'PGE.pbc'
              load_bytecode 'PGE/Text.pbc'
              load_bytecode 'PGE/Util.pbc'
              load_bytecode 'PGE/Dumper.pbc'
              load_bytecode 'PCT.pbc'
          .end
          ")))

; Emit PIR that prints the value returned by scheme_entry()
(define emit-driver
  (lambda ()
    (emit "
          .sub drive :main
          
              .local pmc stmts
              ( stmts ) = scheme_entry()
              # _dumper( stmts, 'stmts' )
          
              # compile and evaluate
              .local pmc past_compiler
              past_compiler = new [ 'PCT::HLLCompiler' ]
              $P0 = split ' ', 'post pir evalpmc'
              past_compiler.'stages'( $P0 )
              past_compiler.'eval'(stmts)
          
          .end
          ")))

; emit the PIR library
(define emit-builtins
  (lambda ()
    (emit "
          .sub 'say'
              .param pmc args :slurpy
              if null args goto end
              .local pmc iter
              iter = new 'Iterator', args
          loop:
              unless iter goto end
              $P0 = shift iter
              print $P0
              goto loop
          end:
              say ''
              .return ()
          .end
          
          .sub 'infix:<'
              .param num a
              .param num b
              $I0 = islt a, b

              .return ($I0)
          .end

          .sub 'infix:<='
              .param num a
              .param num b
              $I0 = isle a, b

              .return ($I0)
          .end

          .sub 'infix:=='
              .param pmc a
              .param pmc b
              $I0 = cmp_num a, b
              $I0 = iseq $I0, 0
          
              .return ($I0)
          .end

          .sub 'infix:>='
              .param num a
              .param num b
              $I0 = isge a, b

              .return ($I0)
          .end

          .sub 'infix:>'
              .param num a
              .param num b
              $I0 = isgt a, b

              .return ($I0)
          .end

          ")))

;; recognition of forms

; forms represented by a scalar PMC
(define immediate?
  (lambda (x)
    (or (fixnum? x)
        (boolean? x)
        (char? x)
        (and (list? x)
             (= (length x) 0)))))

(define variable?
  (lambda (x) 
    (symbol? x)))

(define make-combination-predicate
  (lambda (name)
    (lambda (form)
      (and (pair? form)
           (eq? name (car form))))))

(define if?
  (make-combination-predicate 'if))

(define let?
  (make-combination-predicate 'let))

(define lambda?
  (lambda (x)
    (and (pair? x)
         (pair? (car x)))))

(define if-test
  (lambda (form)
    (car (cdr form))))

(define if-conseq
  (lambda (form)
    (car (cdr (cdr form)))))

(define if-altern
  (lambda (form)
    (car (cdr (cdr (cdr form))))))

; Support for primitive functions

; is x a primitive?
(define primitive?
  (lambda (x)
    (and (symbol? x)
         (getprop x '*is-prim*))))

; is x a call to a primitive? 
(define primcall?
  (lambda (x)
    (and (pair? x)
         (primitive? (car x)))))

; a primitive function is a symbol with the properties
; *is-prim*, *arg-count* and *emitter*
; implementatus of primitive functions are added
; with 'define-primitive'
(define-syntax define-primitive
  (syntax-rules ()
    [(_ (prim-name arg* ...) b b* ...)
     (begin
        (putprop 'prim-name '*is-prim*
          #t)
        (putprop 'prim-name '*arg-count*
          (length '(arg* ...)))
        (putprop 'prim-name '*emitter*
          (lambda (arg* ...) b b* ...)))]))

; implementation of fxadd1
(define-primitive (fxadd1 arg)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pirop "n_add")))
    (emit-expr arg)
    (emit-expr 1)))

; implementation of fx+
(define-primitive (fx+ arg1 arg2)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pirop "n_add")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of fxsub1
(define-primitive (fxsub1 arg)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pirop "n_sub")))
    (emit-expr arg)
    (emit-expr 1)))

; implementation of fx-
(define-primitive (fx- arg1 arg2)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pirop "n_sub")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of fxlogand
(define-primitive (fxlogand arg1 arg2)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pirop "n_band")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of fxlogor
(define-primitive (fxlogor arg1 arg2)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pirop "n_bor")))
    (emit-expr arg1)
    (emit-expr arg2)))

; implementation of char->fixnum
(define-primitive (char->fixnum arg)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pasttype "inline")
                   (inline "new %r, 'EclectusFixnum'\\nassign %r, %0\\n")))
    (emit-expr arg)))

; implementation of fixnum->char
(define-primitive (fixnum->char arg)
  (list
    (string->symbol "PAST::Op")
    (quasiquote (@ (pasttype "inline")
                   (inline "new %r, 'EclectusCharacter'\\nassign %r, %0\\n")))
    (emit-expr arg)))

(define emit-comparison
  (lambda (builtin arg1 arg2)
    (list
      (string->symbol "PAST::Op")
      (quasiquote (@ (pasttype "if")))
      (list
        (string->symbol "PAST::Op")
        (quasiquote (@ (pasttype "chain")
                       (name (unquote builtin))))
        (emit-expr arg1)
        (emit-expr arg2))
      (emit-expr #t)
      (emit-expr #f))))

; implementation of char<
(define-primitive (char< arg1 arg2)
  (emit-comparison "infix:<" arg1 arg2))

; implementation of char<=
(define-primitive (char<= arg1 arg2)
  (emit-comparison "infix:<=" arg1 arg2))

; implementation of char=
(define-primitive (char= arg1 arg2)
  (emit-comparison "infix:==" arg1 arg2))

; implementation of char>
(define-primitive (char> arg1 arg2)
  (emit-comparison "infix:>" arg1 arg2))

; implementation of char>=
(define-primitive (char>= arg1 arg2)
  (emit-comparison "infix:>=" arg1 arg2))

; implementation of fxzero?
(define-primitive (fxzero? arg)
  (emit-comparison "infix:==" arg 0))

; implementation of fx<
(define-primitive (fx< arg1 arg2)
  (emit-comparison "infix:<" arg1 arg2))

; implementation of fx<=
(define-primitive (fx<= arg1 arg2)
  (emit-comparison "infix:<=" arg1 arg2))

; implementation of fx=
(define-primitive (fx= arg1 arg2)
  (emit-comparison "infix:==" arg1 arg2))

; implementation of fx>=
(define-primitive (fx>= arg1 arg2)
  (emit-comparison "infix:>=" arg1 arg2))

; implementation of fx>
(define-primitive (fx> arg1 arg2)
  (emit-comparison "infix:>" arg1 arg2))

(define emit-typequery
  (lambda (typename arg)
    (list
      (string->symbol "PAST::Op")
      (quasiquote (@ (pasttype "if")))
      (list
        (string->symbol "PAST::Op")
        (quasiquote (@ (pasttype "inline")
                       (inline (unquote (format "new %r, 'EclectusBoolean'\\nisa $I1, %0, '~a'\\n %r = $I1" typename)))))
        (emit-expr arg))
      (emit-expr #t)
      (emit-expr #f))))
   
; implementation of null?
(define-primitive (null? arg)
  (emit-typequery "EclectusEmptyList" arg))

; implementation of fixnum?
(define-primitive (fixnum? arg)
  (emit-typequery "EclectusFixnum" arg))

; implementation of boolean?
(define-primitive (boolean? arg)
  (emit-typequery "EclectusBoolean" arg))

; implementation of char?
(define-primitive (char? arg)
  (emit-typequery "EclectusCharacter" arg))

; a getter of '*emitter*'
(define primitive-emitter
  (lambda (x)
    (getprop x '*emitter*)))

(define emit-function-header
  (lambda (function-name)
    (emit (string-append ".sub " function-name))))

(define emit-function-footer
  (lambda (reg)
    (emit "
            .return( reg_~a )
          .end
          " reg)))

(define emit-primcall
  (lambda (x)
    (let ([prim (car x)] [args (cdr x)])
      (apply (primitive-emitter prim) args))))

; emit PIR for a scalar
(define emit-immediate
  (lambda (x)
    (list
      (string->symbol "PAST::Val")
      (cond
        [(fixnum? x)
         (quasiquote (@ (value (unquote x))
                        (returns "EclectusFixnum")))]
        [(char? x)
         (quasiquote (@ (value (unquote (char->integer x)))
                        (returns "EclectusCharacter")))]
        [(and (list? x)
              (= (length x) 0))
         (quasiquote (@ (value 0)
                        (returns "EclectusEmptyList")))]
        [(boolean? x)
         (quasiquote (@ (value (unquote (if x 1 0)))
                        (returns "EclectusBoolean")))]
        [(string? x)
         (quasiquote (@ (value (unquote (format "\"'~a'\"" x)))
                          (returns "EclectusString")))]))))

(define bindings
  (lambda (x)
    (cadr x)))

(define body
  (lambda (x)
    (caddr x)))

(define emit-variable
  (lambda (x)
    (list
      (string->symbol "PAST::Var")
      (quasiquote (@ (name (unquote x))
                     (scope "lexical")
                     (viviself "Undef"))))))

(define emit-let
  (lambda (binds body)
    (if (null? binds)
      (emit-expr body)
      (begin
        (append
          (list
            (string->symbol "PAST::Stmts"))
          (map 
            (lambda (decl)
              (list
                (string->symbol "PAST::Op")
                (quasiquote (@ (pasttype "copy")
                               (lvalue "1")))
                (list
                  (string->symbol "PAST::Var")
                  (quasiquote (@ (name (unquote (car decl)))
                                 (scope "lexical")
                                 (viviself "Undef")
                                 (isdecl 1))))
                (emit-expr (cadr decl))))
            binds)
          (list
            (emit-expr body)))))))

(define emit-if
  (lambda (x)
    (list
      (string->symbol "PAST::Op")
      (quasiquote (@ (pasttype "if")))
      (emit-expr (if-test x))
      (emit-expr (if-conseq x))
      (emit-expr (if-altern x)))))

(define emit-lambda
  (lambda (x)
    ;(write (cddar x))(newline)
    (list  
      (string->symbol "PAST::Op")
      (quasiquote (@ (pasttype "call")))
      (list
        (string->symbol "PAST::Block")
        (append
          (list
            (string->symbol "PAST::Stmts"))
          (map
            (lambda (stmt)
              ;(write stmt)
              (emit-expr stmt))
            (cddar x)))))))
 
; emir PIR for an expression
(define emit-expr
  (lambda (x)
    ;(diag (format "~s" x))
    (cond
      [(immediate? x) (emit-immediate x)]
      [(variable? x)  (emit-variable x)]
      [(let? x)       (emit-let (bindings x) (body x))]
      [(if? x)        (emit-if x)]
      [(lambda? x)    (emit-lambda x)]
      [(primcall? x)  (emit-primcall x)]))) 

; transverse the program and rewrite
; "and" can be supported by transformation before compiling
; So "and" is implemented if terms of "if"
;
; Currently a new S-expression is generated,
; as I don't know how to manipulate S-expressions while traversing it
(define transform-and-or
  (lambda (tree)
    (cond [(atom? tree)
           tree]
          [(eqv? (car tree) 'and) 
           ( cond [(null? (cdr tree)) #t]
                  [(= (length (cdr tree)) 1) (transform-and-or (cadr tree))]
                  [else (quasiquote
                          (if
                            (unquote (transform-and-or (cadr tree)))
                            (unquote (transform-and-or (quasiquote (and (unquote-splicing (cddr tree))))))
                            #f))])]
          [(eqv? (car tree) 'or) 
           ( cond [(null? (cdr tree)) #f]
                  [(= (length (cdr tree)) 1) (transform-and-or (cadr tree))]
                  [else (quasiquote
                          (if
                           (unquote (transform-and-or (cadr tree)))
                           (unquote (transform-and-or (cadr tree)))
                           (unquote (transform-and-or (quasiquote (or (unquote-splicing (cddr tree))))))))])]
          [(eqv? (car tree) 'not) 
           (quasiquote (if (unquote (transform-and-or (cadr tree))) #f #t))]
          [else
           (map transform-and-or tree)]))) 

; eventually this will become a PIR generator
; for PAST as SXML
; currently it only handles the pushes
(define past-sxml->past-pir
  (lambda (past)
    (let ([uid (gen-unique-id)])
      ;(diag (format "~a" past))
      (emit "
            .local pmc reg_~a
            reg_~a = new '~a'
            " uid uid (car past))
      (for-each
        (lambda (daughter)
          (if (eq? '@ (car daughter))
            (for-each
              (lambda (key_val)
                ;(write (list "emit-pushes3:" daughter (cadr daughter) (caadr daughter)(cadadr daughter)))(newline)
                (emit "
                      reg_~a.init( '~a' => \"~a\" )
                      " uid (car key_val) (cadr key_val)))
                (cdr daughter))
              (emit "
                    reg_~a.push( reg_~a )
                    " uid (past-sxml->past-pir daughter))))
        (cdr past))
      uid)))

; print the result of the evaluation
(define wrap-say
  (lambda (past)
    (list
      (string->symbol "PAST::Op")
      (quasiquote (@ (pasttype "call")
                     (name "say")))
      past)))

; the actual compiler
(define compile-program
  (lambda (program)
    (emit-init)
    (emit-driver)
    (emit-builtins)
    (emit-function-header "scheme_entry")
    (emit-function-footer
      (past-sxml->past-pir
        (wrap-say
          (emit-expr
            (transform-and-or program)))))))
