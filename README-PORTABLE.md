# Windows PC Optimizer - Portable Version

## Sobre este pacote

Este é um pacote **portátil** do Windows PC Optimizer que pode ser executado a partir de uma unidade USB, drive externo, ou qualquer armazenamento removível sem instalação no sistema.

## Requisitos do sistema

- **Windows 10 ou superior** (32-bit ou 64-bit)
- **PowerShell 5.1 ou superior** (incorporado no Windows 10)
- **Acesso administrativo para algumas operações** (opcional, mas recomendado para SMART completo)

## Como usar

### 1. Preparar a unidade portátil

1. **Baixe ou copie** este entire repositório para sua unidade USB
2. **Crie uma pasta** chamada `windows-pc-optimizer` na raiz da sua unidade USB
3. **Verifique** se todas as pastas e arquivos estão presentes

### 2. Executar o otimizador

**Opção A: Clique duas vezes (recomendado)**

1. Na sua unidade USB, abra a pasta `windows-pc-optimizer`
2. Clique duas vezes em `Executar-Otimizador.bat`
3. O otimizador será carregado e executado

**Opção B: PowerShell direta**

1. Abra PowerShell como administrador (clique com o botão direito → "Executar como administrador")
2. Navegue até o local do otimizador:
   ```
   cd "C:\Users\SeuNome\AppData\Local\Programs\WindowsPC_Optimizer"
   ```
   *(ou onde quer que você tenha extraído o programa)*
3. Execute:
   ```powershell
   ."./Modules/Optimizer.Core.psm1" -Force
   ```
4. Ou execute o script principal:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Otimizador-GUI.ps1"
   ```

### 3. Desinstalar ou limpar

Como este é um programa portátil:

- **Sem entradas no registro**: Nenhuma alteração no registro do Windows
- **Sem alterações no sistema**: Nenhuma alteração permanente no computador hospedeiro
- **Sem configurações personalizadas salvas**: Todas as configurações são resetadas cada vez que você executa

Para limpar da sua unidade USB:
1. Excluia a pasta inteira `windows-pc-optimizer`
2. Remova qualquer arquivo temporário criado (geralmente na pasta Temp do seu usuário)

## Estrutura do diretório portátil

```
/windows-pc-optimizer-portable/
├── Executar-Otimizador.bat
├── Otimizador-GUI.ps1
├── Otimizar-PC.ps1
├── README.md
├── README-PORTABLE.md
├── .gitignore
├── .editorconfig
├── Modules/
│   ├── Optimizer.Core.psm1
│   ├── Optimizer.Preferences.psm1
│   ├── Optimizer.Technician.psm1
│   ├── Optimizer.NetworkDiagnostics.psm1
│   └── Optimizer.Events.psm1
├── Tests/
│   ├── Core.Smoke.ps1
│   ├── Events.Smoke.ps1
│   ├── Network.Smoke.ps1
│   ├── Optimizer.Tests.ps1
│   ├── Preferences.Smoke.ps1
│   ├── Technician.Smoke.ps1
│   └── UI.UX.Smoke.ps1
├── UI/
│   └── MainWindow.xaml
└── Outros arquivos de suporte...
```

## Funcionalidades notáveis

### Portátil significa:

✅ **Sem instalação no sistema** - Apenas copie e execute
✅ **Sem alterações no registro** - Não afeta o computador hospedeiro
✅ **Sem configurações persistentes** - Comece limpo cada vez
✅ **Funciona em qualquer lugar** - Execute a partir de qualquer unidade USB
✅ **Funciona em qualquer computador** - Não requer permissões administrativas (exceto para SMART completo)

### Funcionalidades disponíveis:

- **Limpeza e otimização** - Limpe arquivos temporários e registre otimizações
- **Diagnóstico do sistema** - Verifique bateria, discos e componentes do sistema
- **Remoção de aplicativos** - Gerencie aplicativos Windows e Store
- **Atualização de drivers** - Verifique e atualize drivers
- **Reparos do sistema** - Execute ferramentas de reparo do Windows
- **Inventário técnico** - Detalhes completos do sistema e hardware
- **Análise de rede** - Verifique conectividade e configuração de rede
- **Logs de eventos** - Analise logs de eventos do Windows
- **Modo alto contraste e escalabilidade** - Acessibilidade integrada

## Dicas e atalhos

### Criar um atalho no seu desktop

1. Na sua unidade USB, clique com o botão direito em `Executar-Otimizador.bat`
2. Selecione "Enviar para" → "Área de trabalho (criar atalho)"
3. Mova o atalho do desktop para a sua unidade USB para fácil acesso

### Usar a partir do PowerShell

```powershell
# Execute o otimizador a partir de qualquer lugar
cd "C:\Users\SeuNome\AppData\Local\Programs\WindowsPC_Optimizer"
."./Executar-Otimizador.bat"
```

### Manter atualizações

Baixe a versão mais recente do repositório oficial:
https://github.com/leonccunha21/windows-pc-optimizer

## Perguntas frequentes

### P: O otimizador funciona em computadores sem permissão administrativa?
R: Sim! A maioria das funcionalidades funciona sem privilégios administrativos. No entanto, a temperatura completa do SMART do disco e a análise de horas requerem privilégios administrativos para dados mais detalhados.

### P: Posso usar este em um computador compartilhado?
R: Absolutamente! Como é portátil, não deixa rastros no computador hospedeiro e não altera configurações do sistema.

### P: E se eu excluír acidentalmente arquivos?
R: O otimizador usa um modo **"What If"** seguro que apenas simula exclusões antes de realmente executar qualquer ação. Todas as exclusões verdadeiras exigem confirmação adicional.

### P: Este programa é seguro?
R: Totalmente seguro! O código-fonte está disponível publicamente, não instala malware, e todas as operações são opcionais e requerem confirmação antes da execução.

## Sobre o desenvolvimento

Este é um fork **portátil** do Windows PC Optimizer original, projetado especificamente para:

- **Profissionais de TI** que precisam de ferramentas em multiple computadores
- **Administradores de sistema** que trabalham em múltiplas estações de trabalho
- **Usuários móveis** que precisam de manutenção do sistema em qualquer lugar
- **Testadores** que precisam de um ambiente de teste limpo e consistente

O programa original permanece inalterado, e esta versão portátil é uma adaptação separada do repositório original.

## Agradecimentos

- Baseado no Windows PC Optimizer original por leonccunha21
- Traduzido para um formato portátil por OpenCode
- Agradecimentos à comunidade por feedback e suporte contínuo