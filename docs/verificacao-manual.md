# Verificação manual

Cenários das especificações em `openspec/changes/menu-bar-camera-viewer/specs/`
que precisam do DVR de verdade ou da barra de menus, e por isso não são
cobertos pelos testes de unidade (`make test`).

Como usar: compile e abra o app com `make run`. Para cada item, siga os passos,
marque a caixa e preencha **Resultado** com a data, ✅ ou ❌ e o que foi visto.
Cada problema encontrado vira um commit `fix(<escopo>): …` próprio.

Antes de começar:

- DVR em 192.168.1.2:554 com o usuário restrito `macApp` (só visualização ao
  vivo e reprodução). O nome do usuário diferencia maiúsculas de minúsculas.
- Para começar do zero: `security delete-generic-password -s com.carloseduardo.IntelbrasViewer`
  e `defaults delete com.carloseduardo.IntelbrasViewer`.
- Para ver conexões RTSP abertas: `lsof -nP -iTCP:554 -a -c IntelbrasV`.
- Para ver os logs do app:
  `/usr/bin/log stream --info --predicate 'subsystem == "com.carloseduardo.IntelbrasViewer"'`.

Resultado da execução de `make test`: 2026-10-13 ✅ 132 testes, 0 falhas (6 de renderização pulados, como esperado).

## 1. Barra de menus e painel (menu-bar-app)

- [x] **1.1 Abrir o app.** Abra o app pelo Finder (ou `make run`).
  Esperado: aparece o ícone de câmera na barra de menus; nenhum ícone no Dock,
  nada no Cmd+Tab, nenhuma janela abre sozinha.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **1.2 Abrir o painel.** Com o DVR configurado, clique no ícone.
  Esperado: o canto superior esquerdo do painel encosta no canto inferior
  direito do ícone (ou o painel encosta na borda direita da tela, se não
  couber), com o cabeçalho "Câmeras",
  a grade e o rodapé com o status.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **1.3 Fechar clicando no ícone.** Com o painel aberto, clique no ícone de novo.
  Esperado: o painel fecha.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **1.4 Fechar clicando fora.** Com o painel aberto, clique na mesa.
  Esperado: o painel fecha.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **1.5 Fechar com Esc.** Com o painel aberto e nenhum campo de texto em
  edição, aperte Esc. Depois, em "Configurações do DVR", clique num campo e
  aperte Esc.
  Esperado: no primeiro caso o painel fecha; no segundo, não fecha.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **1.6 Menu "…".** Abra o menu "…".
  Esperado: nesta ordem, "Renomear câmeras", "Configurações do DVR",
  "Abrir ao iniciar o Mac" e "Sair".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)

## 2. Configuração do DVR (dvr-connection)

