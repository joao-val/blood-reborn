<div align="center">

# 🩸 Blood Reborn

**Mods grátis de Bloodborne para o BB Port (PC)**

[![English](https://img.shields.io/badge/English-read%20in%20English-2f2f2f?style=for-the-badge)](README.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs%20(Brasil)-selecionado-8b0000?style=for-the-badge)](README.pt-BR.md)

</div>

---

## Os mods

| Mod | Versão | O que faz |
|---|---|---|
| **Hunter's Arsenal: Blood Pacts** | 1.0 | Ataques especiais novos para as armas de truque (R2+L2 no modo transformado), inspirados nas habilidades do Elden Ring e refeitos para o Bloodborne. Runas e gemas com **pactos**: 14 pactos sorteados nas gemas que você acha. Traz 9 patches de código. |
| **Merciless Night** | 1.31 | Chefes e inimigos mais duros e modernos: segunda barra de vida e fases novas em vários chefes, menos tempo parado entre os golpes, IA mais agressiva, vida e dano rebalanceados. Traz 1 patch de código (correção da física do pano). |
| **Fogside Lantern** | 1.6.1 *(em teste)* | Morreu na luta contra um chefe? Você renasce do lado de fora da névoa, na lanterna do chefe. |
| **Blood Vial Safety Net** | 1.0.1 *(em teste)* | Depois de morrer e renascer, os seus Frascos de Sangue voltam para 11. Ele só completa o que falta e nunca durante uma luta. |

Os mods funcionam sozinhos ou juntos. Onde dois mexem no mesmo arquivo do jogo, uma pastinha de compatibilidade (**zCompat**) junta os dois.

## Você precisa

- O **BB Port** instalado e funcionando.
- O seu próprio dump do **Bloodborne** (CUSA03173), versão **1.09** do jogo.
- Uma cópia da sua pasta de saves num lugar seguro, por garantia (pasta do BB Port ➜ `user` ➜ `savedata`).

## Gerenciador de Mods do Blood Reborn *(em desenvolvimento)*

Um gerenciador de mods pequeno, feito só para os mods do Blood Reborn. Ele **não** abre o jogo: você continua jogando pelo BB Port, como sempre.

- **Instala, remove e atualiza** cada mod, mostrando a versão instalada, a mais nova e *o que mudou*.
- **Procura atualizações no GitHub e no Nexus Mods**, sem precisar de login.
  - GitHub: download de um clique.
  - Nexus Premium: um clique, com a sua chave da API.
  - Conta grátis do Nexus: ele abre a página do arquivo, você clica em *Download manual*, e ele instala o zip assim que ele chega na sua pasta Downloads.
- **Resolve conflitos com qualquer outro mod** da sua pasta `mods`. Ele junta o que dá numa pasta no fim da ordem e lista o que não dá, para você escolher qual mod vence (o Blood Reborn é a escolha recomendada).
- Nunca escreve nos arquivos do jogo nem nos mods de outras pessoas.

Desenho (em inglês): [docs/manager-design.md](docs/manager-design.md).

## Como as atualizações são publicadas

O [`catalog.json`](catalog.json) lista cada mod com a versão atual, as notas de cada versão, o download (um arquivo anexado a um lançamento do GitHub) e a página no Nexus Mods. Publicar uma versão nova é montar o pacote, anexar a um lançamento do GitHub e atualizar o catálogo. O gerenciador lê o catálogo para saber o que há de novo.

## Créditos e aviso legal

- Feito por **joao-val**.
- Sem ligação com a FromSoftware, a Sony Interactive Entertainment ou o projeto BB Port.
- Bloodborne é marca registrada da Sony Interactive Entertainment. Você precisa da sua própria cópia do jogo, obtida legalmente.
