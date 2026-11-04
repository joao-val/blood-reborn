<#
Blood Reborn - instalador único (interface + correção de erros) / single installer (UI + error repair)
- Lê os pacotes Blood_Reborn_*.zip da pasta dele, de "2 - Mods" ou da pasta de cima, SEM extrair (nada de caminho longo).
- Instala, remove e repara os mods no BB Port. As pastas de compatibilidade (zCompat) entram quando todos os mods delas
  estão instalados, sempre no fim da ordem (no BB Port o último vence).
- Correção de erros: confere os arquivos contra os pacotes (SHA-256); acha restos de instalação manual em mods\, patch
  sem o mod, zCompat faltando, sobrando ou fora de ordem, mod desligado com os patches ligados; conserta o que é do
  Blood Reborn. Nunca mexe nos arquivos do jogo nem em mods de outras pessoas.
- A arte e as fontes vêm do próprio BB Port (_internal\assets): nada do jogo é redistribuído.
- Atenção (PowerShell): nomes de variável não diferenciam maiúsculas; nenhum nome abaixo repete um parâmetro.
Testes sem janela: -PastaPort <pasta> -Acao instalar|verificar|corrigir [-Mods "a,b"] [-Relatorio arq.json] [-SemTrava]
Captura da janela sem mostrar: -Captura arq.png [-Pagina mods|correcao|ajuda] [-Lingua pt|en|es|zh] [-PastaPort ...]
#>
# [CmdletBinding()] (04/11/2026): sem ele um parâmetro desconhecido ia calado para $args (um teste com -PastaDados
# escrevia na pasta de dados de verdade)
[CmdletBinding()]
param(
    [string]$PastaPort = '',
    [string]$Acao = '',
    [string[]]$Mods = @(),
    [string]$Lingua = '',
    [string]$Captura = '',
    [string]$Pagina = 'mods',
    [string]$Relatorio = '',
    [switch]$SemTrava,
    # fase 2 (atualizações, 04/11/2026)
    [string]$PastaDados = '',
    [string]$PastaDownloads = '',
    [string]$Catalogo = 'https://raw.githubusercontent.com/joao-val/blood-reborn/main/catalog.json',
    [string]$NexusApi = 'https://api.nexusmods.com',
    [string]$ChaveNexus = '',
    [int]$EsperaDownload = 1800,
    [switch]$SemRede,
    [switch]$SemNavegador
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$script:Aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:Utf8 = New-Object System.Text.UTF8Encoding $false
$script:Sha = [Security.Cryptography.SHA256]::Create()
$script:Pacotes = @(); $script:Compat = @(); $script:Porto = $null; $script:AoProgredir = $null
$COMPAT_DIR = 'Compatibilidade - Compatibility'
$PASTAS_JOGO = @('action', 'chr', 'event', 'facegen', 'font', 'map', 'menu', 'movie', 'msg', 'mtd', 'obj', 'other', 'param',
                 'paramdef', 'parts', 'remo', 'script', 'sfx', 'shader', 'sound')
$EMBRULHOS = @('', 'app0', 'CUSA03173', 'CUSA00900', 'CUSA00207', 'CUSA00208', 'CUSA00299', 'CUSA01363', 'CUSA03179', 'CUSA03014', 'CUSA03023')
$EXTRAS = @('', '.txt', '.md', '.ini', '.json', '.pdf', '.rtf', '.nfo', '.url', '.htm', '.html', '.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp')
$SOLTOS = @('instalador.ps1', 'Instalar - Install.bat', 'Desinstalar - Uninstall.bat', 'LEIA-ME_PT.txt', 'README_EN.txt', 'LEAME_ES.txt', 'README_ZH.txt', 'blood_reborn.json')
$PREFERENCIA = @('Blood Reborn - Hunters Arsenal', 'Blood Reborn - Merciless Night', 'Blood Reborn - Fogside Lantern', 'Blood Reborn - Blood Vial Safety Net')
$LEIAME = @{ pt = 'LEIA-ME_PT.txt'; en = 'README_EN.txt'; es = 'LEAME_ES.txt'; zh = 'README_ZH.txt' }
$VERSAO_GERENCIADOR = '2.0.0'
$REGISTRO = 'blood_reborn_installed.json'
$script:Dados = if ($PastaDados) { $PastaDados } else { Join-Path $env:APPDATA 'BloodReborn' }
$CONFIG = Join-Path $script:Dados 'instalador.json'

# ---------------------------------------------------------------- textos (pt, en, es, zh)
$TXT = @{
 pt = @{
  app_sub = 'Instalador de mods'; busca = 'Pesquisar...   Ctrl+F'; nav_mods = 'Mods'; nav_fix = 'Correção de erros'; nav_ajuda = 'Como instalar'
  idioma = 'Idioma'; rodape = 'Mods grátis para o BB Port'
  t_mods = 'Mods do Blood Reborn'; s_mods = 'Ligue os mods que você quer e clique em Aplicar. Desligar um mod instalado tira ele do BB Port.'
  sec_mods = 'ESCOLHA OS MODS'
  t_fix = 'Correção de erros'; s_fix = 'Confere os arquivos dos mods do Blood Reborn no seu BB Port e conserta o que estiver errado: arquivo estragado, pasta no lugar errado, compatibilidade faltando, patch sem o mod.'
  sec_fix = 'RESULTADO DA VERIFICAÇÃO'
  t_ajuda = 'Como instalar'; s_ajuda = 'Quatro passos. O instalador cuida do resto.'; sec_ajuda = 'PASSO A PASSO'
  h1 = 'Feche o jogo e o BB Port.'
  h2 = 'Confira a pasta do BB Port no rodapé: é a que tem o "Play Bloodborne.exe". Se estiver errada, use Procurar ou Buscar no PC.'
  h3 = 'Na página Mods, ligue os mods que você quer e clique em APLICAR. A compatibilidade entre os mods entra sozinha, sempre por último.'
  h4 = 'Abra o BB Port e confira em "Mods e patches": os mods ligados e nenhuma linha "Não carregado". Deu algo errado? Use Correção de erros.'
  dica = 'Não precisa extrair os pacotes: o instalador lê os zips direto. Deixe-os na pasta do instalador ou em "2 - Mods".'
  pasta = 'PASTA DO BB PORT'; procurar = 'Procurar...'; buscar = 'Buscar no PC'
  porto_ok = 'BB Port encontrado'; porto_ruim = 'Essa pasta não tem o "Play Bloodborne.exe"'; porto_nada = 'Escolha a pasta do BB Port'
  buscando = 'Procurando o BB Port... {0} pastas'; achou0 = 'Nenhum BB Port encontrado. Use Procurar...'; escolha = 'Escolha a pasta do BB Port (a que tem "Play Bloodborne.exe").'
  aplicar = 'APLICAR'; verificar = 'VERIFICAR'; corrigir = 'CORRIGIR TUDO'; comecar = 'VER OS MODS'
  st_inst = 'Instalado'; st_nao = 'Não instalado'; st_rep = 'Precisa reparar'
  compat = 'Compatibilidade automática: {0}'; compat0 = 'Nenhuma compatibilidade necessária para essa escolha.'
  sem_pac = 'Nenhum pacote do Blood Reborn (Blood_Reborn_*.zip) foi encontrado na pasta do instalador nem em "2 - Mods".'
  aberto = 'Feche o jogo e o BB Port antes de continuar.'
  confirma = "Instalar ou reparar:`n{0}`n`nRemover:`n{1}`n`nContinuar?"; nada = '(nada)'
  pronto = "Pronto!`n`nAbra o BB Port: em ""Mods e patches"" os mods aparecem ligados e nenhuma linha ""Não carregado""."
  v_ok = 'Tudo certo: nenhum problema encontrado.'; v_n = '{0} problema(s) encontrado(s): {1} pode(m) ser corrigido(s).'
  v_porto = 'Escolha a pasta do BB Port no rodapé para verificar.'
  confirma_fix = 'Corrigir {0} problema(s) agora?'; corrigido = 'Correção concluída.'; erro = "Algo deu errado:`n`n{0}"
  longo = 'Caminho longo demais para o Windows ({0} caracteres). Mova o BB Port para uma pasta mais curta, por exemplo C:\Jogos.'
  trabalhando = 'Trabalhando: {0}'; conferindo = 'Conferindo os arquivos...'; chip_fix = 'corrigível'
  d_noport = 'A pasta do BB Port não foi encontrada.'; d_running = 'O jogo ou o BB Port está aberto: feche antes de corrigir.'
  d_rest = 'Resto de instalação manual em mods: "{0}" (o BB Port mostra "Não carregado").'
  d_ruim = '{0}: {1} arquivo(s) estragado(s), faltando ou sobrando.'; d_ok = '{0}: arquivos íntegros.'
  d_patch = '{0}: patch faltando ou diferente: {1}'; d_orfao = 'Patch sem o mod instalado: {0} (deixa as telas de gema quebradas).'
  d_desl = '{0} está desligado no BB Port, mas os patches dele estão ligados.'; d_pdesl = 'Patch desligado no BB Port (o mod precisa dele): {0}'
  d_cfalta = 'Compatibilidade faltando: {0} (sem ela, um mod apaga a parte do outro).'
  d_csobra = 'Compatibilidade sobrando: {0} (falta um dos mods dela).'
  d_cordem = 'Compatibilidade fora de ordem ou desligada: {0} (tem de ficar ligada e por último).'; d_cok = '{0}: ligada e por último.'
  d_csem = 'A compatibilidade {0} não está em nenhum pacote encontrado.'
  d_sobre = 'O mod "{0}" carrega depois e substitui arquivos do Blood Reborn ({1}). Para o Blood Reborn valer, deixe-o abaixo dele na lista do BB Port.'
  d_desc = 'O BB Port não carrega a pasta "{0}" (não é do Blood Reborn: não mexo).'
  d_nova = '{0}: versão {1} instalada, {2} disponível (use Atualizar na página Mods).'
  u_semrede = 'Sem internet ou GitHub/Nexus fora do ar: mostrando o que já está no computador.'
  u_falhou = 'Não deu para baixar {0}: confira a internet ou baixe o zip e ponha na pasta do instalador.'
  u_esperando = 'Esperando o download do Nexus na pasta Downloads... {0} s'
  u_semanterior = 'Não há versão anterior guardada para voltar.'
 }
 en = @{
  app_sub = 'Mod installer'; busca = 'Search...   Ctrl+F'; nav_mods = 'Mods'; nav_fix = 'Error repair'; nav_ajuda = 'How to install'
  idioma = 'Language'; rodape = 'Free mods for the BB Port'
  t_mods = 'Blood Reborn mods'; s_mods = 'Switch on the mods you want and click Apply. Switching off an installed mod removes it from the BB Port.'
  sec_mods = 'CHOOSE YOUR MODS'
  t_fix = 'Error repair'; s_fix = 'Checks the Blood Reborn mod files in your BB Port and fixes what is wrong: damaged files, folders in the wrong place, missing compatibility, patches without their mod.'
  sec_fix = 'CHECK RESULT'
  t_ajuda = 'How to install'; s_ajuda = 'Four steps. The installer does the rest.'; sec_ajuda = 'STEP BY STEP'
  h1 = 'Close the game and the BB Port.'
  h2 = 'Check the BB Port folder at the bottom: the one with "Play Bloodborne.exe". If it is wrong, use Browse or Search PC.'
  h3 = 'On the Mods page, switch on the mods you want and click APPLY. Compatibility between mods is added automatically, always last.'
  h4 = 'Open the BB Port and check "Mods & patches": your mods are on and there is no "Not loaded" line. Something wrong? Use Error repair.'
  dica = 'No need to extract the packages: the installer reads the zips directly. Keep them in the installer folder or in "2 - Mods".'
  pasta = 'BB PORT FOLDER'; procurar = 'Browse...'; buscar = 'Search PC'
  porto_ok = 'BB Port found'; porto_ruim = 'This folder has no "Play Bloodborne.exe"'; porto_nada = 'Choose the BB Port folder'
  buscando = 'Looking for the BB Port... {0} folders'; achou0 = 'No BB Port found. Use Browse...'; escolha = 'Choose the BB Port folder (the one with "Play Bloodborne.exe").'
  aplicar = 'APPLY'; verificar = 'CHECK'; corrigir = 'FIX ALL'; comecar = 'GO TO MODS'
  st_inst = 'Installed'; st_nao = 'Not installed'; st_rep = 'Needs repair'
  compat = 'Automatic compatibility: {0}'; compat0 = 'No compatibility needed for this choice.'
  sem_pac = 'No Blood Reborn package (Blood_Reborn_*.zip) was found in the installer folder or in "2 - Mods".'
  aberto = 'Close the game and the BB Port before continuing.'
  confirma = "Install or repair:`n{0}`n`nRemove:`n{1}`n`nContinue?"; nada = '(nothing)'
  pronto = "Done!`n`nOpen the BB Port: under ""Mods & patches"" your mods are on and there is no ""Not loaded"" line."
  v_ok = 'All good: no problems found.'; v_n = '{0} problem(s) found: {1} can be fixed.'
  v_porto = 'Choose the BB Port folder at the bottom to check it.'
  confirma_fix = 'Fix {0} problem(s) now?'; corrigido = 'Repair finished.'; erro = "Something went wrong:`n`n{0}"
  longo = 'Path too long for Windows ({0} characters). Move the BB Port to a shorter folder, for example C:\Games.'
  trabalhando = 'Working: {0}'; conferindo = 'Checking the files...'; chip_fix = 'fixable'
  d_noport = 'BB Port folder not found.'; d_running = 'The game or the BB Port is open: close it before repairing.'
  d_rest = 'Leftover from a manual install in mods: "{0}" (the BB Port shows "Not loaded").'
  d_ruim = '{0}: {1} file(s) damaged, missing or extra.'; d_ok = '{0}: files intact.'
  d_patch = '{0}: patch missing or different: {1}'; d_orfao = 'Patch without its mod installed: {0} (breaks the gem screens).'
  d_desl = '{0} is off in the BB Port, but its patches are on.'; d_pdesl = 'Patch switched off in the BB Port (the mod needs it): {0}'
  d_cfalta = 'Missing compatibility: {0} (without it, one mod overwrites the other).'
  d_csobra = 'Unneeded compatibility: {0} (one of its mods is missing).'
  d_cordem = 'Compatibility out of order or off: {0} (it must be on and last).'; d_cok = '{0}: on and last.'
  d_csem = 'The compatibility {0} is not in any package found.'
  d_sobre = 'The mod "{0}" loads later and replaces Blood Reborn files ({1}). Move Blood Reborn below it in the BB Port list.'
  d_desc = 'The BB Port does not load the folder "{0}" (not Blood Reborn: left alone).'
  d_nova = '{0}: version {1} installed, {2} available (use Update on the Mods page).'
  u_semrede = 'No internet, or GitHub/Nexus is down: showing what is already on this PC.'
  u_falhou = 'Could not download {0}: check your internet, or download the zip and put it next to the manager.'
  u_esperando = 'Waiting for the Nexus download in your Downloads folder... {0} s'
  u_semanterior = 'There is no previous version saved to go back to.'
 }
 es = @{
  app_sub = 'Instalador de mods'; busca = 'Buscar...   Ctrl+F'; nav_mods = 'Mods'; nav_fix = 'Corrección de errores'; nav_ajuda = 'Cómo instalar'
  idioma = 'Idioma'; rodape = 'Mods gratuitos para el BB Port'
  t_mods = 'Mods de Blood Reborn'; s_mods = 'Activa los mods que quieras y haz clic en Aplicar. Desactivar un mod instalado lo quita del BB Port.'
  sec_mods = 'ELIGE LOS MODS'
  t_fix = 'Corrección de errores'; s_fix = 'Revisa los archivos de los mods de Blood Reborn en tu BB Port y arregla lo que esté mal: archivos dañados, carpetas en el lugar equivocado, compatibilidad faltante, parches sin su mod.'
  sec_fix = 'RESULTADO DE LA REVISIÓN'
  t_ajuda = 'Cómo instalar'; s_ajuda = 'Cuatro pasos. El instalador hace el resto.'; sec_ajuda = 'PASO A PASO'
  h1 = 'Cierra el juego y el BB Port.'
  h2 = 'Revisa la carpeta del BB Port abajo: la que tiene "Play Bloodborne.exe". Si no es la correcta, usa Examinar o Buscar en el PC.'
  h3 = 'En la página Mods, activa los mods que quieras y haz clic en APLICAR. La compatibilidad entre mods se añade sola, siempre al final.'
  h4 = 'Abre el BB Port y revisa "Mods & patches": tus mods activados y ninguna línea "No cargado". ¿Algo salió mal? Usa Corrección de errores.'
  dica = 'No hace falta extraer los paquetes: el instalador lee los zip directamente. Déjalos en la carpeta del instalador o en "2 - Mods".'
  pasta = 'CARPETA DEL BB PORT'; procurar = 'Examinar...'; buscar = 'Buscar en el PC'
  porto_ok = 'BB Port encontrado'; porto_ruim = 'Esta carpeta no tiene "Play Bloodborne.exe"'; porto_nada = 'Elige la carpeta del BB Port'
  buscando = 'Buscando el BB Port... {0} carpetas'; achou0 = 'No se encontró ningún BB Port. Usa Examinar...'; escolha = 'Elige la carpeta del BB Port (la que tiene "Play Bloodborne.exe").'
  aplicar = 'APLICAR'; verificar = 'REVISAR'; corrigir = 'CORREGIR TODO'; comecar = 'VER LOS MODS'
  st_inst = 'Instalado'; st_nao = 'No instalado'; st_rep = 'Necesita reparar'
  compat = 'Compatibilidad automática: {0}'; compat0 = 'No hace falta compatibilidad para esta elección.'
  sem_pac = 'No se encontró ningún paquete de Blood Reborn (Blood_Reborn_*.zip) en la carpeta del instalador ni en "2 - Mods".'
  aberto = 'Cierra el juego y el BB Port antes de continuar.'
  confirma = "Instalar o reparar:`n{0}`n`nQuitar:`n{1}`n`n¿Continuar?"; nada = '(nada)'
  pronto = "¡Listo!`n`nAbre el BB Port: en ""Mods & patches"" tus mods aparecen activados y sin ninguna línea ""No cargado""."
  v_ok = 'Todo bien: no se encontraron problemas.'; v_n = '{0} problema(s) encontrado(s): {1} se puede(n) corregir.'
  v_porto = 'Elige la carpeta del BB Port abajo para revisarla.'
  confirma_fix = '¿Corregir {0} problema(s) ahora?'; corrigido = 'Corrección terminada.'; erro = "Algo salió mal:`n`n{0}"
  longo = 'Ruta demasiado larga para Windows ({0} caracteres). Mueve el BB Port a una carpeta más corta, por ejemplo C:\Juegos.'
  trabalhando = 'Trabajando: {0}'; conferindo = 'Revisando los archivos...'; chip_fix = 'corregible'
  d_noport = 'No se encontró la carpeta del BB Port.'; d_running = 'El juego o el BB Port está abierto: ciérralo antes de corregir.'
  d_rest = 'Resto de una instalación manual en mods: "{0}" (el BB Port muestra "No cargado").'
  d_ruim = '{0}: {1} archivo(s) dañado(s), faltante(s) o sobrante(s).'; d_ok = '{0}: archivos íntegros.'
  d_patch = '{0}: parche faltante o distinto: {1}'; d_orfao = 'Parche sin su mod instalado: {0} (rompe las pantallas de gemas).'
  d_desl = '{0} está desactivado en el BB Port, pero sus parches están activados.'; d_pdesl = 'Parche desactivado en el BB Port (el mod lo necesita): {0}'
  d_cfalta = 'Falta la compatibilidad: {0} (sin ella, un mod pisa al otro).'
  d_csobra = 'Compatibilidad sobrante: {0} (falta uno de sus mods).'
  d_cordem = 'Compatibilidad fuera de orden o desactivada: {0} (debe estar activada y al final).'; d_cok = '{0}: activada y al final.'
  d_csem = 'La compatibilidad {0} no está en ningún paquete encontrado.'
  d_sobre = 'El mod "{0}" se carga después y reemplaza archivos de Blood Reborn ({1}). Pon Blood Reborn debajo en la lista del BB Port.'
  d_desc = 'El BB Port no carga la carpeta "{0}" (no es de Blood Reborn: no la toco).'
  d_nova = '{0}: versión {1} instalada, {2} disponible (usa Actualizar en la página Mods).'
  u_semrede = 'Sin internet o GitHub/Nexus caído: se muestra lo que ya está en el equipo.'
  u_falhou = 'No se pudo descargar {0}: revisa internet, o descarga el zip y ponlo en la carpeta del instalador.'
  u_esperando = 'Esperando la descarga de Nexus en la carpeta Descargas... {0} s'
  u_semanterior = 'No hay una versión anterior guardada para volver.'
 }
 zh = @{
  app_sub = '模组安装器'; busca = '搜索...   Ctrl+F'; nav_mods = '模组'; nav_fix = '错误修复'; nav_ajuda = '安装说明'
  idioma = '语言'; rodape = 'BB Port 的免费模组'
  t_mods = 'Blood Reborn 模组'; s_mods = '打开你想要的模组，然后点击“应用”。关闭已安装的模组会把它从 BB Port 中移除。'
  sec_mods = '选择模组'
  t_fix = '错误修复'; s_fix = '检查 BB Port 中 Blood Reborn 模组的文件，并修复问题：文件损坏、文件夹位置错误、缺少兼容文件、补丁没有对应的模组。'
  sec_fix = '检查结果'
  t_ajuda = '安装说明'; s_ajuda = '四个步骤，其余交给安装器。'; sec_ajuda = '步骤'
  h1 = '关闭游戏和 BB Port。'
  h2 = '检查底部的 BB Port 文件夹：就是有 "Play Bloodborne.exe" 的那个。如果不对，请点“浏览”或“在电脑中搜索”。'
  h3 = '在“模组”页面打开你想要的模组，然后点击“应用”。模组之间的兼容文件会自动添加，并始终放在最后。'
  h4 = '打开 BB Port，查看 "Mods & patches"：你的模组已启用，并且没有“未加载”的行。出问题了？请使用“错误修复”。'
  dica = '无需解压安装包：安装器会直接读取 zip。把它们放在安装器所在的文件夹或 "2 - Mods" 中。'
  pasta = 'BB PORT 文件夹'; procurar = '浏览...'; buscar = '在电脑中搜索'
  porto_ok = '已找到 BB Port'; porto_ruim = '这个文件夹里没有 "Play Bloodborne.exe"'; porto_nada = '请选择 BB Port 文件夹'
  buscando = '正在查找 BB Port... {0} 个文件夹'; achou0 = '没有找到 BB Port。请点“浏览...”'; escolha = '请选择 BB Port 文件夹（有 "Play Bloodborne.exe" 的那个）。'
  aplicar = '应用'; verificar = '检查'; corrigir = '全部修复'; comecar = '前往模组'
  st_inst = '已安装'; st_nao = '未安装'; st_rep = '需要修复'
  compat = '自动兼容：{0}'; compat0 = '当前选择不需要兼容文件。'
  sem_pac = '在安装器文件夹或 "2 - Mods" 中没有找到 Blood Reborn 安装包（Blood_Reborn_*.zip）。'
  aberto = '继续之前请关闭游戏和 BB Port。'
  confirma = "安装或修复：`n{0}`n`n移除：`n{1}`n`n继续吗？"; nada = '（无）'
  pronto = "完成！`n`n打开 BB Port：在 ""Mods & patches"" 中你的模组已启用，并且没有""未加载""的行。"
  v_ok = '一切正常：没有发现问题。'; v_n = '发现 {0} 个问题：其中 {1} 个可以修复。'
  v_porto = '请在底部选择 BB Port 文件夹后再检查。'
  confirma_fix = '现在修复 {0} 个问题吗？'; corrigido = '修复完成。'; erro = "出错了：`n`n{0}"
  longo = '路径对 Windows 来说太长（{0} 个字符）。请把 BB Port 移到更短的文件夹，例如 C:\Games。'
  trabalhando = '处理中：{0}'; conferindo = '正在检查文件...'; chip_fix = '可修复'
  d_noport = '未找到 BB Port 文件夹。'; d_running = '游戏或 BB Port 正在运行：请先关闭再修复。'
  d_rest = 'mods 中有手动安装的残留："{0}"（BB Port 会显示“未加载”）。'
  d_ruim = '{0}：{1} 个文件损坏、缺失或多余。'; d_ok = '{0}：文件完好。'
  d_patch = '{0}：补丁缺失或不同：{1}'; d_orfao = '补丁的模组未安装：{0}（会导致宝石界面出错）。'
  d_desl = '{0} 在 BB Port 中被关闭，但它的补丁仍在启用。'; d_pdesl = 'BB Port 中关闭了补丁（模组需要它）：{0}'
  d_cfalta = '缺少兼容文件：{0}（没有它，一个模组会覆盖另一个）。'
  d_csobra = '多余的兼容文件：{0}（缺少它对应的某个模组）。'
  d_cordem = '兼容文件顺序错误或被关闭：{0}（必须启用并放在最后）。'; d_cok = '{0}：已启用并在最后。'
  d_csem = '在找到的安装包中没有兼容文件 {0}。'
  d_sobre = '模组 "{0}" 在之后加载，会替换 Blood Reborn 的文件（{1}）。请在 BB Port 列表中把 Blood Reborn 放在它下面。'
  d_desc = 'BB Port 不会加载文件夹 "{0}"（不是 Blood Reborn 的：不做改动）。'
  d_nova = '{0}：已安装版本 {1}，可用版本 {2}（请在“模组”页面点击“更新”）。'
  u_semrede = '没有网络，或 GitHub/Nexus 无法访问：显示本机已有的内容。'
  u_falhou = '无法下载 {0}：请检查网络，或手动下载 zip 并放到管理器所在的文件夹。'
  u_esperando = '正在“下载”文件夹中等待 Nexus 的下载…… {0} 秒'
  u_semanterior = '没有保存可以回退的旧版本。'
 }
}
function T([string]$chave) {
    # $script: explícito: o PowerShell não diferencia maiúsculas e procura a variável também em quem chamou ($txt local = $TXT)
    $v = $script:TXT[$script:Ling][$chave]
    if (-not $v) { $v = $script:TXT['en'][$chave] }
    return $v
}

# ---------------------------------------------------------------- pacotes (zips)
function Ler-Entrada($entrada) {
    $sr = New-Object IO.StreamReader($entrada.Open(), [Text.Encoding]::UTF8, $true)
    try { return $sr.ReadToEnd() } finally { $sr.Close() }
}
function Descricao([string]$texto) {
    # as linhas do bloco "O QUE ESTE MOD FAZ" do LEIA-ME (entre o título com ✨ e o com ✅), sem os emojis
    $linhas = $texto -split "`r?`n"; $dentro = $false; $out = @()
    foreach ($l in $linhas) {
        if ($l.Contains([string][char]0x2728)) { $dentro = $true; continue }
        if ($l.Contains([string][char]0x2705)) { break }
        if (-not $dentro) { continue }
        $s = ($l -replace '[\uD800-\uDFFF\uFE0F\u200D]', '' -replace '[\u2190-\u2BFF]', '').Trim()
        if ($s) { $out += $s }
    }
    return ($out -join "`n")
}
function Versao-Num([string]$v) {
    $s = ($v -replace '[^\d.]', '').Trim('.')
    if (-not $s) { $s = '0' }
    if (-not $s.Contains('.')) { $s += '.0' }
    return [version]$s
}
function Ler-Pacotes {
    # 04/11 (fase 2): também <dados>\pacotes (os baixados pelo gerenciador) e TODAS as versões em $script:TodosPacotes
    $achados = @{}; $cima = Split-Path -Parent $script:Aqui; $todos = New-Object Collections.ArrayList
    $lugares = @($script:Aqui, (Join-Path $script:Aqui '2 - Mods'), $cima, (Join-Path $cima '2 - Mods'), (Join-Path $script:Dados 'pacotes'))
    foreach ($lugar in $lugares) {
        if (-not $lugar -or -not [IO.Directory]::Exists($lugar)) { continue }
        foreach ($z in [IO.Directory]::GetFiles($lugar, 'Blood_Reborn_*.zip')) {
            $arq = $null
            try {
                $arq = [IO.Compression.ZipFile]::OpenRead($z)
                $ent = $null
                foreach ($e in $arq.Entries) { if ($e.FullName -match '^[^/]+/blood_reborn\.json$') { $ent = $e; break } }
                if (-not $ent) { continue }
                $topo = $ent.FullName.Substring(0, $ent.FullName.IndexOf('/') + 1)
                $info = (Ler-Entrada $ent) | ConvertFrom-Json
                $desc = @{}
                foreach ($lg in $LEIAME.Keys) {
                    $e2 = $arq.GetEntry($topo + $LEIAME[$lg])
                    if ($e2) { $desc[$lg] = Descricao (Ler-Entrada $e2) } else { $desc[$lg] = '' }
                }
                $pre = $topo + 'mods/' + [string]$info.pasta + '/'
                $arqs = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase); $maior = 0
                foreach ($e in $arq.Entries) {
                    if ($e.FullName.StartsWith($pre) -and -not $e.FullName.EndsWith('/')) {
                        $rel = $e.FullName.Substring($pre.Length)
                        if ($rel.StartsWith('dvdroot_ps4/')) { [void]$arqs.Add($rel.Substring(12)) }
                        $maior = [Math]::Max($maior, ([string]$info.pasta).Length + 1 + $rel.Length)
                    }
                }
                $pac = [pscustomobject]@{
                    Nome = [string]$info.nome; Versao = [string]$info.versao; Pasta = [string]$info.pasta
                    Patches = @($info.patches | Where-Object { $_ }); CompatDef = @($info.compat | Where-Object { $_ })
                    Zip = $z; Topo = $topo; Prefixo = $pre; Desc = $desc; Arquivos = $arqs; Maior = $maior }
                [void]$todos.Add($pac)
                $velho = $achados[$pac.Pasta]
                if (-not $velho -or (Versao-Num $pac.Versao) -gt (Versao-Num $velho.Versao)) { $achados[$pac.Pasta] = $pac }
            } catch {
            } finally { if ($arq) { $arq.Dispose() } }
        }
    }
    $script:Pacotes = @($achados.Values | Sort-Object { $i = [array]::IndexOf($PREFERENCIA, $_.Pasta); if ($i -lt 0) { 99 } else { $i } }, Nome)
    $script:TodosPacotes = @($todos)
    $script:PastasPacote = @($script:Pacotes | ForEach-Object { $_.Pasta })
    # compatibilidades: a definição vem dos blood_reborn.json; a fonte, do 1º zip que tem a pasta
    $cs = @{}
    foreach ($p in $script:Pacotes) {
        foreach ($c in $p.CompatDef) {
            $nome = [string]$c.pasta
            if (-not $cs.ContainsKey($nome)) {
                $cs[$nome] = [pscustomobject]@{ Pasta = $nome; Mods = @($c.mods | ForEach-Object { [string]$_ }); Zip = $null; Prefixo = $null
                                                Arquivos = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase); Maior = 0 }
            }
        }
    }
    foreach ($c in $cs.Values) {
        foreach ($p in $script:Pacotes) {
            $pre = $p.Topo + $COMPAT_DIR + '/' + $c.Pasta + '/'; $arq = [IO.Compression.ZipFile]::OpenRead($p.Zip)
            try {
                foreach ($e in $arq.Entries) {
                    if ($e.FullName.StartsWith($pre) -and -not $e.FullName.EndsWith('/')) {
                        $rel = $e.FullName.Substring($pre.Length)
                        if ($rel.StartsWith('dvdroot_ps4/')) { [void]$c.Arquivos.Add($rel.Substring(12)) }
                        $c.Maior = [Math]::Max($c.Maior, $c.Pasta.Length + 1 + $rel.Length)
                    }
                }
            } finally { $arq.Dispose() }
            if ($c.Arquivos.Count -gt 0) { $c.Zip = $p.Zip; $c.Prefixo = $pre; break }
        }
    }
    $script:Compat = @($cs.Values | Sort-Object Pasta)
}

