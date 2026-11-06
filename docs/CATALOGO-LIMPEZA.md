# Catálogo de limpeza

O catálogo em `Data/cleanup-rules.json` é próprio deste projeto. Ele foi
escrito a partir de documentação pública e dos caminhos oficiais dos
aplicativos. **Não há engenharia reversa, extração de binários ou cópia de
definições do CCleaner** ou de outro produto comercial.

## Fontes usadas

- Documentação da Microsoft sobre pastas conhecidas, Windows Update, WER,
  Otimização de Entrega e Prefetch.
- Documentação do Chromium sobre caches `Cache`, `Code Cache` e `GPUCache`.
- Documentação dos próprios aplicativos para pastas de cache (Teams, Discord,
  Spotify, Steam, Slack, Visual Studio Code, npm, pip e NuGet).

Projetos open-source de limpeza podem servir como referência conceitual, mas
o código e as definições não são copiados. Em especial, o BleachBit é GPL e
não pode ser incorporado a este projeto MIT sem mudança de licença.

## Método clean-room e o projeto Craft Anything

O [Craft Anything](https://github.com/storytold/craft-anything) (MIT ou
Apache-2.0) foi consultado apenas como **referência de método**: inspecionar
software que você possui ou tem autorização para examinar, trabalhar a partir
de evidências públicas e construir uma implementação própria. Nenhum código,
binário, definição de limpeza ou ativo do repositório foi copiado para este
projeto.

O mesmo princípio foi aplicado ao CCleaner: **não houve engenharia reversa,
desmontagem, extração de binários ou cópia das regras internas**. As categorias
abaixo vêm de documentação pública da Microsoft, do Chromium e dos próprios
aplicativos. O Craft Anything também não contorna DRM, login ou anti-cheat, e
esse limite foi mantido aqui.

## Formato de uma categoria

| Campo | Obrigatório | Uso |
|---|---|---|
| `Id` | sim | Identificador único usado na análise e na limpeza. |
| `Name` | sim | Nome exibido na interface. |
| `Path` | sim | Pasta raiz. Aceita `{LocalAppData}`, `{AppData}`, `{UserProfile}`, `{SystemRoot}`, `{ProgramData}` e `{Temp}`. Um segmento inteiro `*` expande perfis; curingas parciais são recusados. |
| `Process` | não | Processo que deve estar fechado para a categoria ser analisada. |
| `RequiresAdmin` | não | Categoria ignorada quando a interface não está elevada. |
| `Risk` | não | `Baixo`, `Médio` ou `Alto`, exibido na grade. |
| `Note` | não | Explicação curta do impacto da limpeza. |
| `Patterns` | não | Lista de padrões de nome de arquivo (por exemplo, `thumbcache_*.db`). |
| `AllowedExtensions` | não | Substitui a lista padrão de extensões protegidas **somente** para os arquivos que também casarem com `Patterns`. |

Categorias cujo caminho não existe no computador são omitidas. Tokens não
resolvidos e caminhos relativos são descartados.

## Perfis de navegador

Navegadores baseados em Chromium guardam perfis em subpastas como `Default` e
`Profile 1`. O catálogo usa um segmento `*` para descobri-los sem manter uma
lista fixa:

```json
"Path": "{LocalAppData}\\Vivaldi\\User Data\\*\\Cache\\Cache_Data"
```

Regras de expansão:

- Apenas um segmento inteiro pode ser `*`; algo como `wild*` é recusado.
- O limite é de 64 pastas por regra.
- Junctions e links simbólicos são ignorados.
- Cada pasta encontrada vira um destino com id próprio (`regra-1`, `regra-2`)
  e nome com o perfil (`Vivaldi / Cache / Default`).
- Pastas que não existem depois da expansão continuam omitidas.

Categorias incluídas: Chrome, Edge, Brave, Firefox (`cache2` e `startupCache`),
Opera, Vivaldi e Chromium. Chrome, Edge, Brave, Firefox, Vivaldi e Chromium usam
`*` para cobrir todos os perfis; Opera usa o perfil único `Opera Stable`.

## Elevação

Categorias como Temp do Windows, Windows Update e Prefetch exigem
administrador. Sem elevação:

1. A análise ignora essas categorias e mostra um aviso com os nomes das
   categorias puladas.
2. A limpeza também recusa os ids correspondentes, mesmo que a análise tenha
   sido feita em outra sessão.
3. O botão **Abrir como administrador** reabre a interface elevada após
   confirmação. Ele fica oculto quando a sessão já é administrativa.

Use a mesma conta do cliente. Credenciais de outro usuário mudam o perfil
analisado e podem apontar para pastas erradas.

## Regras de segurança preservadas

- Somente raízes declaradas são percorridas; não há limpeza de Registro,
  cookies, senhas, histórico, documentos ou Downloads.
- Junctions, links simbólicos e pastas com marcadores de projeto continuam
  bloqueados por `Test-OptimizerPath`.
- Arquivos recentes (menos de 7 dias), extensões de código/documentos/mídia e
  arquivos alterados após a análise são preservados.
- A exclusão é permanente, arquivo por arquivo, sempre depois da prévia e da
  confirmação explícita.
- Categorias com `RequiresAdmin` nunca são limpas sem elevação.

## Como adicionar uma categoria

1. Confirme a finalidade da pasta na documentação oficial do Windows ou do
   aplicativo.
2. Adicione uma entrada em `Data/cleanup-rules.json` com `Id` único, `Name`,
   `Path`, `Risk` e `Note`.
3. Se a pasta contiver arquivos pessoais ou bancos de dados não relacionados
   ao cache, use `Patterns` e deixe `AllowedExtensions` restrito.
4. Execute `./Tests/CleanupCatalog.Smoke.ps1` e `./Tests/Core.Smoke.ps1`.
5. Valide em uma máquina descartável antes de publicar.
