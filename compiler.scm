; $Id$

; Generate driver and PAST for Eclectus

;; Helpers that emit PIR

; unique ids for registers
(define counter 1000)
(define (gen-unique-id)
  (set! counter (+ 1 counter))
  counter)

(define (make-past-conser type)
  (let ((type-symbol (string->symbol type)))
    (lambda args
      (cons type-symbol args))))

(define past::op (make-past-conser "PAST::Op"))
(define past::val (make-past-conser "PAST::Val"))
(define past::var (make-past-conser "PAST::Var"))
(define past::block (make-past-conser "PAST::Block"))
(define past::stmts
  (let ((type-symbol (string->symbol "PAST::Stmts")))
    (lambda (stmts)
      (cons type-symbol stmts))))

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

; recognition of forms
(define make-combination-predicate
  (lambda (name)
    (lambda (form)
      (and (pair? form)
           (eq? name (car form))))))

(define if?     (make-combination-predicate 'if))
(define let?    (make-combination-predicate 'let))
(define lambda? (make-combination-predicate 'lambda))
(define begin?  (make-combination-predicate 'begin))
(define quote?  (make-combination-predicate 'quote))

(define if-test
  (lambda (form)
    (car (cdr form))))

(define if-conseq
  (lambda (form)
    (car (cdr (cdr form)))))

(define if-altern
  (lambda (form)
    (car (cdr (cdr (cdr form))))))

(define (self-evaluating? x)
  (or (string? x)
      (number? x)
      (char? x)
      (boolean? x)))

; Support for primitive functions

(define-record primitive (arg-count emitter))

(define *primitives* (make-eq-hashtable))

(define (lookup-primitive sym)
  (hashtable-ref *primitives* sym #f))

; is x a call to a primitive? 
(define primcall?
  (lambda (x)
    (and (pair? x) (lookup-primitive (car x)))))

; implementatus of primitive functions are added
; with 'define-primitive'
(define-syntax define-primitive
  (syntax-rules ()
    ((_ (prim-name arg* ...) b b* ...)
     (hashtable-set! *primitives*
                     'prim-name
                     (make-primitive (length '(arg* ...))
                                     (lambda (arg* ...) b b* ...))))))

; implementation of fxadd1
(define-primitive (fxadd1 arg)
  (past::op '(@ (pirop "n_add"))
            (emit-expr arg)
            (emit-expr 1)))

; implementation of fx+
(define-primitive (fx+ arg1 arg2)
  (past::op '(@ (pirop "n_add"))
            (emit-expr arg1)
            (emit-expr arg2)))

; implementation of fxsub1
(define-primitive (fxsub1 arg)
  (past::op
        '(@ (pirop "n_sub"))
        (emit-expr arg)
        (emit-expr 1)))

; implementation of fx-
(define-primitive (fx- arg1 arg2)
  (past::op '(@ (pirop "n_sub"))
            (emit-expr arg1)
            (emit-expr arg2)))

; implementation of fxlogand
(define-primitive (fxlogand arg1 arg2)
  (past::op '(@ (pirop "n_band"))
            (emit-expr arg1)
            (emit-expr arg2)))

; implementation of fxlogor
(define-primitive (fxlogor arg1 arg2)
  (past::op '(@ (pirop "n_bor"))
            (emit-expr arg1)
            (emit-expr arg2)))

; implementation of char->fixnum
(define-primitive (char->fixnum arg)
  (past::op '(@ (pasttype "inline")
                (inline "new %r, 'EclectusFixnum'\\nassign %r, %0\\n"))
            (emit-expr arg)))

; implementation of fixnum->char
(define-primitive (fixnum->char arg)
  (past::op '(@ (pasttype "inline")
                (inline "new %r, 'EclectusCharacter'\\nassign %r, %0\\n"))
            (emit-expr arg)))

; implementation of cons
(define-primitive (cons arg1 arg2)
  (past::var '(@ (viviself "EclectusPair")
                 (name "%dummy")
                 (isdecl 1)
                 (scope "lexical"))
             (past::op '(@ (name "infix:,"))
                       (emit-expr arg1)
                       (emit-expr arg2))))

; implementation of car
(define-primitive (car arg)
  (past::op '(@ (pasttype "inline")
                (inline "%r = %0.'key'()\\n"))
            (emit-expr arg)))

; implementation of cdr
(define-primitive (cdr arg)
  (past::val '(@ (value 31)
                 (returns "EclectusFixnum"))))

(define emit-comparison
  (lambda (builtin arg1 arg2)
    (past::op '(@ (pasttype "if"))
              (past::op (quasiquote (@ (pasttype "chain")
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



; asking for the type of an object
(define emit-typequery
  (lambda (typename arg)
    (past::op
     '(@ (pasttype "if"))
     (past::op
      (quasiquote (@ (pasttype "inline")
                     (inline (unquote (format #f "new %r, 'EclectusBoolean'\\nisa $I1, %0, '~a'\\n %r = $I1" typename)))))
      (emit-expr arg))
     (emit-expr #t)
     (emit-expr #f))))
   
(define-primitive (boolean? arg)
  (emit-typequery "EclectusBoolean" arg))

(define-primitive (char? arg)
  (emit-typequery "EclectusCharacter" arg))

(define-primitive (null? arg)
  (emit-typequery "EclectusEmptyList" arg))

(define-primitive (fixnum? arg)
  (emit-typequery "EclectusFixnum" arg))

(define-primitive (pair? arg)
  (emit-typequery "EclectusPair" arg))



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
    (let ((prim (lookup-primitive (car x))) (args (cdr x)))
      (apply (primitive-emitter prim) args))))

(define emit-functional-application
  (lambda (x)
    (append
      (past::op '(@ (pasttype "call"))
                (emit-expr (car x)))
      (map
       (lambda (arg)
         (emit-expr arg))
       (cdr x)))))

(define (emit-variable x)
  (past::var `(@ (name ,x)
                 (scope "lexical")
                 (viviself "Undef"))))

(define (emit-constant x)
  (past::val
   (cond
    ((fixnum? x)
     (quasiquote (@ (value (unquote x))
                    (returns "EclectusFixnum"))))
    ((char? x)
     (quasiquote (@ (value (unquote (char->integer x)))
                    (returns "EclectusCharacter"))))
    ((null? x)
     '(@ (value 0)
         (returns "EclectusEmptyList")))
    ((boolean? x)
     (quasiquote (@ (value (unquote (if x 1 0)))
                    (returns "EclectusBoolean"))))    
    ((string? x)
     (quasiquote (@ (value (unquote (format #f "'~a'" x)))
                    (returns "EclectusString"))))
    ((vector? x)
     (quasiquote (@ (value "'#0()'")
                    (returns "EclectusString")))))))

(define bindings
  (lambda (x)
    (cadr x)))

(define body
  (lambda (x)
    (caddr x)))

(define emit-variable
  (lambda (x)
    (past::var (quasiquote (@ (name (unquote x))
                              (scope "lexical")
                              (viviself "Undef"))))))

(define emit-let
  (lambda (binds body)
    (if (null? binds)
      (emit-expr body)
      (begin
        (append
          (past::stmts
           (map 
            (lambda (decl)
              (past::op
               '(@ (pasttype "copy")
                   (lvalue "1"))
               (past::var
                (quasiquote (@ (name (unquote (car decl)))
                               (scope "lexical")
                               (viviself "Undef")
                               (isdecl 1))))
               (emit-expr (cadr decl))))
            binds))
          (list
           (emit-expr body)))))))

(define emit-if
  (lambda (x)
    (past::op
     '(@ (pasttype "if"))
     (emit-expr (if-test x))
     (emit-expr (if-conseq x))
     (emit-expr (if-altern x)))))

(define emit-lambda
  (lambda (x)  
    ; (write (list "all" x "decl" (cadr x) "stmts" (cddr x) ))(newline)
    (past::block
     (quasiquote (@ (blocktype "declaration")
                    (arity (unquote (length (cadr x))))))
     (past::stmts (map
                   (lambda (decl)
                     (past::var
                      (quasiquote (@ (name (unquote decl))
                                     (scope "parameter")))))
                   (cadr x)))
     (past::stmts (map
                   (lambda (stmt)
                     (emit-expr stmt))
                   (cddr x))))))

(define emit-begin
  (lambda (x)
    (past::stmts (map emit-expr (cdr x)))))

; emir PIR for an expression
(define emit-expr
  (lambda (x)
    ;(diag (format "emit-expr: ~s" x))
    (cond
      ((symbol? x)          (emit-variable x))
      ((quote? x)           (emit-constant (cadr x)))
      ((self-evaluating? x) (emit-constant x))
      ((let? x)             (emit-let (bindings x) (body x)))
      ((if? x)              (emit-if x))
      ((begin? x)           (emit-begin x))
      ((lambda? x)          (emit-lambda x))
      ((primcall? x)        (emit-primcall x))
      (else                 (emit-functional-application x)))))

; transverse the program and rewrite
; "and" can be supported by transformation before compiling
; So "and" is implemented if terms of "if"
;
; Currently a new S-expression is generated,
; as I don't know how to manipulate S-expressions while traversing it
(define preprocess
  (lambda (tree)
    (cond ((atom? tree)
           tree)
          ((eqv? (car tree) 'and) 
           (preprocess
             (cond ((null? (cdr tree)) #t)
                   ((= (length (cdr tree)) 1) (cadr tree))
                   (else (list
                           'if
                           (cadr tree)
                           (cons 'and (cddr tree))
                            #f)))))
          ((eqv? (car tree) 'or) 
           (preprocess
             (cond ((null? (cdr tree)) #f)
                   ((= (length (cdr tree)) 1) (cadr tree))
                   (else (list
                           'if
                           (cadr tree)
                           (cadr tree)
                           (cons 'or (cddr tree)))))))
          ((eqv? (car tree) 'not) 
           (preprocess
             (list 'if (cadr tree) #f #t)))
          ((eqv? (car tree) 'let*) 
           (preprocess
             (if (null? (cadr tree))
                 (cons 'let (cdr tree))
                 (list
                   'let
                   (list (caadr tree))
                   (append
                     (list 'let* (cdadr tree))
                     (cddr tree))))))
          (else
           (map preprocess tree))))) 

; eventually this will become a PIR generator
; for PAST as SXML
; currently it only handles the pushes
(define past-sxml->past-pir
  (lambda (past)
    (let ((uid (gen-unique-id)))
      ;(diag (format "to_pir: ~a" past))
      (emit "
            .local pmc reg_~a
            reg_~a = new '~a'
            " uid uid (symbol->string (car past)))
      (for-each
        (lambda (daughter)
          (if (eq? '@ (car daughter))
            (for-each
              (lambda (key_val)
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
    (past::op
     '(@ (pasttype "call")
         (name "say"))
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
            (preprocess program)))))))