# ---------------------------------------------------------------- arquivos
function Conferir-Pasta([string]$zip, [string]$prefixo, [string]$pasta, [switch]$Rapido) {
    # 0 = igual ao pacote; -1 = não existe; n = arquivos estragados, faltando ou sobrando
    if (-not [IO.Directory]::Exists($pasta)) { return -1 }
    $ruins = 0; $vistos = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $arq = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($e in $arq.Entries) {
            if (-not $e.FullName.StartsWith($prefixo) -or $e.FullName.EndsWith('/')) { continue }
            $rel = $e.FullName.Substring($prefixo.Length).Replace('/', '\'); [void]$vistos.Add($rel)
            $f = Join-Path $pasta $rel
            if (-not [IO.File]::Exists($f)) { $ruins++; continue }
            if ((New-Object IO.FileInfo $f).Length -ne $e.Length) { $ruins++; continue }
            if ($Rapido) { continue }
            $s = $e.Open(); try { $h1 = [Convert]::ToBase64String($script:Sha.ComputeHash($s)) } finally { $s.Close() }
            $s = [IO.File]::OpenRead($f); try { $h2 = [Convert]::ToBase64String($script:Sha.ComputeHash($s)) } finally { $s.Close() }
            if ($h1 -ne $h2) { $ruins++ }
        }
    } finally { $arq.Dispose() }
    $base = $pasta.TrimEnd('\').Length + 1
    # o registro da instalação (fase 2) não é arquivo do pacote: não conta como sobrando
    foreach ($f in [IO.Directory]::GetFiles($pasta, '*', 'AllDirectories')) { $r = $f.Substring($base); if ($r -ne $REGISTRO -and -not $vistos.Contains($r)) { $ruins++ } }
    return $ruins
}
function Conferir-Arquivo([string]$zip, [string]$entrada, [string]$arquivo) {
    if (-not [IO.File]::Exists($arquivo)) { return $false }
    $arq = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $e = $arq.GetEntry($entrada); if (-not $e) { return $true }
        if ((New-Object IO.FileInfo $arquivo).Length -ne $e.Length) { return $false }
        $s = $e.Open(); try { $h1 = [Convert]::ToBase64String($script:Sha.ComputeHash($s)) } finally { $s.Close() }
    } finally { $arq.Dispose() }
    $s = [IO.File]::OpenRead($arquivo); try { $h2 = [Convert]::ToBase64String($script:Sha.ComputeHash($s)) } finally { $s.Close() }
    return $h1 -eq $h2
}
function Extrair-Pasta([string]$zip, [string]$prefixo, [string]$pasta) {
    if ([IO.Directory]::Exists($pasta)) { Remove-Item -LiteralPath $pasta -Recurse -Force }
    $arq = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        foreach ($e in $arq.Entries) {
            if (-not $e.FullName.StartsWith($prefixo) -or $e.FullName.EndsWith('/')) { continue }
            $alvo = Join-Path $pasta ($e.FullName.Substring($prefixo.Length).Replace('/', '\'))
            if ($alvo.Length -ge 260) { throw ((T 'longo') -f $alvo.Length) }
            [void][IO.Directory]::CreateDirectory((Split-Path -Parent $alvo))
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $alvo, $true)
        }
    } finally { $arq.Dispose() }
}
function Extrair-Arquivo([string]$zip, [string]$entrada, [string]$arquivo) {
    $arq = [IO.Compression.ZipFile]::OpenRead($zip)
    try {
        $e = $arq.GetEntry($entrada); if (-not $e) { return }
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $arquivo))
        [IO.Compression.ZipFileExtensions]::ExtractToFile($e, $arquivo, $true)
    } finally { $arq.Dispose() }
}

