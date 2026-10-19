;;; ====================================================================
;;;  RM Estruturas Pre-Fabricadas -- conferencia de telhas no AutoCAD
;;;  Nunes & Kuhn Estruturas Metalicas Ltda -- Estrela/RS
;;;
;;;  Companheiro do sistema "Corte e Estrutura": desenha e cota o mesmo
;;;  esboco que o sistema le, nas mesmas camadas do DXF de conferencia.
;;;  Assim o que sai do sistema cai por cima do que ele desenhou.
;;;
;;;  COMANDOS
;;;    TL    preenche a face de telha em telha e cota cada linha
;;;    TLC   cota linhas que ja existem, e resume (conferencia)
;;;    TLS   confere se as duas metades da face batem
;;;
;;;  COMO CARREGAR
;;;    APPLOAD, aponte para este arquivo. Para nao repetir toda vez,
;;;    APPLOAD > Contents... (Inicializacao) e adicione o arquivo.
;;;
;;;  UNIDADES
;;;    Trabalha na unidade do desenho. Os desenhos de fechamento da RM
;;;    estao em MILIMETROS, entao o passo padrao e' 980 e a letra 140.
;;;    Em desenho de centimetro, informe 98 e 14.
;;; ====================================================================

(vl-load-com)

;; ---- versao ----
;; Existe por um motivo pratico: ja foram varios arquivos, e quando alguma
;; coisa "continua dando o mesmo problema" a primeira pergunta e' QUAL codigo
;; esta rodando. O AutoCAD guarda o que carregou ate fechar, e a lista de
;; inicializacao pode estar apontando para um arquivo velho na pasta de
;; downloads. O numero aparece ao carregar, no RMTESTE e no fim de cada TL.
(setq RM-VER "7")
(setq RM-VER-NOTA "acha a cumeeira sozinho + RMONDE")

;;; --------------------------------------------------------------------
;;;  utilidades
;;; --------------------------------------------------------------------

;; Camada com a mesma cor do DXF que o sistema gera, para os dois
;; desenhos ficarem visualmente iguais quando sobrepostos.
(defun rm:camada (nome cor)
  (if (not (tblsearch "LAYER" nome))
    (entmake (list '(0 . "LAYER")
                   '(100 . "AcDbSymbolTableRecord")
                   '(100 . "AcDbLayerTableRecord")
                   (cons 2 nome) (cons 70 0) (cons 62 cor)
                   (cons 6 "CONTINUOUS"))))
  nome)

(defun rm:linha (a b lay)
  (entmake (list '(0 . "LINE") (cons 8 lay)
                 (cons 10 (list (car a) (cadr a) 0.0))
                 (cons 11 (list (car b) (cadr b) 0.0)))))

;; Texto centrado no ponto: 72=1 (centro) e 73=2 (meio) exigem que 10 e
;; 11 sejam o MESMO ponto -- sem isso o texto pula para a origem.
(defun rm:texto (p alt s ang lay)
  (entmake (list '(0 . "TEXT") (cons 8 lay)
                 (cons 10 (list (car p) (cadr p) 0.0))
                 (cons 11 (list (car p) (cadr p) 0.0))
                 (cons 40 alt) (cons 1 s) (cons 50 ang)
                 (cons 72 1) (cons 73 2))))

;; Quanto o ponto q anda na direcao dir, contado a partir de base.
(defun rm:proj (q base dir)
  (+ (* (- (car q) (car base)) (car dir))
     (* (- (cadr q) (cadr base)) (cadr dir))))

(defun rm:esc (v k) (list (* (car v) k) (* (cadr v) k) 0.0))

