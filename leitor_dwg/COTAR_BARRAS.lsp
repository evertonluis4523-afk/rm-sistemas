;;; ====================================================================
;;;  RM Estruturas Pre-Fabricadas -- COTAR_BARRAS
;;;  Cota alinhada de cada barra (linha ou trecho reto de polilinha)
;;;  selecionada, no UCS atual. Nao altera a geometria do desenho.
;;;
;;;  COMANDOS
;;;    COTARBARRAS   cota as barras selecionadas
;;;    RMCBVER       mostra a versao carregada
;;;
;;;  O QUE FICA DE FORA (a mesma regra do Corte de Estruturas)
;;;    - suporte de terca: retangulo de 4 linhas que fecha em si mesmo,
;;;      com lados de ate 60 cm e nenhuma outra linha selecionada chegando
;;;      nos cantos;
;;;    - polilinha fechada e polilinha so com trechos de ate 60 cm
;;;      (no modelo RM a polilinha e' representacao: suporte, secao);
;;;    - camadas com SUPORTE ou QUADRO no nome (RM-SUPORTE, RM-QUADRO);
;;;    - trechos curvos, nulos ou fora do plano.
;;;
;;;  TAMANHO DA LETRA
;;;    Sai do tamanho do que foi selecionado (a maior medida / 120) e
;;;    aparece como sugestao: Enter aceita, ou digite outra altura. O
;;;    estilo de cota e' o mesmo; so' a escala dele (DIMSCALE) e' ajustada
;;;    nas cotas criadas, e volta ao que era no fim. A ultima altura usada
;;;    fica lembrada ate fechar o AutoCAD.
;;;
;;;  UNIDADES
;;;    Pela variavel INSUNITS (mm, cm ou m). Sem ela, pelo tamanho: maior
;;;    medida acima de 5000 e' milimetro, senao centimetro.
;;; ====================================================================

(vl-load-com)

;; versao propria (RM-CB-VER): o RM-TELHA.lsp usa RM-VER, e os dois podem
;; estar carregados juntos
(setq RM-CB-VER "1.1")

(defun c:RMCBVER () (princ (strcat "\nCOTAR_BARRAS versao " RM-CB-VER)) (princ))

;; ---- cota de um trecho ----
(defun rmcb:cota (a b afast / dx dy comp meio pos anterior)
  (setq dx (- (car b) (car a)) dy (- (cadr b) (cadr a))
        comp (sqrt (+ (* dx dx) (* dy dy))))
  (if (and (> comp 1e-9) (equal (caddr a) (caddr b) 1e-7))
    (progn
      (setq meio (mapcar '(lambda (x y) (/ (+ x y) 2.0)) a b)
            pos (list (- (car meio) (* afast (/ dy comp)))
                      (+ (cadr meio) (* afast (/ dx comp)))
                      (caddr meio))
            anterior (entlast))
      (command-s "_.DIMALIGNED" "_non" a "_non" b "_non" pos)
      (not (eq anterior (entlast))))
    nil))

;; ---- vertices de uma polilinha 2D: ((ponto bulge) ...) no UCS ----
(defun rmcb:vertices (ent dados / item ponto bulge resultado elev)
  (setq elev (cond ((cdr (assoc 38 dados))) (0.0)) bulge 0.0)
  (foreach item dados
    (cond
      ((= (car item) 10)
        (if ponto (setq resultado (cons (list ponto bulge) resultado)))
        (setq ponto (trans (list (cadr item) (caddr item) elev) ent 1) bulge 0.0))
      ((= (car item) 42) (setq bulge (cdr item)))))
  (if ponto (setq resultado (cons (list ponto bulge) resultado)))
  (reverse resultado))

(defun rmcb:dist (a b) (distance (list (car a) (cadr a)) (list (car b) (cadr b))))

;; ---- unidade do desenho: fator para converter milimetro ----
(defun rmcb:fator (maior / u)
  (setq u (getvar "INSUNITS"))
  (cond ((= u 4) 1.0)          ; mm
        ((= u 5) 0.1)          ; cm
        ((= u 6) 0.001)        ; m
        ((> maior 5000.0) 1.0) ; sem unidade: grande e' mm
        (T 0.1)))              ; senao cm (o 2D da RM)

(defun rmcb:camada-fora (dados / lay)
  (setq lay (strcase (cdr (assoc 8 dados))))
  (or (wcmatch lay "*SUPORTE*") (wcmatch lay "*QUADRO*")))

;; ---- suportes de terca entre as LINHAS selecionadas ----
;; lins: lista de (ent a b). Devolve a lista de ent que sao suporte.
(defun rmcb:suportes (lins tol maxlado / naponta fora vistos ciclo p ant ok n ls prox)
  (defun naponta (p / r)
    (foreach l lins
      (if (or (< (rmcb:dist (cadr l) p) tol) (< (rmcb:dist (caddr l) p) tol))
        (setq r (cons l r))))
    r)
  (setq fora '() vistos '())
  (foreach l0 lins
    (if (not (member (car l0) vistos))
      (progn
        (setq ciclo (list l0) p (caddr l0) ant l0 ok T n 0)
        (while (and ok (< n 4))
          (setq ls (naponta p))
          (if (or (/= (length ls) 2) (not (member ant ls)))
            (setq ok nil)
            (progn
              (setq prox (if (eq (car (car ls)) (car ant)) (cadr ls) (car ls)))
              (cond
                ((eq (car prox) (car l0)) (setq ok (= (length ciclo) 4) n 4))
                ((= n 3) (setq ok nil))
                (T
                  (setq p (if (< (rmcb:dist (cadr prox) p) tol) (caddr prox) (cadr prox))
                        ciclo (cons prox ciclo) ant prox))))
          )
          (setq n (1+ n)))
        (if (and ok (= (length ciclo) 4)
                 (vl-every '(lambda (g) (<= (rmcb:dist (cadr g) (caddr g)) maxlado)) ciclo))
          (foreach g ciclo (setq fora (cons (car g) fora) vistos (cons (car g) vistos)))))))
  fora)

(defun c:COTARBARRAS (/ *error* eco snap escOrig grupo ss afast altura sugerida fator maxlado tol
                       i ent dados tipo lins pols mn mx maior sup vertices seq primeiro atual proximo
                       n ignoradas suportes txt curtos p)
  (setq eco (getvar "CMDECHO") snap (getvar "OSMODE") escOrig (getvar "DIMSCALE")
        grupo nil n 0 ignoradas 0 suportes 0)
  (defun *error* (msg)
    (if grupo (command-s "_.UNDO" "_End"))
    (setvar "DIMSCALE" escOrig) (setvar "CMDECHO" eco) (setvar "OSMODE" snap)
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*,*BREAK*")))
      (princ (strcat "\nErro: " msg)))
    (princ "\nOperacao encerrada. U desfaz as cotas criadas nesta execucao.")
    (princ))
  (princ "\nSelecione as barras (linhas ou polilinhas 2D): ")
  (setq ss (ssget '((0 . "LINE,LWPOLYLINE"))))
  (if (null ss)
    (princ "\nNenhuma barra selecionada.")
    (progn
      ;; separa linhas e polilinhas, mede a extensao da selecao
      (setq i 0 lins '() pols '())
      (repeat (sslength ss)
        (setq ent (ssname ss i) dados (entget ent) i (1+ i) tipo (cdr (assoc 0 dados)))
        (cond
          ((rmcb:camada-fora dados) (setq suportes (1+ suportes)))
          ((= tipo "LINE")
            (setq lins (cons (list ent (trans (cdr (assoc 10 dados)) 0 1) (trans (cdr (assoc 11 dados)) 0 1)) lins)))
          (T (setq pols (cons (list ent dados) pols)))))
      (foreach l lins
        (foreach p (list (cadr l) (caddr l))
          (setq mn (if mn (list (min (car mn) (car p)) (min (cadr mn) (cadr p))) (list (car p) (cadr p)))
                mx (if mx (list (max (car mx) (car p)) (max (cadr mx) (cadr p))) (list (car p) (cadr p))))))
      (foreach pl pols
        (foreach v (rmcb:vertices (car pl) (cadr pl))
          (setq p (car v)
                mn (if mn (list (min (car mn) (car p)) (min (cadr mn) (cadr p))) (list (car p) (cadr p)))
                mx (if mx (list (max (car mx) (car p)) (max (cadr mx) (cadr p))) (list (car p) (cadr p))))))
      (setq maior (if mn (max (- (car mx) (car mn)) (- (cadr mx) (cadr mn))) 1.0)
            fator (rmcb:fator maior)
            maxlado (* 600.0 fator)       ; 60 cm na unidade do desenho
            tol (* 3.0 fator))            ; 3 mm
      ;; altura da letra
      (setq sugerida (cond (RM-CB-ALTURA) ((/ maior 120.0))))
      (initget 6)
      (setq altura (getdist (strcat "\nAltura da letra das cotas <" (rtos sugerida 2 2) ">: ")))
      (if (null altura) (setq altura sugerida))
      (setq RM-CB-ALTURA altura)
      (initget 6)
      (setq afast (getdist (strcat "\nAfastamento das cotas <" (rtos (* 2.0 altura) 2 2) ">: ")))
      (if (null afast) (setq afast (* 2.0 altura)))
      ;; suportes de terca entre as linhas
      (setq sup (rmcb:suportes lins tol maxlado) suportes (+ suportes (length sup)))
      (setvar "CMDECHO" 0) (setvar "OSMODE" 0)
      (setvar "DIMSCALE" (/ altura (max (getvar "DIMTXT") 1e-6)))
      (command-s "_.UNDO" "_Begin") (setq grupo T)
      (foreach l lins
        (if (not (member (car l) sup))
          (if (rmcb:cota (cadr l) (caddr l) afast) (setq n (1+ n)) (setq ignoradas (1+ ignoradas)))))
      (foreach pl pols
        (setq dados (cadr pl) vertices (rmcb:vertices (car pl) dados) primeiro (car vertices)
              txt (= 1 (logand 1 (cdr (assoc 70 dados)))))
        ;; polilinha fechada ou so de trechos curtos: suporte/secao, fica de fora
        (setq curtos T seq vertices)
        (while (cadr seq)
          (if (> (rmcb:dist (car (car seq)) (car (cadr seq))) maxlado) (setq curtos nil))
          (setq seq (cdr seq)))
        (if (or txt curtos)
          (setq suportes (1+ suportes))
          (progn
            (setq seq vertices)
            (while seq
              (setq atual (car seq) proximo (cadr seq))
              (if proximo
                (if (and (equal (cadr atual) 0.0 1e-12) (rmcb:cota (car atual) (car proximo) afast))
                  (setq n (1+ n)) (setq ignoradas (1+ ignoradas))))
              (setq seq (cdr seq))))))
      (command-s "_.UNDO" "_End") (setq grupo nil)
      (setvar "DIMSCALE" escOrig) (setvar "CMDECHO" eco) (setvar "OSMODE" snap)
      (princ (strcat "\n" (itoa n) " cotas criadas. "
                     (itoa suportes) " suporte(s) de terca, polilinha(s) fechada(s) ou camada de suporte/quadro deixados de fora. "
                     (itoa ignoradas) " trecho(s) curvo(s), nulo(s) ou fora do plano ignorado(s)."))
      (princ "\nSe precisar, U desfaz esta execucao.")))
  (princ))

(princ (strcat "\nCOTAR_BARRAS " RM-CB-VER " carregada. Digite COTARBARRAS para iniciar."))
(princ)