# ---------------------------------------------------------------- BB Port (as mesmas regras do mods.py do lançador)
function E-Port([string]$p) { return [bool]($p -and [IO.File]::Exists((Join-Path $p 'Play Bloodborne.exe'))) }
function Jogo-Aberto { return [bool](Get-Process -Name 'Bloodborne', 'Play Bloodborne', 'bb-probe' -ErrorAction SilentlyContinue) }
function Raiz-Mod([string]$pasta, [int]$nivel = 0) {
    if (-not [IO.Directory]::Exists($pasta)) { return $null }
    foreach ($emb in $EMBRULHOS) {
        $base = $pasta; if ($emb) { $base = Join-Path $pasta $emb }
        $dv = Join-Path $base 'dvdroot_ps4'
        if ([IO.Directory]::Exists($dv)) { return @{ Raiz = $dv; Jogo = $false } }
    }
    $dirs = @([IO.Directory]::GetDirectories($pasta) | Where-Object { -not ([IO.Path]::GetFileName($_)).StartsWith('.') })
    $fs = @([IO.Directory]::GetFiles($pasta) | Where-Object { -not ([IO.Path]::GetFileName($_)).StartsWith('.') })
    if (@($dirs | Where-Object { $PASTAS_JOGO -contains ([IO.Path]::GetFileName($_)).ToLowerInvariant() }).Count -gt 0) { return @{ Raiz = $pasta; Jogo = $true } }
    $arqAvulsos = @($fs | Where-Object { $script:EXTRAS -notcontains ([IO.Path]::GetExtension($_)).ToLowerInvariant() })
    if ($nivel -lt 3 -and $dirs.Count -eq 1 -and $arqAvulsos.Count -eq 0) { return (Raiz-Mod $dirs[0] ($nivel + 1)) }
    return $null
}
function Arquivos-Mod([string]$pasta) {
    $set = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $r = Raiz-Mod $pasta; if (-not $r) { return ,$set }
    $base = $r.Raiz.TrimEnd('\').Length + 1
    foreach ($f in [IO.Directory]::GetFiles($r.Raiz, '*', 'AllDirectories')) {
        $rel = $f.Substring($base).Replace('\', '/')
        if ($r.Jogo -and $PASTAS_JOGO -notcontains ($rel.Split('/')[0]).ToLowerInvariant()) { continue }
        [void]$set.Add($rel)
    }
    return ,$set
}
function Ler-Json2([string]$arquivo, [string]$k1, [string]$k2) {
    $a = @(); $b = @()
    if ([IO.File]::Exists($arquivo)) {
        $j = [IO.File]::ReadAllText($arquivo, [Text.Encoding]::UTF8) | ConvertFrom-Json
        if ($j.$k1) { $a = @($j.$k1 | ForEach-Object { [string]$_ }) }
        if ($j.$k2) { $b = @($j.$k2 | ForEach-Object { [string]$_ }) }
    }
    return @{ A = $a; B = $b }
}
function Json-Lista($itens) {
    $l = @($itens | Where-Object { $_ })
    if ($l.Count -eq 0) { return '[]' }
    return "[`n" + (($l | ForEach-Object { '    ' + (ConvertTo-Json ([string]$_)) }) -join ",`n") + "`n  ]"
}
function Gravar-Json2([string]$arquivo, [string]$k1, $a, [string]$k2, $b) {
    $t = "{`n  `"$k1`": " + (Json-Lista $a) + ",`n  `"$k2`": " + (Json-Lista $b) + "`n}`n"
    [IO.File]::WriteAllText($arquivo, $t, $script:Utf8)
}
function Disponiveis([string]$porto) {
    $dm = Join-Path $porto 'mods'
    if (-not [IO.Directory]::Exists($dm)) { return @() }
    return @([IO.Directory]::GetDirectories($dm) | ForEach-Object { [IO.Path]::GetFileName($_) } |
             Where-Object { -not $_.StartsWith('.') -and (Raiz-Mod (Join-Path $dm $_)) } | Sort-Object { $_.ToLowerInvariant() }, { $_ })
}
function Selecionados([string]$porto) {
    # mods.selected do lançador: a ordem do mods.json, depois as pastas novas em ordem alfabética; sem as desligadas
    $cfg = Ler-Json2 (Join-Path $porto 'mods.json') 'order' 'disabled'; $disp = @(Disponiveis $porto)
    $out = New-Object Collections.ArrayList
    foreach ($n in (@($cfg.A) + $disp)) { if ($disp -contains $n -and $cfg.B -notcontains $n -and -not $out.Contains($n)) { [void]$out.Add($n) } }
    return $out
}
function Achar-Restos([string]$porto) {
    # pastas e arquivos do Blood Reborn que uma instalação manual deixou no lugar errado (o BB Port não carrega)
    $out = @(); $dm = Join-Path $porto 'mods'; $nossosPatches = @($script:Pacotes | ForEach-Object { $_.Patches })
    if ([IO.Directory]::Exists($dm)) {
        foreach ($d in [IO.Directory]::GetDirectories($dm)) {
            $n = [IO.Path]::GetFileName($d); $nosso = $false; $resgate = @()
            if ($n -eq $COMPAT_DIR) { $nosso = $true }
            elseif ($n -eq 'patches') {
                $fs = @([IO.Directory]::GetFiles($d, '*', 'AllDirectories'))
                $nosso = $fs.Count -gt 0 -and @([IO.Directory]::GetDirectories($d)).Count -eq 0 -and
                         @($fs | Where-Object { $nossosPatches -notcontains [IO.Path]::GetFileName($_) }).Count -eq 0
            } elseif ($n -eq 'mods') {
                $ds = @([IO.Directory]::GetDirectories($d))
                $nosso = $ds.Count -gt 0 -and @([IO.Directory]::GetFiles($d)).Count -eq 0 -and
                         @($ds | Where-Object { -not ([IO.Path]::GetFileName($_)).StartsWith('Blood Reborn - ') }).Count -eq 0
                if ($nosso) { $resgate = @($ds | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $script:PastasPacote -contains $_ }) }
            } elseif ($n -match '^Blood Reborn - .+ v\d[\d.]*$' -and [IO.File]::Exists((Join-Path $d 'blood_reborn.json'))) {
                $nosso = $true
                try {
                    $j = [IO.File]::ReadAllText((Join-Path $d 'blood_reborn.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
                    if ($script:PastasPacote -contains [string]$j.pasta) { $resgate = @([string]$j.pasta) }
                } catch { }
            }
            if ($nosso) { $out += [pscustomobject]@{ Caminho = $d; Nome = $n; Resgate = $resgate } }
        }
        foreach ($f in [IO.Directory]::GetFiles($dm)) {
            $n = [IO.Path]::GetFileName($f)
            if ($SOLTOS -contains $n) { $out += [pscustomobject]@{ Caminho = $f; Nome = $n; Resgate = @() } }
        }
    }
    if ([IO.File]::Exists((Join-Path $porto 'blood_reborn.json'))) {     # pacote extraído na raiz do BB Port
        foreach ($n in $SOLTOS) { $f = Join-Path $porto $n; if ([IO.File]::Exists($f)) { $out += [pscustomobject]@{ Caminho = $f; Nome = $n; Resgate = @() } } }
        $c = Join-Path $porto $COMPAT_DIR
        if ([IO.Directory]::Exists($c)) { $out += [pscustomobject]@{ Caminho = $c; Nome = $COMPAT_DIR; Resgate = @() } }
    }
    return $out
}
function Passo([string]$texto) { if ($script:AoProgredir) { & $script:AoProgredir ((T 'trabalhando') -f $texto) } }
function Checar-Caminho([string]$porto) {
    $base = (Join-Path $porto 'mods').Length + 1
    $maior = (@($script:Pacotes | ForEach-Object { $_.Maior }) + @($script:Compat | ForEach-Object { $_.Maior }) | Measure-Object -Maximum).Maximum
    if ($base + $maior -ge 260) { throw ((T 'longo') -f ($base + $maior)) }
}

# ---------------------------------------------------------------- instalar / remover / reparar
function Aplicar-Escolha([string]$porto, [string[]]$quero) {
    if (-not $SemTrava -and (Jogo-Aberto)) { throw (T 'aberto') }
    $dm = Join-Path $porto 'mods'; $dp = Join-Path $porto 'patches'
    [void][IO.Directory]::CreateDirectory($dm); [void][IO.Directory]::CreateDirectory($dp)
    Checar-Caminho $porto
    foreach ($r in @(Achar-Restos $porto)) { Passo $r.Nome; Remove-Item -LiteralPath $r.Caminho -Recurse -Force }
    $feitos = @(); $tirados = @()
    foreach ($p in $script:Pacotes) {
        $alvo = Join-Path $dm $p.Pasta
        if ($quero -contains $p.Pasta) {
            Passo $p.Nome
            # 04/11 (fase 2): o APLICAR instala e conserta, mas não troca de versão sozinho (isso é do botão Atualizar);
            # conserta com o pacote da versão instalada, se ele estiver no computador
            $reg = Ler-Registro $alvo; $pv = $p
            if ($reg -and $reg.version) { $pv = Pacote-Da-Versao $p.Pasta ([string]$reg.version) }
            $estadoReg = Conferir-Registro $alvo
            if (-not [IO.Directory]::Exists($alvo) -or ($estadoReg -gt 0 -and $pv) -or ($estadoReg -lt 0 -and (Conferir-Pasta $p.Zip $p.Prefixo $alvo) -ne 0)) {
                if (-not $pv) { $pv = $p }
                Extrair-Pasta $pv.Zip $pv.Prefixo $alvo; Gravar-Registro $alvo $pv $script:FonteInstalacao; $feitos += $pv.Nome
            } elseif ($estadoReg -lt 0) { Gravar-Registro $alvo $p 'zip' }
            if ($pv) {
                foreach ($x in $pv.Patches) {
                    $e = $pv.Topo + 'patches/' + $x; $f = Join-Path $dp $x
                    if (-not (Conferir-Arquivo $pv.Zip $e $f)) { Extrair-Arquivo $pv.Zip $e $f }
                }
            }
        } else {
            # sai também o patch que só a versão instalada tinha (o registro guarda os patches dela)
            $reg = Ler-Registro $alvo; $saem = @($p.Patches) + @($reg.patches | Where-Object { $_ })
            if ([IO.Directory]::Exists($alvo)) { Passo $p.Nome; Remove-Item -LiteralPath $alvo -Recurse -Force; $tirados += $p.Nome }
            foreach ($x in $saem) { $f = Join-Path $dp ([string]$x); if ([IO.File]::Exists($f)) { Remove-Item -LiteralPath $f -Force } }
        }
    }
    $compatOk = @()
    foreach ($c in $script:Compat) {
        $alvo = Join-Path $dm $c.Pasta
        $precisa = @($c.Mods | Where-Object { -not [IO.Directory]::Exists((Join-Path $dm $_)) }).Count -eq 0
        if ($precisa -and $c.Zip) {
            if ((Conferir-Pasta $c.Zip $c.Prefixo $alvo) -ne 0) { Passo $c.Pasta; Extrair-Pasta $c.Zip $c.Prefixo $alvo }
            $compatOk += $c.Pasta
        } elseif ($precisa -and [IO.Directory]::Exists($alvo)) {
            $compatOk += $c.Pasta
        } elseif ([IO.Directory]::Exists($alvo)) { Passo $c.Pasta; Remove-Item -LiteralPath $alvo -Recurse -Force }
    }
    # mods.json: os nossos ligados e no fim, as zCompat por último
    $nossos = @($script:PastasPacote) + @($script:Compat | ForEach-Object { $_.Pasta })
    $cfg = Ler-Json2 (Join-Path $porto 'mods.json') 'order' 'disabled'
    $ordem = @($cfg.A | Where-Object { $nossos -notcontains $_ }) + @($script:Pacotes | Where-Object { $quero -contains $_.Pasta } | ForEach-Object { $_.Pasta }) + $compatOk
    $desl = @($cfg.B | Where-Object { $nossos -notcontains $_ })
    Gravar-Json2 (Join-Path $porto 'mods.json') 'order' $ordem 'disabled' $desl
    # patches.json (só se o BB Port já criou): os patches dos nossos ligados; os dos tirados saem da lista
    $pc = Join-Path $porto 'patches.json'
    if ([IO.File]::Exists($pc)) {
        $j = Ler-Json2 $pc 'enabled' 'disabled'
        $querem = @($script:Pacotes | Where-Object { $quero -contains $_.Pasta } | ForEach-Object { $_.Patches })
        $saem = @($script:Pacotes | Where-Object { $quero -notcontains $_.Pasta } | ForEach-Object { $_.Patches })
        $de = { param($k, $lista) foreach ($x in $lista) { if ($k.StartsWith($x + '/')) { return $true } }; return $false }
        $ativos = @($j.A | Where-Object { -not (& $de $_ $saem) })
        $desl2 = @($j.B | Where-Object { -not (& $de $_ $querem) -and -not (& $de $_ $saem) })
        Gravar-Json2 $pc 'enabled' $ativos 'disabled' $desl2
    }
    return @{ Feitos = $feitos; Tirados = $tirados; Compat = $compatOk }
}
function Corrigir-Tudo([string]$porto) {
    $dm = Join-Path $porto 'mods'
    $quero = @($script:Pacotes | Where-Object { [IO.Directory]::Exists((Join-Path $dm $_.Pasta)) } | ForEach-Object { $_.Pasta })
    foreach ($r in @(Achar-Restos $porto)) { foreach ($x in $r.Resgate) { if ($quero -notcontains $x) { $quero += $x } } }
    return (Aplicar-Escolha $porto $quero)
}
function Item([string]$nivel, [string]$texto, [bool]$corrige) { return [pscustomobject]@{ Nivel = $nivel; Texto = $texto; Corrige = $corrige } }
function Diagnosticar([string]$porto) {
    $L = New-Object Collections.ArrayList
    if (-not (E-Port $porto)) { [void]$L.Add((Item 'erro' (T 'd_noport') $false)); return $L }
    if (-not $SemTrava -and (Jogo-Aberto)) { [void]$L.Add((Item 'erro' (T 'd_running') $false)) }
    $dm = Join-Path $porto 'mods'; $dp = Join-Path $porto 'patches'
    $restos = @(Achar-Restos $porto)
    foreach ($r in $restos) { [void]$L.Add((Item 'erro' ((T 'd_rest') -f $r.Nome) $true)) }
    $cfg = Ler-Json2 (Join-Path $porto 'mods.json') 'order' 'disabled'
    $pj = Ler-Json2 (Join-Path $porto 'patches.json') 'enabled' 'disabled'
    foreach ($p in $script:Pacotes) {
        $alvo = Join-Path $dm $p.Pasta
        if ([IO.Directory]::Exists($alvo)) {
            Passo $p.Nome; $ok = $true
            # 04/11 (fase 2): confere pelo registro da instalação (vale para qualquer versão); sem registro, pelo pacote
            $ruins = Conferir-Registro $alvo
            if ($ruins -lt 0) { $ruins = Conferir-Pasta $p.Zip $p.Prefixo $alvo }
            if ($ruins -gt 0) { [void]$L.Add((Item 'erro' ((T 'd_ruim') -f $p.Nome, $ruins) $true)); $ok = $false }
            $vi = Versao-Instalada $porto $p.Pasta
            if ($vi -and $vi -ne 'unknown' -and (Versao-Num $p.Versao) -gt (Versao-Num $vi)) {
                [void]$L.Add((Item 'aviso' ((T 'd_nova') -f $p.Nome, $vi, $p.Versao) $false))
            }
            $pv = Pacote-Da-Versao $p.Pasta $vi; if (-not $pv) { $pv = $p }
            foreach ($x in $pv.Patches) {
                if (-not (Conferir-Arquivo $pv.Zip ($pv.Topo + 'patches/' + $x) (Join-Path $dp $x))) { [void]$L.Add((Item 'erro' ((T 'd_patch') -f $p.Nome, $x) $true)); $ok = $false }
            }
            if ($cfg.B -contains $p.Pasta -and $p.Patches.Count -gt 0) { [void]$L.Add((Item 'erro' ((T 'd_desl') -f $p.Nome) $true)); $ok = $false }
            foreach ($k in $pj.B) { foreach ($x in $p.Patches) { if ($k.StartsWith($x + '/')) { [void]$L.Add((Item 'erro' ((T 'd_pdesl') -f $k) $true)); $ok = $false } } }
            if ($ok) { [void]$L.Add((Item 'ok' ((T 'd_ok') -f $p.Nome) $false)) }
        } else {
            foreach ($x in $p.Patches) { if ([IO.File]::Exists((Join-Path $dp $x))) { [void]$L.Add((Item 'erro' ((T 'd_orfao') -f $x) $true)) } }
        }
    }
    $sel = @(Selecionados $porto)
    foreach ($c in $script:Compat) {
        $alvo = Join-Path $dm $c.Pasta
        $precisa = @($c.Mods | Where-Object { -not [IO.Directory]::Exists((Join-Path $dm $_)) }).Count -eq 0
        $existe = [IO.Directory]::Exists($alvo)
        if ($precisa -and -not $existe) {
            if ($c.Zip) { [void]$L.Add((Item 'erro' ((T 'd_cfalta') -f $c.Pasta) $true)) } else { [void]$L.Add((Item 'aviso' ((T 'd_csem') -f $c.Pasta) $false)) }
        } elseif (-not $precisa -and $existe) {
            [void]$L.Add((Item 'erro' ((T 'd_csobra') -f $c.Pasta) $true))
        } elseif ($precisa -and $existe) {
            Passo $c.Pasta; $ok = $true
            if ($c.Zip) {
                $ruins = Conferir-Pasta $c.Zip $c.Prefixo $alvo
                if ($ruins -gt 0) { [void]$L.Add((Item 'erro' ((T 'd_ruim') -f $c.Pasta, $ruins) $true)); $ok = $false }
            }
            $i = [array]::IndexOf($sel, $c.Pasta)
            $depois = @($c.Mods | Where-Object { [array]::IndexOf($sel, $_) -gt $i })
            if ($i -lt 0 -or $depois.Count -gt 0) { [void]$L.Add((Item 'erro' ((T 'd_cordem') -f $c.Pasta) $true)); $ok = $false }
            if ($ok) { [void]$L.Add((Item 'ok' ((T 'd_cok') -f $c.Pasta) $false)) }
        }
    }
    # quem fica por último com cada arquivo do Blood Reborn (no BB Port o último da lista vence)
    $nossoArqs = @{}
    foreach ($p in $script:Pacotes) { $nossoArqs[$p.Pasta] = $p.Arquivos }
    foreach ($c in $script:Compat) { $nossoArqs[$c.Pasta] = $c.Arquivos }
    $dono = @{}; $nossosAtivos = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($n in $sel) {
        if ($nossoArqs.ContainsKey($n)) { $fs = $nossoArqs[$n]; foreach ($f in $fs) { [void]$nossosAtivos.Add($f) } }
        else { $fs = Arquivos-Mod (Join-Path $dm $n) }
        foreach ($f in $fs) { $dono[$f] = $n }
    }
    $perdidos = @{}
    foreach ($f in $nossosAtivos) { $d = $dono[$f]; if ($d -and -not $nossoArqs.ContainsKey($d)) { if (-not $perdidos[$d]) { $perdidos[$d] = @() }; $perdidos[$d] += $f } }
    foreach ($d in $perdidos.Keys) { [void]$L.Add((Item 'aviso' ((T 'd_sobre') -f $d, ((@($perdidos[$d]) | Select-Object -First 3) -join ', ')) $false)) }
    # pastas que o BB Port não carrega e não são nossas
    $nomesRestos = @($restos | ForEach-Object { $_.Nome })
    if ([IO.Directory]::Exists($dm)) {
        foreach ($d in [IO.Directory]::GetDirectories($dm)) {
            $n = [IO.Path]::GetFileName($d)
            if (-not $n.StartsWith('.') -and $nomesRestos -notcontains $n -and -not (Raiz-Mod $d)) { [void]$L.Add((Item 'aviso' ((T 'd_desc') -f $n) $false)) }
        }
    }
    $ordemNivel = @{ erro = 0; aviso = 1; ok = 2 }
    return ($L | Sort-Object { $ordemNivel[$_.Nivel] })
}

# ---------------------------------------------------------------- procurar o BB Port
function Ler-Config {
    try { if ([IO.File]::Exists($CONFIG)) { return ([IO.File]::ReadAllText($CONFIG, [Text.Encoding]::UTF8) | ConvertFrom-Json) } } catch { }
    return $null
}
function Gravar-Config {
    try {
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $CONFIG))
        # fase 2: a chave do Nexus (cifrada, DPAPI); $null = não mexeu nesta sessão (mantém a guardada); '' = apagar
        $nx = $script:ChaveCifrada
        if ($null -eq $nx) { $velha = Ler-Config; if ($velha -and $velha.nexus) { $nx = [string]$velha.nexus } }
        $t = '{"porto": ' + (ConvertTo-Json ([string]$script:Porto)) + ', "lingua": ' + (ConvertTo-Json ([string]$script:Ling)) +
             ', "nexus": ' + (ConvertTo-Json ([string]$nx)) + '}'
        [IO.File]::WriteAllText($CONFIG, $t, $script:Utf8)
    } catch { }
}
function Achar-Port-Rapido {
    $cands = @()
    if ($PastaPort) { $cands += $PastaPort }
    $cfgUser = Ler-Config; if ($cfgUser -and $cfgUser.porto) { $cands += [string]$cfgUser.porto }
    $p = $script:Aqui
    for ($i = 0; $i -lt 4 -and $p; $i++) { $cands += $p; $cands += (Join-Path $p 'bbport-windows'); $p = Split-Path -Parent $p }
    foreach ($c in $cands) { if (E-Port $c) { return $c } }
    return $null
}
function Buscar-Ports([int]$fundo = 5, [int]$limite = 60000) {
    $raizes = @()
    foreach ($pasta in @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:USERPROFILE 'Downloads'), [Environment]::GetFolderPath('MyDocuments'), $env:USERPROFILE)) {
        if ($pasta -and [IO.Directory]::Exists($pasta)) { $raizes += $pasta }
    }
    foreach ($d in [IO.DriveInfo]::GetDrives()) { if ($d.DriveType -eq 'Fixed' -and $d.IsReady) { $raizes += $d.RootDirectory.FullName } }
    $pular = @('windows', 'program files', 'program files (x86)', 'programdata', '$recycle.bin', 'system volume information', 'appdata', 'node_modules', '.git', 'winsxs')
    $achados = New-Object Collections.ArrayList; $fila = New-Object Collections.Queue; $contados = 0
    $jaVisto = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($r in $raizes) { $fila.Enqueue(@($r, 0)) }
    while ($fila.Count -gt 0 -and $contados -lt $limite) {
        $item = $fila.Dequeue(); $dir = [string]$item[0]; $nivel = [int]$item[1]
        if (-not $jaVisto.Add($dir.TrimEnd('\'))) { continue }
        $contados++
        if ($script:AoProgredir -and $contados % 400 -eq 0) { & $script:AoProgredir ((T 'buscando') -f $contados) }
        if ([IO.File]::Exists((Join-Path $dir 'Play Bloodborne.exe'))) { if (-not $achados.Contains($dir)) { [void]$achados.Add($dir) }; continue }
        if ($nivel -ge $fundo) { continue }
        try { $subs = [IO.Directory]::GetDirectories($dir) } catch { continue }
        foreach ($s in $subs) { if ($pular -notcontains ([IO.Path]::GetFileName($s)).ToLowerInvariant()) { $fila.Enqueue(@($s, ($nivel + 1))) } }
    }
    return $achados
}

# ---------------------------------------------------------------- atualizações (fase 2)
$script:FonteInstalacao = 'zip'
. (Join-Path $script:Aqui 'Atualizacoes.ps1')

# ---------------------------------------------------------------- idioma
$script:Ling = 'en'
$cfgIni = Ler-Config
if ($Lingua -and $TXT.ContainsKey($Lingua)) { $script:Ling = $Lingua }
elseif ($cfgIni -and $cfgIni.lingua -and $TXT.ContainsKey([string]$cfgIni.lingua)) { $script:Ling = [string]$cfgIni.lingua }
else { $lg = (Get-UICulture).TwoLetterISOLanguageName; if ($TXT.ContainsKey($lg)) { $script:Ling = $lg } }

# ---------------------------------------------------------------- modo sem janela (testes)
if ($Acao) {
    Ler-Pacotes
    if (-not (E-Port $PastaPort)) { Write-Error 'BB Port não encontrado (-PastaPort)'; exit 2 }
    $quero = @($Mods | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    # fase 2: uma falha (ex.: download recusado) sai com código 3, para os testes enxergarem
    try {
    switch ($Acao) {
        'instalar' { [void](Aplicar-Escolha $PastaPort $quero) }
        'corrigir' { [void](Corrigir-Tudo $PastaPort) }
        'verificar' { }
        'atualizar' { foreach ($x in $quero) { [void](Atualizar-Mod $PastaPort $x) } }
        'voltar' { foreach ($x in $quero) { Voltar-Mod $PastaPort $x } }
        'atualizacoes' {
            # fase 2: o estado de atualização de cada mod (instalada, disponível, notas, fontes), sem cache
            $est = @(Estado-Atualizacoes $PastaPort -Forcar)
            $json = ConvertTo-Json -InputObject $est -Depth 8
            if ($Relatorio) { [IO.File]::WriteAllText($Relatorio, $json, $script:Utf8) } else { $json }
            exit 0
        }
        default { Write-Error "Ação desconhecida: $Acao"; exit 2 }
    }
    } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 3 }
    $res = @(Diagnosticar $PastaPort)
    $json = ConvertTo-Json -InputObject $res -Depth 4
    if ($Relatorio) { [IO.File]::WriteAllText($Relatorio, $json, $script:Utf8) } else { $json }
    exit 0
}
try {
    . (Join-Path $script:Aqui 'BloodReborn_janela.ps1')
} catch {
    # captura (teste): nunca abre caixa na tela; o erro vai só para o registro
    if ($Captura) { [Console]::Error.WriteLine($_.Exception.Message + ' ' + $_.InvocationInfo.PositionMessage); exit 1 }
    # o .bat esconde o console: o erro aparece numa caixa, não some
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show(((T 'erro') -f ($_.Exception.Message + "`n`n" + $_.InvocationInfo.PositionMessage)), 'Blood Reborn', 'OK', 'Error')
    exit 1
}