;; Todos os cruzamentos de um sensor (reta que passa por p na direcao
;; dir) com os objetos escolhidos. O sensor e' uma linha de verdade,
;; criada e apagada na hora: IntersectWith so' aceita objeto contra
;; objeto, e assim funciona com LINE, LWPOLYLINE, ARC e o que mais ele
;; tiver usado no contorno.
(defun rm:cruza (p dir lim objs / a b e o r res)
  (setq a   (mapcar '- p (rm:esc dir lim))
        b   (mapcar '+ p (rm:esc dir lim))
        res '())
  (entmake (list '(0 . "LINE")
                 (cons 10 (list (car a) (cadr a) 0.0))
                 (cons 11 (list (car b) (cadr b) 0.0))))
  (setq e (entlast)
        o (vlax-ename->vla-object e))
  (foreach ob objs
    (setq r (vl-catch-all-apply 'vlax-invoke (list o 'IntersectWith ob 0)))
    (if (and r (not (vl-catch-all-error-p r)))
      (while (>= (length r) 3)
        (setq res (cons (list (car r) (cadr r) 0.0) res)
              r   (cdddr r)))))
  (entdel e)
  res)

;; O par mais afastado, medido ao longo de dir. E' o que vira a linha:
;; do ponto mais baixo do contorno ate o mais alto, naquela estacao.
(defun rm:extremos (pts base dir / a b da db d)
  (foreach q pts
    (setq d (rm:proj q base dir))
    (if (or (null a) (< d da)) (setq a q da d))
    (if (or (null b) (> d db)) (setq b q db d)))
  (if (and a b) (list a b)))

;; A caixa que envolve tudo o que ele selecionou: (x0 y0 x1 y1). E' o que
;; diz ate onde a face vai, para o preenchimento nao depender de um segundo
;; clique -- que era justamente onde dava para errar e deixar meia face
;; vazia sem o comando reclamar.
(defun rm:caixa (objs / mn mx p q x0 y0 x1 y1 r)
  (foreach o objs
    (setq r (vl-catch-all-apply 'vla-GetBoundingBox (list o 'mn 'mx)))
    (if (not (vl-catch-all-error-p r))
      (progn
        (setq p (vlax-safearray->list mn)
              q (vlax-safearray->list mx))
        (if (or (null x0) (< (car p)  x0)) (setq x0 (car p)))
        (if (or (null y0) (< (cadr p) y0)) (setq y0 (cadr p)))
        (if (or (null x1) (> (car q)  x1)) (setq x1 (car q)))
        (if (or (null y1) (> (cadr q) y1)) (setq y1 (cadr q))))))
  (if (and x0 y0 x1 y1) (list x0 y0 x1 y1)))

;; initget 6 = nem zero nem negativo; ENTER devolve nil e fica o padrao
(defun rm:pergunta-num (msg padrao / v)
  (initget 6)
  (setq v (getreal (strcat "\n" msg " <" (rtos padrao 2 2) ">: ")))
  (if v v padrao))

;; Uma marca de desfazer por comando: sem isto, preencher uma face de
;; 50 m deixa umas 100 entidades soltas no historico e desfazer vira
;; Ctrl+Z cem vezes.
(defun rm:doc ()
  (if (null *rm-doc*)
    (setq *rm-doc* (vla-get-ActiveDocument (vlax-get-acad-object))))
  *rm-doc*)
(defun rm:abre () (vla-StartUndoMark (rm:doc)))
(defun rm:fecha () (vla-EndUndoMark (rm:doc)))

;;; --------------------------------------------------------------------
;;;  TL -- preenche a face inteira e cota cada linha
;;;
;;;  E' o desenho que ele ja faz a mao: da cumeeira para fora, uma linha a
;;;  cada largura util, cada uma parando na agua, com a medida deitada em
;;;  cima dela. A montagem comeca no centro da tesoura e vai para as duas
;;;  pontas -- entao o comando faz os DOIS lados de uma vez.
;;;
;;;  Na primeira versao ele pedia o inicio E a ponta, e a ponta era a chance
;;;  de errar: bastou o segundo clique cair fora do lugar para meia face sair
;;;  vazia, sem o comando reclamar de nada. Agora o unico ponto pedido e' a
;;;  CUMEEIRA -- de onde a montagem sai -- e ate onde ir sai do proprio
;;;  contorno selecionado. Nao ha segundo clique para errar.
;;;
;;;  Do clique so' o X importa: a linha e' vertical e vai de onde cruza a
;;;  base ate onde cruza a agua. Clicar no vertice la em cima da cumeeira ou
;;;  no pe dela da no mesmo.
;;; --------------------------------------------------------------------

;; So' a altura do contorno em x, sem desenhar nada. E' o que permite
;; procurar a cumeeira.
(defun rm:altura (x y0 y1 lim objs / base perp ex)
  (setq base (list x (/ (+ y0 y1) 2.0) 0.0)
        perp (list 0.0 1.0 0.0)
        ex   (rm:extremos (rm:cruza base perp lim objs) base perp))
  (if ex (distance (car ex) (cadr ex)) 0.0))

;; ---- acha a cumeeira sozinho ----
;; Ele clica no olho e erra por alguns centimetros. Num desenho de 50 m numa
;; tela de 1200 pixels, 350 mm sao OITO PIXELS -- nao ha como acertar a mao.
;; E a cumeeira nao admite aproximacao: a grade inteira nasce dela, entao
;; errar ali joga a fila toda de lado e a cota do meio sai 3756 em vez de
;; 3800. Aconteceu no OITAO dele, exatamente assim.
;;
;; O ponto mais alto do contorno E' a cumeeira, e o sistema sabe medir altura.
;; Entao procura: uma varredura grossa numa largura util para cada lado do
;; clique, depois duas mais finas em cima do melhor. Termina com 1 mm.
;;
;; Face de topo reto (parede sem agua) nao tem um ponto mais alto -- todos
;; empatam. Como so' troca quando encontra ALGO MAIS ALTO, o empate mantem o
;; clique dele, que e' o certo ali.
(defun rm:acha-cume (x y0 y1 lim objs janela / passo base xx melhor hm h i)
  (setq melhor x
        hm     (rm:altura x y0 y1 lim objs)
        passo  (/ janela 10.0))
  ;; quatro passadas: 98 / 9,8 / 0,98 / 0,098 numa largura util de 980.
  ;; Termina em centesimo de milimetro, que e' mais fino do que qualquer
  ;; desenho de galpao precisa.
  (repeat 4
    (setq base melhor i -10)
    (while (<= i 10)
      (setq xx (+ base (* i passo))
            h  (rm:altura xx y0 y1 lim objs))
      (if (> h hm) (setq hm h melhor xx))
      (setq i (1+ i)))
    (setq passo (/ passo 10.0)))
  melhor)

;; Uma estacao: sobe a vertical em x, acha onde ela corta o contorno e
;; desenha a linha com a cota. Devolve o COMPRIMENTO que cotou, ou 0 se
;; nao havia contorno ali -- o comprimento serve para o relatorio dizer
;; quanto mede a cumeeira e a primeira telha de cada lado.
(defun rm:trilho (x y0 y1 lim objs lay1 lay2 lado / base perp pts ex a b comp meio)
  (setq base (list x (/ (+ y0 y1) 2.0) 0.0)
        perp (list 0.0 1.0 0.0)
        pts  (rm:cruza base perp lim objs)
        ex   (rm:extremos pts base perp))
  (cond
    ((null ex) 0)
    (t
     (setq a (car ex) b (cadr ex) comp (distance a b))
     (cond
       ((<= comp 1.0) 0)
       (t
        (rm:linha a b lay1)
        ;; a cota fica deitada NA linha, um pouco para o lado, para nao
        ;; ficar exatamente em cima dela
        (setq meio (list (+ (car a) (* (if (< lado 0.0) -0.7 0.7) *rm-alt*))
                         (/ (+ (cadr a) (cadr b)) 2.0) 0.0))
        (rm:texto meio *rm-alt* (rtos comp 2 0) (/ pi 2.0) lay2)
        (atoi (rtos comp 2 0)))))))

(defun c:TL ( / ss objs i n pc xc cx x0 y0 x1 y1 lim lado bons vazios v
                cume pri1D pri1E sobraD sobraE lay1 lay2 marca op tol)
  (if (null *rm-passo*) (setq *rm-passo* 980.0))
  (if (null *rm-alt*)   (setq *rm-alt*   140.0))
  (setq lay1 (rm:camada "RM-TELHA"    3)
        lay2 (rm:camada "RM-TEL-COTA" 5))
  (prompt "\nSelecione o CONTORNO da face -- base, as duas aguas e as pontas -- e ENTER: ")
  (setq ss (ssget (list (cons 0 "LINE,LWPOLYLINE,POLYLINE,ARC,CIRCLE,SPLINE"))))
  (cond
    ((null ss) (prompt "\nNada selecionado.") (princ))
    (t
     (setq objs (list) i 0 n (sslength ss))
     (while (< i n)
       (setq objs (cons (vlax-ename->vla-object (ssname ss i)) objs)
             i    (1+ i)))
     (setq cx (rm:caixa objs))
     (cond
       ((null cx) (prompt "\nNao consegui medir a face selecionada.") (princ))
       (t
        (setq x0 (car cx) y0 (cadr cx) x1 (caddr cx) y1 (cadddr cx))
        (prompt (strcat "\nFace de " (rtos (- x1 x0) 2 1) " por " (rtos (- y1 y0) 2 1) "."))
        (setq pc (getpoint "\nClique na CUMEEIRA (de onde a montagem comeca): "))
        (cond
          ((null pc) (prompt "\nCancelado.") (princ))
          ((or (< (car pc) (- x0 1.0)) (> (car pc) (+ x1 1.0)))
           (prompt "\nEsse ponto esta FORA da face que voce selecionou -- nada foi desenhado.")
           (princ))
          (t
           (setq *rm-passo* (rm:pergunta-num "Largura util (passo)" *rm-passo*))
           (setq *rm-alt*   (rm:pergunta-num "Altura da letra"      *rm-alt*))
           ;; A cumeeira E' a primeira cota, e nao um extra opcional: a
           ;; montagem sai dela, e a primeira telha de cada agua encosta
           ;; nela. Eu tinha deixado esta pergunta com <Nao> por causa do
           ;; montante ja desenhado no contorno -- mas o que ele quer nao e'
           ;; a linha, e' a MEDIDA da cumeeira abrindo a sequencia. Agora o
           ;; padrao e' Sim, e so' sai fora se ele disser Nao.
           (initget "Sim Nao")
           (setq op    (getkword "\nCotar tambem a propria cumeeira (a linha central)? [Sim/Nao] <Sim>: ")
                 marca (/= op "Nao"))
           (setq lim (max (* 5.0 (- y1 y0)) 100000.0))
           ;; o clique so' aponta a regiao; quem acha a cumeeira e' a medida
           (setq xc (rm:acha-cume (car pc) y0 y1 lim objs *rm-passo*))
           (cond
             ((<= (rm:altura xc y0 y1 lim objs) 1.0)
              (prompt "\nNao achei contorno nenhum ali. Confira se a base e as aguas")
              (prompt "\nentraram na selecao."))
             (t
              (if (> (abs (- xc (car pc))) 0.5)
                (prompt (strcat "\n(voce clicou em " (rtos (car pc) 2 1)
                                "; o ponto mais alto esta em " (rtos xc 2 1)
                                " -- ajustei " (rtos (abs (- xc (car pc))) 2 1) ")")))))
           (rm:abre)
           (setq tol    0.5
                 bons   0
                 vazios 0
                 sobraD 0.0
                 sobraE 0.0)
           ;; A CUMEEIRA PRIMEIRO: e' dela que a montagem sai, e a cota dela
           ;; abre a sequencia dos dois lados.
           (if marca
             (progn
               (setq cume (rm:trilho xc y0 y1 lim objs lay1 lay2 1.0))
               (if (> cume 0) (setq bons (1+ bons)))))
           ;; e dali para a DIREITA e para a ESQUERDA, ate onde o contorno for
           (foreach lado (list 1.0 -1.0)
             (setq i 1)
             (while (and (<= (+ xc (* lado i *rm-passo*)) (+ x1 tol))
                         (>= (+ xc (* lado i *rm-passo*)) (- x0 tol)))
               (setq v (rm:trilho (+ xc (* lado i *rm-passo*))
                                  y0 y1 lim objs lay1 lay2 lado))
               (if (> v 0) (setq bons (1+ bons)) (setq vazios (1+ vazios)))
               (if (= i 1) (if (> lado 0.0) (setq pri1D v) (setq pri1E v)))
               (setq i (1+ i)))
             (if (> lado 0.0)
               (setq sobraD (- x1 (+ xc (* (1- i) *rm-passo*))))
               (setq sobraE (- (- xc (* (1- i) *rm-passo*)) x0))))
           (rm:fecha)
           (prompt (strcat "\n[RM-TELHA v" RM-VER "] " (itoa bons)
                           " linha(s) desenhada(s) e cotada(s)."))
           (prompt (strcat "\nDa cumeeira"
                           (if (and marca cume (> cume 0))
                             (strcat " (" (itoa cume) ")") "")
                           " para fora, a cada " (rtos *rm-passo* 2 1)
                           ": primeira a esquerda " (if pri1E (itoa pri1E) "-")
                           ", primeira a direita " (if pri1D (itoa pri1D) "-") "."))
           (prompt (strcat "\nCumeeira em " (rtos xc 2 1)
                           " -- para a esquerda " (rtos (- xc x0) 2 1)
                           ", para a direita "    (rtos (- x1 xc) 2 1) "."))
           (prompt (strcat "\nSobra ate a ponta: esquerda " (rtos sobraE 2 1)
                           ", direita " (rtos sobraD 2 1)
                           " -- sao as telhas estreitas do fim de cada agua."))
           (if (> vazios 0)
             (prompt (strcat "\n>>> " (itoa vazios) " posicao(oes) ficaram sem linha: ali a"
                             "\n    vertical nao cruzou o contorno em dois pontos. Falta"
                             "\n    selecionar alguma linha da base ou da agua.")))
           (princ))))))))

;;; --------------------------------------------------------------------
;;;  TLC -- cota o que ja esta desenhado, e resume
;;;
;;;  Para o desenho que ja existe: seleciona as linhas e ele escreve a
;;;  medida de cada uma e diz quantas sao, quantas medidas DIFERENTES
;;;  existem e qual a maior e a menor. E' a conferencia rapida antes de
;;;  mandar para o sistema.
;;; --------------------------------------------------------------------
(defun c:TLC ( / ss i n e d a b comp ang meio lay lista mn mx dif chave achou)
  (if (null *rm-alt*) (setq *rm-alt* 140.0))
  (prompt "\nSelecione as linhas a cotar e ENTER: ")
  (setq ss (ssget '((0 . "LINE"))))
  (cond
    ((null ss) (prompt "\nNenhuma linha selecionada.") (princ))
    (t
     (setq *rm-alt* (rm:pergunta-num "Altura da letra" *rm-alt*))
     (rm:abre)
     (setq lay (rm:camada "RM-TEL-COTA" 5)
           i 0 n (sslength ss) lista '())
     (while (< i n)
       (setq d    (entget (ssname ss i))
             a    (cdr (assoc 10 d))
             b    (cdr (assoc 11 d))
             comp (distance a b))
       (if (> comp 1.0)
         (progn
           ;; texto deitado ao longo da propria linha, como ele cota
           (setq ang (atan (- (cadr b) (cadr a)) (- (car b) (car a))))
           ;; sempre lendo de baixo para cima / da esquerda para a
           ;; direita: texto de cabeca para baixo ninguem le na obra
           (if (or (> ang (/ pi 2.0)) (<= ang (- (/ pi 2.0))))
             (setq ang (+ ang pi)))
           (setq meio (list (/ (+ (car a)  (car b))  2.0)
                            (/ (+ (cadr a) (cadr b)) 2.0) 0.0))
           (rm:texto meio *rm-alt* (rtos comp 2 0) ang lay)
           (setq chave (atoi (rtos comp 2 0))
                 lista (cons chave lista))))
       (setq i (1+ i)))
     (rm:fecha)
     (cond
       ((null lista) (prompt "\nNenhuma linha com comprimento util.") (princ))
       (t
        (setq mn (apply 'min lista) mx (apply 'max lista) dif '())
        (foreach v lista (if (not (member v dif)) (setq dif (cons v dif))))
        (prompt (strcat "\n" (itoa (length lista)) " linha(s) cotada(s)."
                        "\nMedidas diferentes: " (itoa (length dif))
                        "   menor " (itoa mn) "   maior " (itoa mx)))
        (if (= (length dif) 1)
          (prompt "\nTodas iguais.")
          (prompt "\nMedidas repetidas sao telhas do mesmo comprimento no pedido."))
        (princ))))))

;;; --------------------------------------------------------------------
;;;  TLS -- as duas metades da face batem?
;;;
;;;  Nasceu de um caso real: o OITAO do galpao Refricomp saia no pedido
;;;  com os comprimentos variando 1 mm e a tira da ponta com 497 de um
;;;  lado contra 500 do outro. Estavam 2,5 mm no desenho -- as duas
;;;  aguas terminavam em x diferentes (29.050 e 29.052,5) e o montante
;;;  da cumeeira estava entortado. Ninguem ve 2,5 mm num desenho de
;;;  50 m; a maquina ve, porque le a coordenada.
;;;
;;;  Pede os tres pontos que definem a face -- ponta, cumeeira, ponta --
;;;  e diz se as metades sao iguais. Use OSNAP em ENDPOINT.
;;; --------------------------------------------------------------------
(defun c:TLS ( / pe pc pd esq dir d dy)
  (setq pe (getpoint "\nPonta ESQUERDA da face (endpoint): "))
  (if pe (setq pc (getpoint pe "\nCUMEEIRA (endpoint): ")))
  (if pc (setq pd (getpoint pc "\nPonta DIREITA da face (endpoint): ")))
  (cond
    ((or (null pe) (null pc) (null pd)) (prompt "\nCancelado.") (princ))
    (t
     (setq esq (abs (- (car pc) (car pe)))
           dir (abs (- (car pd) (car pc)))
           d   (abs (- dir esq))
           dy  (abs (- (cadr pd) (cadr pe))))
     (prompt (strcat "\nEsquerda da cumeeira: " (rtos esq 2 2)
                     "\nDireita  da cumeeira: " (rtos dir 2 2)
                     "\nLargura total:        " (rtos (+ esq dir) 2 2)))
     (if (< d 0.01)
       (prompt "\nAs duas metades batem.")
       (prompt (strcat "\n>>> DIFERENCA DE " (rtos d 2 2)
                       " entre as metades. E' daqui que vem a medida que nao"
                       "\n    espelha no pedido. Procure a cumeeira desenhada"
                       "\n    em dois x, ou o montante do meio entortado.")))
     (if (>= dy 0.01)
       (prompt (strcat "\n>>> As duas pontas tambem estao em alturas diferentes: "
                       (rtos dy 2 2) ".")))
     (princ))))

;;; --------------------------------------------------------------------
;;;  Nomes longos, alem dos curtos.
;;;
;;;  TL, TLC e TLS sao curtos de proposito -- e' o que se digita cem vezes
;;;  por dia. Mas nome curto e' justamente o que colide com apelido do
;;;  acad.pgp ou de outro LISP ja carregado, e ai o comando "some" sem
;;;  explicacao. Os nomes longos nao colidem com nada.
;;; --------------------------------------------------------------------
;;; --------------------------------------------------------------------
;;;  RMONDE -- onde estao as copias deste arquivo, e qual a versao de cada
;;;
;;;  O problema que mais custou tempo aqui nao foi codigo: foi copia velha.
;;;  Cada baixada vira RM-TELHA (1).lsp, (2), (3) na pasta de downloads, a
;;;  lista de inicializacao aponta para uma delas, e o AutoCAD carrega a
;;;  antiga por cima da nova sem avisar. Do lado de dentro nao da' para saber
;;;  de onde veio o que esta na memoria -- mas da' para VER o que existe no
;;;  disco. Ele apaga o que sobra e acaba a duvida.
;;; --------------------------------------------------------------------
(defun rm:ver-arq (caminho / f l p q v)
  (if (setq f (open caminho "r"))
    (progn
      (while (and (null v) (setq l (read-line f)))
        (if (vl-string-search "setq RM-VER " l)
          (progn
            (setq p (vl-string-search "\"" l))
            (if p
              (progn
                (setq q (vl-string-search "\"" l (1+ p)))
                (if q (setq v (substr l (+ p 2) (- q p 1)))))))))
      (close f)))
  (if v v "antiga, sem numero"))
(defun rm:data-arq (caminho / d)
  (if (setq d (vl-file-systime caminho))
    (strcat (itoa (nth 3 d)) "/" (itoa (cadr d)) "/" (itoa (car d)) " "
            (itoa (nth 4 d)) "h" (if (< (nth 5 d) 10) "0" "") (itoa (nth 5 d)))
    "?"))
(defun c:RMONDE ( / casa pastas arqs n)
  (setq casa (if (getenv "USERPROFILE")
               (vl-string-translate "\\" "/" (getenv "USERPROFILE")) "C:")
        pastas (list "C:/RM/"
                     (strcat casa "/Downloads/")
                     (strcat casa "/Desktop/")
                     (strcat casa "/Documents/")
                     (strcat casa "/OneDrive/Downloads/")
                     (strcat casa "/OneDrive/Desktop/"))
        n 0)
  (prompt (strcat "\n====================================================="
                  "\n Na memoria agora: VERSAO " RM-VER
                  "\n Copias no disco:"))
  (foreach p pastas
    (setq arqs (vl-directory-files p "RM-TELHA*.lsp" 1))
    (foreach a arqs
      (setq n (1+ n))
      (prompt (strcat "\n   " p a
                      "\n      versao " (rm:ver-arq (strcat p a))
                      "   -   " (rm:data-arq (strcat p a))))))
  (if (= n 0)
    (prompt "\n   (nao achei nenhuma nas pastas de sempre)")
    (if (> n 1)
      (prompt (strcat "\n\n >>> " (itoa n) " copias. APAGUE as que nao forem a mais nova."
                      "\n     Enquanto houver mais de uma, o AutoCAD pode carregar a velha."))))
  (prompt "\n=====================================================")
  (princ))

;;; --------------------------------------------------------------------
;;;  RMLIMPA -- apaga o que os comandos desenharam
;;;
;;;  Refazer e' normal: erra o clique da cumeeira, muda a largura util,
;;;  quer testar 1000 em vez de 980. Sem isto sobra o preenchimento antigo
;;;  por baixo do novo e o desenho vira um bolo -- foi o que aconteceu na
;;;  primeira tentativa dele. So' mexe nas DUAS camadas do LISP; o contorno
;;;  que ele desenhou nao e' tocado.
;;; --------------------------------------------------------------------
(defun c:RMLIMPA ( / ss n)
  (setq ss (ssget "_X" (list (cons 8 "RM-TELHA,RM-TEL-COTA"))))
  (cond
    ((null ss) (prompt "\nNao ha nada nas camadas RM-TELHA e RM-TEL-COTA.") (princ))
    (t
     (setq n (sslength ss))
     (initget "Sim Nao")
     (if (= "Sim" (getkword (strcat "\nApagar " (itoa n)
                                    " objeto(s) das camadas RM-TELHA e RM-TEL-COTA?"
                                    " [Sim/Nao] <Nao>: ")))
       (progn
         (rm:abre)
         (command "_.ERASE" ss "")
         (rm:fecha)
         (prompt (strcat "\n" (itoa n) " objeto(s) apagado(s). O contorno ficou.")))
       (prompt "\nNada apagado."))
     (princ))))

(defun c:RMTELHA () (c:TL))
(defun c:RMCOTA  () (c:TLC))
(defun c:RMSIM   () (c:TLS))

;;; --------------------------------------------------------------------
;;;  RMTESTE -- prova de vida
;;;  Se este comando responder, o arquivo carregou e o problema esta em
;;;  outro lugar. Se nem ele responder, o arquivo nao chegou a ser lido.
;;; --------------------------------------------------------------------
(defun c:RMTESTE ( / v)
  (prompt "\n=====================================================")
  (prompt (strcat "\n RM-TELHA.lsp CARREGADO -- VERSAO " RM-VER
                  "  (" RM-VER-NOTA ")"))
  (prompt "\n Se este numero nao for o do arquivo que voce acabou de baixar,")
  (prompt "\n o AutoCAD esta rodando um arquivo antigo.")
  (setq v (getvar "ACADVER"))
  (prompt (strcat "\n AutoCAD: " (if v v "?") "   LT: "
                  (if (vl-string-search "LT" (strcat "" (getvar "PRODUCT"))) "sim" "nao")))
  (prompt (strcat "\n SECURELOAD: " (itoa (getvar "SECURELOAD"))
                  "   (2 = so' pasta confiavel)"))
  (prompt (strcat "\n ActiveX: "
                  (if (vl-catch-all-error-p
                        (vl-catch-all-apply 'vlax-get-acad-object nil))
                    "NAO -- o agrupamento do desfazer nao vai funcionar"
                    "sim")))
  (prompt "\n Comandos: TL / TLC / TLS   ou   RMTELHA / RMCOTA / RMSIM")
  (prompt "\n           RMLIMPA (apaga o desenhado)   RMONDE (copias no disco)")
  (prompt "\n=====================================================")
  (princ))

(prompt "\n=====================================================")
(prompt (strcat "\n RM Estruturas -- RM-TELHA.lsp  VERSAO " RM-VER
                "  (" RM-VER-NOTA ")"))
(prompt "\n   TL  ou RMTELHA   preencher a face e cotar")
(prompt "\n   TLC ou RMCOTA    cotar o que ja existe")
(prompt "\n   TLS ou RMSIM     conferir a simetria da face")
(prompt "\n   RMLIMPA          apaga so' o que estes comandos desenharam")
(prompt "\n   RMONDE           lista as copias deste .lsp no disco, com a versao")
(prompt "\n   RMTESTE          prova de vida e diagnostico")
(prompt "\n=====================================================")
(princ)
