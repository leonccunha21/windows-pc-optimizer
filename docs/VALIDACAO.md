# Validação de bancada

## Automatizada

- Sintaxe de todos os PS1/PSM1, ausência de funções duplicadas e XML da interface.
- Testes com arquivos temporários isolados: retenção, projetos, extensões pessoais, cancelamento, prévia, seleção, arquivo alterado, expiração, links, proteção adicionada após análise, bytes removidos e escape de HTML.
- CI: Windows/Linux, Windows PowerShell 5.1 e carregamento real de XAML/eventos WPF e ciclo de análise/limpeza em segundo plano com perfil descartável.

## Manual necessária antes de distribuir amplamente

- Abrir o BAT extraído em Windows 10 e 11, usuário padrão. Testar pastas com espaços e acentos.
- Revisar a interface em 100%, 125%, 150% e 200% de DPI; redimensionar e navegar por teclado.
- Analisar um perfil com muitos temporários: janela deve continuar respondendo, Interromper deve funcionar e fechar durante trabalho deve aguardar.
- Chrome/Edge/Brave abertos: conferir avisos. Fechar, analisar, reabrir antes da limpeza e confirmar que arquivos são ignorados.
- Limpar apenas uma categoria; conferir prévia e resultado. Testar arquivo bloqueado por outro programa.
- Notebook com/sem bateria, desktop, Defender desativado por outro antivírus: indisponibilidade deve aparecer sem falso sucesso.
- Exportar HTML com acentos e símbolos; conferir no navegador e na impressão PDF.
- Conferir restauração, otimização de disco e demais atalhos em Windows Home/Pro; a ação final é feita no aplicativo nativo.

A prévia `preview.png` foi renderizada pelo WPF no CI Windows. Os testes automatizados não substituem inspeção visual e testes em máquinas reais. A limpeza não é uma fronteira de segurança contra outro processo malicioso que altere caminhos simultaneamente; execute apenas em ambiente confiável e com backup adequado.