- [x] **2.1 Formulário inicial.** Sem nada salvo, abra o painel.
  Esperado: "Configurar DVR" com Endereço 192.168.1.2, Porta 554, Usuário e
  Senha vazios; a senha aparece como pontos.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.2 Senha errada.** Digite `macApp` e uma senha errada e aperte "Conectar".
  Esperado: o formulário continua aberto com "Usuário ou senha incorretos", e
  nada é salvo (`security find-generic-password -s com.carloseduardo.IntelbrasViewer`
  não encontra nada). Faça no máximo uma ou duas tentativas: o DVR bloqueia o
  usuário depois de algumas falhas.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.3 Endereço errado.** Digite o endereço 192.168.1.250 e aperte "Conectar".
  Esperado: em até 5 segundos aparece "Não foi possível encontrar o DVR em
  192.168.1.250:554", e nada é salvo.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.4 Acesso à rede local negado.** Em Ajustes do Sistema > Privacidade e
  Segurança > Rede Local, desligue o Intelbras Viewer e aperte "Conectar".
  Religue depois.
  Esperado: "Permita o acesso à rede local em Ajustes do Sistema > Privacidade
  e Segurança > Rede Local".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.5 Senha correta.** Digite `macApp` e a senha certa e aperte "Conectar".
  Esperado: as configurações são salvas e o painel mostra a grade.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.6 Reabrir o app.** Saia pelo menu "…" > "Sair" e abra o app de novo.
  Esperado: o painel mostra a grade sem pedir usuário e senha.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.7 Senha fora das preferências e dos logs.** Rode
  `defaults read com.carloseduardo.IntelbrasViewer` e veja os logs do app
  enquanto ele conecta.
  Esperado: a senha está no Keychain (Acesso às Chaves, item
  "com.carloseduardo.IntelbrasViewer"), e não aparece nas preferências nem no
  log; os endereços nos logs não têm usuário nem senha.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.8 Trocar só a porta.** Em "Configurações do DVR", mude só a porta
  (por exemplo para 555), deixe a senha vazia e aperte "Salvar"; depois volte
  para 554.
  Esperado: com 555 aparece "Não foi possível encontrar o DVR em
  192.168.1.2:555" e nada muda; com 554 salva usando a senha atual.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.9 Cancelar.** Abra "Configurações do DVR" a partir de uma câmera
  ampliada e aperte "Cancelar".
  Esperado: volta para a mesma câmera ampliada, sem mudanças.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.10 Esquecer DVR.** Em "Configurações do DVR", aperte "Esquecer DVR".
  Esperado: o item do Keychain some, nenhuma conexão RTSP fica aberta e o
  painel mostra "Configurar DVR".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.11 Senha trocada no DVR.** Com o app configurado, troque a senha do
  `macApp` no DVR e abra o painel. Volte a senha depois.
  Esperado: o rodapé mostra "Usuário ou senha incorretos" com o botão
  "Corrigir", que abre "Configurações do DVR". O DVR registra uma única
  tentativa com falha, não uma por câmera.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **2.12 Fora de casa.** Numa rede onde 192.168.1.2 não responde (por
  exemplo, o hotspot do celular), abra o painel.
  Esperado: o rodapé mostra "Sem conexão com o DVR" e as câmeras mostram "Sem sinal".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)

## 3. Câmeras ao vivo (live-view)

- [x] **3.1 Grade com as 8 câmeras.** Com as 8 visíveis, abra o painel.
  Esperado: 8 câmeras ao vivo em 2 colunas, do canal 1 (em cima, à esquerda)
  ao 8 (embaixo, à direita), cada uma com nome e número do canal; a grade
  rola; o rodapé mostra "Conectado".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.2 Imagem 16:9.** Olhe o canal 1 na grade e ampliado, ao lado do
  mesmo canal no VLC (`rtsp://192.168.1.2:554/cam/realmonitor?channel=1&subtype=0`).
  Esperado: a imagem preenche o quadro 16:9 sem faixas pretas nem cortes;
  objetos redondos (rodas, por exemplo) parecem redondos, como no VLC. O
  canal 8 (1280x720) ocupa um quadro do mesmo tamanho.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.3 Ampliar uma câmera.** Clique na câmera do canal 6.
  Esperado: só o canal 6, pelo stream principal, com "‹ Canal 6" e o botão de
  foto no cabeçalho; `lsof` mostra uma única conexão RTSP.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.4 Voltar.** Clique em "‹ Canal 6".
  Esperado: a grade volta e as câmeras tocam de novo.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.5 Fechar o painel encerra as conexões.** Com a grade tocando, feche o
  painel e rode `lsof -nP -iTCP:554 -a -c IntelbrasV` em até 1 segundo.
  Esperado: nenhuma conexão com a porta 554.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.6 Reabrir numa câmera ampliada.** Amplie o canal 2, feche o painel e
  abra de novo.
  Esperado: o canal 2 continua ampliado e tocando pelo stream principal.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.7 Câmera desconectada.** Com o painel aberto, desligue o cabo da
  câmera do canal 4 no DVR.
  Esperado: a câmera 4 mostra "Sem sinal" e as outras continuam tocando.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.8 Câmera reconectada.** Ligue o cabo de volta.
  Esperado: em até 30 segundos a câmera 4 volta a tocar sem nenhuma ação.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **3.9 Atualizar.** Com a câmera 4 em "Sem sinal" (esperando a próxima
  tentativa), aperte o botão de atualizar.
  Esperado: todas as câmeras, a 4 inclusive, reiniciam na hora.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)

