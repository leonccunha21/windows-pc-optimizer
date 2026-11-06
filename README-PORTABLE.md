# PC Optimizer Portable

Pacote autônomo do PC Optimizer para uso em qualquer computador Windows, sem
instalação e sem baixar o repositório completo. Pode ser executado de um pen
drive, HD externo, pasta de rede mapeada ou diretamente no disco local.

**Versão:** 4.5  
**Interface:** WPF (Windows PowerShell 5.1 ou PowerShell 7)  
**Licença:** MIT

---

## 1. Início rápido

1. Extraia o ZIP `PC-Optimizer-Portable-4.5.zip` para uma pasta comum.
2. Abra a pasta extraída.
3. Clique duas vezes em **`PC-Optimizer.exe`**.
4. Analise primeiro; a limpeza só começa depois da confirmação.

Não é necessário instalar, registrar serviço, criar atalho, ter o repositório
Git ao lado ou usar qualquer arquivo `.bat`. O `PC-Optimizer.exe` é o launcher
nativo do pacote; o `Iniciar-PC-Optimizer.ps1` é apenas o motor interno.

### Verificação sem abrir a interface

```powershell
$selfTest = Start-Process -FilePath .\PC-Optimizer.exe -ArgumentList '-SelfTest' -Wait -PassThru
if ($selfTest.ExitCode -ne 0) { throw 'Self-test falhou.' }
```

Saída esperada: código de saída `0` (`Start-Process -Wait` é necessário porque
o `PC-Optimizer.exe` é um aplicativo Windows GUI).

### Verificação completa da interface

```powershell
$validate = Start-Process -FilePath .\PC-Optimizer.exe -ArgumentList '-ValidateUI' -Wait -PassThru
if ($validate.ExitCode -ne 0) { throw 'Validação da interface falhou.' }
```

Esse teste abre e fecha a janela, usa uma pasta temporária descartável e não
altera configurações do Windows.

---

## 2. Requisitos

| Item | Requisito |
|---|---|
| Sistema | Windows 10 ou 11 (x64 ou x86) |
| Runtime | Windows PowerShell 5.1 (incluído) ou PowerShell 7 |
| Espaço | Cerca de 200 MB para o pacote e arquivos temporários |
| Permissões | Usuário comum para a maior parte; elevação sob demanda |
| Rede | Opcional, apenas para testes de conectividade e atualizações |

O launcher nativo `PC-Optimizer.exe` prioriza `powershell.exe` (Windows PowerShell 5.1)
porque a interface WPF e os módulos do sistema foram validados nesse runtime.
Se ele não existir, usa `pwsh.exe`.

---

## 3. O que está incluído

```
PC-Optimizer-Portable-4.5/
├─ PC-Optimizer.exe              <- clique aqui
├─ Iniciar-PC-Optimizer.ps1      <- motor interno do launcher e self-test
├─ Otimizador-GUI.ps1            <- interface principal
├─ Otimizar-PC.ps1               <- console legado/avançado
├─ LEIA-ME.txt                   <- guia curto
├─ README-PORTABLE.md            <- este documento
├─ VERSION.txt                   <- versão, data e commit de origem
├─ SHA256SUMS.txt                <- hashes dos arquivos do pacote
├─ Modules/                      <- núcleo, limpeza, privacidade, ajustes e assistente local
├─ UI/                           <- layout WPF
├─ Data/cleanup-rules.json       <- catálogo declarativo de limpeza
├─ config/optimizer.psd1         <- políticas de retenção e proteção
├─ Tools/                        <- diagnósticos de rede e eventos
├─ docs/CATALOGO-LIMPEZA.md      <- referência do catálogo
└─ Dados/                        <- preferências e logs locais (criado no uso)
```

O pacote **não** inclui `Tests/`, `.git/`, builds antigos, executáveis de
terceiros ou arquivos de desenvolvimento. O único executável é o
`PC-Optimizer.exe`, compilado a partir de `Tools/Portable/Launcher`.

---

## 4. Comportamento portátil

- **Preferências:** ficam em `Dados/preferences.json` quando a pasta do pacote é
  gravável. Isso permite levar tema, escala de texto e categorias selecionadas
  junto com o pen drive.
- **Logs do launcher:** ficam em `Dados/Logs/portable-launcher.log`.
- **Mídia somente leitura:** se `Dados/` não puder ser criada ou escrita, o
  programa usa `%TEMP%\PCOptimizer-Portable` automaticamente.
- **Logs do console legado:** continuam em `%TEMP%` e são temporários.
- **Relatórios:** o usuário escolhe onde salvar; nenhum caminho de cliente é
  serializado nos relatórios JSON/HTML.
- **Sem instalação:** não há serviço, driver, tarefa agendada ou chave de
  desinstalação. Remover a pasta remove o programa.

O modo portátil não significa que todas as ações são temporárias: recursos de
**Privacidade** e **Ajustes** alteram configurações do Windows quando o usuário
seleciona e confirma. Elas são operações explícitas e documentadas na interface.

---

## 5. Modos de uso

### Interface gráfica (recomendado)

```text
PC-Optimizer.exe
```

Abre a central de manutenção com limpeza guiada, diagnóstico, saúde do
equipamento, bancada técnica, relatórios e preferências. Na Visão geral, o
botão **Recomendar melhores opções** abre o assistente local: ele analisa o
equipamento sem rede, mostra as melhores opções com motivo e prioridade e só
pré-seleciona itens; nada é aplicado sem confirmação.

### Console legado / avançado

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Otimizar-PC.ps1
```

Use `-DryRun` para simular sem remover arquivos. O console é voltado a
profissionais que já conhecem as rotinas; a interface é o caminho seguro para
uso geral.

### Diagnósticos independentes

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tools\Diagnostico-Rede.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tools\Diagnostico-Eventos.ps1
```