## 4. Nomes e câmeras visíveis (camera-list)

- [x] **4.1 Nomes padrão.** Depois da configuração inicial, olhe a grade.
  Esperado: "Canal 1" a "Canal 8".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **4.2 Renomear e reiniciar.** Em "Renomear câmeras", mude o canal 3 para
  "Garagem" e aperte "Concluído". Saia do app e abra de novo.
  Esperado: a câmera 3 mostra "Garagem" antes e depois de reabrir.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **4.3 Apagar um nome.** Apague o nome do canal 3 e aperte "Concluído".
  Esperado: a câmera 3 mostra "Canal 3".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **4.4 Cancelar.** Mude o nome do canal 5 e aperte "Cancelar".
  Esperado: a câmera 5 continua com o nome anterior.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **4.5 Esconder canais.** Desligue "Mostrar" dos canais 5 a 8 (ou 7 e 8,
  que hoje não têm imagem) e aperte "Concluído".
  Esperado: a grade mostra só os canais visíveis e `lsof` mostra uma conexão
  por câmera visível.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **4.6 Esconder todas.** Desligue "Mostrar" das 8 e aperte "Concluído";
  depois aperte "Escolher câmeras".
  Esperado: "Nenhuma câmera visível" com o botão "Escolher câmeras", que abre
  "Renomear câmeras".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)

## 5. Fotos (snapshots)

- [x] **5.1 Botão desabilitado ao conectar.** Amplie uma câmera e olhe o botão
  de foto enquanto aparece "Conectando…".
  Esperado: o botão fica desabilitado até a imagem aparecer.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **5.2 Foto de uma câmera renomeada.** Com "Garagem" ampliada e tocando,
  aperte o botão de foto.
  Esperado: aparece "Foto salva" por uns 2 segundos; o arquivo
  `~/Pictures/Intelbras Viewer/Garagem AAAA-MM-DD HH.MM.SS.jpg` existe, tem
  1920x1080 (`sips -g pixelWidth -g pixelHeight <arquivo>`) e mostra o que
  estava na tela.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **5.3 Nome com barra.** Renomeie uma câmera para "Sala/Cozinha" e tire uma foto.
  Esperado: o nome do arquivo começa com "Sala-Cozinha ".
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **5.4 Pasta sem permissão.** Rode `chmod a-w ~/Pictures/"Intelbras Viewer"`,
  tire uma foto e depois rode `chmod u+w ~/Pictures/"Intelbras Viewer"`.
  Esperado: aparece "Não foi possível salvar a foto" e a câmera continua tocando.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **5.5 Abrir a pasta.** Apague `~/Pictures/Intelbras Viewer` (se estiver
  vazia) e aperte o botão de pasta no rodapé.
  Esperado: a pasta é criada e aparece numa janela do Finder.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)

## 6. Abrir ao iniciar e sair (menu-bar-app)

- [x] **6.1 Desligado no começo.** Na primeira vez, abra o menu "…".
  Esperado: "Abrir ao iniciar o Mac" sem marca.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **6.2 Ligar.** Escolha "Abrir ao iniciar o Mac", encerre a sessão e entre de novo.
  Esperado: o ícone da câmera está na barra de menus depois de entrar, e o
  item mostra a marca.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **6.3 Desligado nos Ajustes.** Com a opção ligada, remova o app em Ajustes
  do Sistema > Geral > Itens de Início e abra o menu "…".
  Esperado: "Abrir ao iniciar o Mac" sem marca.
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
- [x] **6.4 Sair.** Com a grade tocando, escolha "Sair".
  Esperado: as conexões RTSP fecham, o ícone some da barra de menus e o
  processo termina (`pgrep -x IntelbrasViewer` não mostra nada).
  Resultado: 2026-10-13 ✅ (confirmado pelo usuário)