São somente leitura e não exigem a interface.

### Elevação sob demanda

O botão **Abrir como administrador** na aba Limpeza reinicia a interface elevada
com confirmação. Categorias administrativas são ignoradas enquanto a sessão não
for elevada.

---

## 6. Segurança e privacidade

- Sem telemetria, analytics, login ou chamada de rede automática.
- Análise não remove arquivos; a remoção exige seleção e confirmação.
- Código-fonte, fotos, documentos e pastas de projeto são preservados por
  política (`config/optimizer.psd1`).
- Junctions, links simbólicos e caminhos fora da raiz permitida são recusados.
- Logs estruturados do console redigem caminhos absolutos/UNC, IPs, e-mails e
  tokens longos.
- Preferências não guardam nome de cliente, IP, caminho limpo ou inventário.
- O ZIP acompanha um arquivo `.sha256`; os arquivos internos têm hashes em
  `SHA256SUMS.txt`.

---

## 7. Verificação de integridade

No PowerShell, na pasta do ZIP:

```powershell
$hash = (Get-FileHash .\PC-Optimizer-Portable-4.5.zip -Algorithm SHA256).Hash.ToLowerInvariant()
$expected = (Get-Content .\PC-Optimizer-Portable-4.5.zip.sha256 -Raw).Split(' ')[0]
if ($hash -eq $expected) { 'Integridade OK' } else { 'Falha na verificação' }
```

Dentro do pacote:

```powershell
Get-Content .\SHA256SUMS.txt | ForEach-Object {
    $parts = $_ -split '  ', 2
    $actual = (Get-FileHash -LiteralPath $parts[1] -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $parts[0]) { Write-Warning "Hash diferente: $($parts[1])" }
}
```

---

## 8. Atualização

1. Baixe o novo ZIP e o respectivo `.sha256`.
2. Extraia em uma pasta nova (recomendado) ou substitua os arquivos antigos.
3. Preserve a pasta `Dados/` se quiser manter as preferências.
4. Execute o self-test antes de usar em produção.

Não há registro, serviço ou cache global para limpar.

---

## 9. Solução de problemas

| Sintoma | Ação |
|---|---|
| SmartScreen bloqueia o `.exe` | **Mais informações** → **Executar assim mesmo** |
| “PowerShell não encontrado” | Reative o Windows PowerShell 5.1 ou instale o PowerShell 7 |
| Janela não abre | Confirme que `Modules/` e `UI/` estão ao lado de `Otimizador-GUI.ps1` |
| Erro de política de execução | Use o `PC-Optimizer.exe`; ele aplica `Bypass` somente ao processo atual |
| `Dados/` não grava | Use uma pasta local; em mídia somente leitura o fallback é automático |
| Antivírus alerta | O código é aberto; SFC/DISM e limpeza de temporários podem gerar alerta |
| Categoria administrativa ignorada | Use **Abrir como administrador** na interface |
| Interface em PowerShell 7 falha | Execute o `PC-Optimizer.exe`, que prioriza o Windows PowerShell 5.1 |

Logs úteis:

```text
Dados\Logs\portable-launcher.log
%TEMP%\PCOptimizer-Portable\Logs\portable-launcher.log
```

---

## 10. Build e release (mantenedores)

O pacote é gerado a partir do repositório com:

```powershell
pwsh -NoProfile -File .\Tools\Build-Portable.ps1
```

Opções:

```powershell
# Versão explícita, saída em uma pasta específica e sem ZIP
pwsh -File .\Tools\Build-Portable.ps1 -Version 4.5 -OutputDirectory .\dist -NoZip

# Pular a validação de sintaxe do repositório (o release já roda os testes)
pwsh -File .\Tools\Build-Portable.ps1 -SkipTests

# Assinar o PC-Optimizer.exe com certificado self-signed local (desenvolvimento)
pwsh -File .\Tools\Build-Portable.ps1 -SignSelfSigned

# Assinar com certificado de código Authenticode já instalado (CA confiável)
pwsh -File .\Tools\Build-Portable.ps1 -CertificateThumbprint SEU_THUMBPRINT
```

Saídas em `dist/`:

```text
PC-Optimizer-Portable-4.5/
PC-Optimizer-Portable-4.5.zip
PC-Optimizer-Portable-4.5.zip.sha256
```

O script copia apenas a lista explícita de runtime, valida sintaxe/XAML, compila
o launcher nativo `PC-Optimizer.exe` a partir de `Tools/Portable/Launcher` com
o `csc.exe` do Windows, gera `VERSION.txt`, `SHA256SUMS.txt` e recusa a build
se algum arquivo obrigatório estiver ausente. Em sistemas não-Windows, a
compilação do EXE é ignorada com aviso; o release oficial deve ser gerado no
Windows para incluir o executável. `dist/` é ignorado pelo Git.

---

## 11. Limitações conhecidas

- Drivers e reparos que exigem reinicialização continuam dependendo do sistema
  hospedeiro e de elevação.
- A temperatura/horas SMART podem ficar indisponíveis sem administrador.
- Não há assinatura Authenticode de CA neste pacote local; o Windows pode exibir aviso de
  origem desconhecida. O build pode assinar com certificado self-signed para desenvolvimento
  (`-SignSelfSigned`) ou com um certificado de CA já instalado (`-CertificateThumbprint`).
- O pacote não substitui backup, antivírus ou julgamento profissional antes de
  operações destrutivas.

---

## 12. Licença e contato

MIT. Consulte `LICENSE`. Projeto independente, sem vínculo com CCleaner,
Microsoft ou qualquer fornecedor de limpeza comercial.

Repositório: <https://github.com/leonccunha21/windows-pc-optimizer>
